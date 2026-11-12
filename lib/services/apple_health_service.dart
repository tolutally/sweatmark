import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_activity.dart';
import '../models/monthly_stats.dart';
import '../models/workout_model.dart';

/// Connects SweatMark to Apple Health when the person turns it on in Settings.
/// It saves finished workouts (time, activity type, known distance; no
/// calories) and reads steps, walking and running distance and active energy
/// to show in Stats. It also reads the times of workouts other apps or an
/// Apple Watch recorded, only so a logged workout on the same day can use the
/// Watch time. Health data stays on the device: it is never uploaded or
/// merged into logged workouts.
class AppleHealthService {
  AppleHealthService._();
  static final instance = AppleHealthService._();

  final Health _health = Health();
  static const _writeTypes = [HealthDataType.WORKOUT];
  static const _writeAccess = [HealthDataAccess.WRITE];
  static const _movementTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  static const _types = [HealthDataType.WORKOUT, ..._movementTypes];
  static const _access = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Workouts from these sources are SweatMark's own copies, already counted
  /// in Stats from the logged workout.
  static const ownSourceIds = {'com.peniwyse.sweatmark.ios001'};

  bool get isAvailable => !kIsWeb && Platform.isIOS;

  /// Bumped whenever Health is turned on or off, so screens read again.
  final ValueNotifier<int> changes = ValueNotifier(0);

  String _enabledKey(String uid) => 'apple_health_enabled_$uid';
  String _savedKey(String uid) => 'apple_health_saved_$uid';
  // Set once the read permission has been asked for, so people who turned
  // Health on before these types were read are asked again from Stats.
  String _readKey(String uid) => 'apple_health_read_v2_$uid';

  /// Whether Health is on and reading has been asked for.
  Future<bool> canRead(String? uid) async {
    if (!await isEnabled(uid)) return false;
    try {
      return (await SharedPreferences.getInstance()).getBool(_readKey(uid!)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled(String? uid) async {
    if (!isAvailable || uid == null) return false;
    try {
      return (await SharedPreferences.getInstance())
              .getBool(_enabledKey(uid)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Asks to save workouts and to read movement and workout times. Returns whether
  /// Health is on. iOS never says whether reading was allowed; if it was
  /// not, reads simply come back empty.
  Future<bool> enable(String uid) async {
    if (!isAvailable) return false;
    try {
      await _health.configure();
      final granted =
          await _health.requestAuthorization(_types, permissions: _access);
      final canWrite = await _health.hasPermissions(_writeTypes,
              permissions: _writeAccess) ??
          granted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey(uid), granted && canWrite);
      if (granted) await prefs.setBool(_readKey(uid), true);
      changes.value++;
      return granted && canWrite;
    } catch (error) {
      debugPrint('Apple Health permission failed: $error');
      return false;
    }
  }

  Future<void> disable(String uid) async {
    try {
      await (await SharedPreferences.getInstance())
          .setBool(_enabledKey(uid), false);
    } catch (_) {}
    changes.value++;
  }

  /// Steps, walking and running distance and active energy between [start]
  /// and [end], plus the times of workouts other apps or devices recorded.
  /// Null when Health is off or reading was not asked for.
  Future<HealthSummary?> readActivity(
      String? uid, DateTime start, DateTime end) async {
    if (!await canRead(uid) || !end.isAfter(start)) return null;
    try {
      await _health.configure();
    } catch (error) {
      debugPrint('Apple Health read skipped: $error');
      return HealthSummary();
    }
    // Totals use HealthKit statistics, which count overlapping iPhone and
    // Watch samples once.
    final totals = <HealthDataType, double>{};
    // Local days with any movement; each point is one day starting at
    // [start]. Its middle names the day, so a daylight-saving shift can't
    // move it to the day before.
    final days = <String>{};
    void addDay(HealthDataPoint point) {
      final middle = point.dateFrom
          .add(point.dateTo.difference(point.dateFrom) ~/ 2)
          .toLocal();
      days.add('${middle.year}-${middle.month}-${middle.day}');
    }

    var daysKnown = false;
    try {
      final points = await _health.getHealthIntervalDataFromTypes(
          startDate: start,
          endDate: end,
          types: const [
            HealthDataType.DISTANCE_WALKING_RUNNING,
            HealthDataType.ACTIVE_ENERGY_BURNED,
          ],
          interval: 86400);
      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) continue;
        final number = value.numericValue.toDouble();
        if (!number.isFinite || number <= 0) continue;
        totals[point.type] = (totals[point.type] ?? 0) + number;
        addDay(point);
      }
      daysKnown = true;
    } catch (error) {
      debugPrint('Apple Health totals skipped: $error');
    }
    int? steps;
    try {
      steps = await _health.getTotalStepsInInterval(start, end);
    } catch (_) {}
    if (daysKnown && (steps ?? 0) > 0) {
      try {
        final points = await _health.getHealthIntervalDataFromTypes(
            startDate: start,
            endDate: end,
            types: const [HealthDataType.STEPS],
            interval: 86400);
        for (final point in points) {
          final value = point.value;
          if (value is NumericHealthValue && value.numericValue > 0) {
            addDay(point);
          }
        }
      } catch (error) {
        daysKnown = false;
        debugPrint('Apple Health step days skipped: $error');
      }
    }
    final sessions = <HealthActivity>[];
    try {
      final points = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.WORKOUT],
          startTime: start,
          endTime: end);
      final seen = <String>{};
      for (final point in points) {
        if (point.value is! WorkoutHealthValue) continue;
        if (ownSourceIds.contains(point.sourceId) ||
            point.sourceName == 'SweatMark' ||
            !seen.add(point.uuid)) {
          continue;
        }
        sessions.add(HealthActivity(
            id: point.uuid,
            start: point.dateFrom,
            end: point.dateTo,
            sourceName: point.sourceName));
      }
    } catch (error) {
      debugPrint('Apple Health workout times skipped: $error');
    }
    return HealthSummary(
      steps: steps,
      distanceMeters: totals[HealthDataType.DISTANCE_WALKING_RUNNING],
      activeKcal: totals[HealthDataType.ACTIVE_ENERGY_BURNED],
      daysWithData: daysKnown && days.isNotEmpty ? days.length : null,
      sessions: sessions,
    );
  }

  /// Saves one finished workout, at most once. Never throws: a Health
  /// failure must not affect the saved workout.
  Future<void> saveWorkout(String? uid, WorkoutLog workout) async {
    if (!isAvailable || uid == null || workout.isTestData) return;
    if (workout.durationSeconds <= 0) return;
    final completed = workout.exercises
        .where((e) => e.sets.any((s) => s.isCompleted && !s.isSuperSetRest))
        .toList();
    if (completed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_enabledKey(uid)) ?? false)) return;
      final saved = prefs.getStringList(_savedKey(uid)) ?? const [];
      if (saved.contains(workout.id)) return;

      final cardioOnly =
          completed.every((exercise) => MonthlyStats.isCardio(exercise, null));
      final ok = await _health.writeWorkoutData(
        activityType: cardioOnly
            ? HealthWorkoutActivityType.CROSS_TRAINING
            : HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        start: workout.timestamp,
        end: workout.timestamp.add(Duration(seconds: workout.durationSeconds)),
        totalDistance: _distanceMeters(completed),
        title: workout.workoutName,
        recordingMethod: RecordingMethod.manual,
      );
      if (ok) {
        // Keep the list short; only recent workouts can be finished again.
        await prefs.setStringList(
            _savedKey(uid), [...saved.reversed.take(199), workout.id]);
      }
    } catch (error) {
      debugPrint('Apple Health save skipped: $error');
    }
  }

  /// Total recorded distance with a known unit, or null when none is known.
  static int? _distanceMeters(List<WorkoutExerciseLog> exercises) {
    var meters = 0.0;
    for (final set in exercises.expand((e) => e.sets)) {
      if (!set.isCompleted || set.isSuperSetRest) continue;
      final distance = set.distance;
      if (distance == null || !distance.isFinite || distance <= 0) continue;
      if (set.distanceUnit == 'km') meters += distance * 1000;
      if (set.distanceUnit == 'mi') meters += distance * 1609.344;
    }
    return meters > 0 ? meters.round() : null;
  }
}
