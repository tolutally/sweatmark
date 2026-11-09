import 'package:intl/intl.dart';
import '../data/exercise_catalog.dart';
import '../services/pr_service.dart';
import 'exercise_model.dart';
import 'monthly_stats.dart';
import 'weekly_progress.dart';
import 'workout_model.dart';

/// The same saved-workout snapshot powers the summary and share preview.
class WorkoutResultData {
  final WorkoutLog workout;
  final String durationLabel;
  final String dateLabel;
  final int completedSets;
  final int exerciseCount;
  final int streakWeeks;
  final int newRecordCount;
  final String volumeLabel;
  final List<WorkoutResultExercise> exercises;

  /// The standout set: a new record if there is one, otherwise the strongest
  /// lift by estimated one-rep max, then the most reps, the longest hold or
  /// the longest cardio session. Null only when no completed set has any
  /// measurement.
  final WorkoutResultTopSet? topSet;

  /// Main muscles, most sets first, then supporting muscles from the
  /// exercise library that are not already primary.
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  const WorkoutResultData._({
    required this.workout,
    required this.durationLabel,
    required this.dateLabel,
    required this.completedSets,
    required this.exerciseCount,
    required this.streakWeeks,
    required this.newRecordCount,
    required this.volumeLabel,
    required this.exercises,
    required this.topSet,
    required this.primaryMuscles,
    required this.secondaryMuscles,
  });

  factory WorkoutResultData.fromWorkout({
    required WorkoutLog workout,
    required List<WorkoutLog> history,
    required List<PersonalRecord> records,
    required String weightUnit,
    required String distanceUnit,
    required Map<String, int> weeklyGoals,
    Map<String, String> catalogNames = const {},
    Map<String, Exercise> catalog = const {},
  }) {
    final grouped = <String, List<WorkoutExerciseLog>>{};
    var completedSets = 0;
    var knownWeightedSets = 0;
    var volumeKg = 0.0;
    for (final exercise in workout.exercises) {
      final sets = _completed(exercise.sets);
      if (sets.isEmpty) continue;
      grouped.putIfAbsent(exercise.exerciseId, () => []).add(exercise);
      completedSets += sets.length;
      if (MonthlyStats.isCardio(exercise, null) ||
          exercise.exerciseType == 'timedHold') {
        continue;
      }
      for (final set in sets) {
        if (!_knownWeighted(set)) continue;
        final setVolume = set.weightKg! * set.reps!;
        if (!setVolume.isFinite) continue;
        final nextVolume = volumeKg + setVolume;
        if (!nextVolume.isFinite) continue;
        volumeKg = nextVolume;
        knownWeightedSets++;
      }
    }

    final matchingRecords = workout.isTestData
        ? <PersonalRecord>[]
        : records.where((record) => record.workoutId == workout.id).toList();
    final newKeys = matchingRecords
        .where((record) => !record.isBaseline)
        .map((record) => record.key)
        .toSet();
    final rows = <WorkoutResultExercise>[];
    Exercise? definition(String id) =>
        catalog[id] ?? catalog[ExerciseCatalog.canonicalId(id)];
    final primarySets = <String, int>{};
    final secondarySets = <String, int>{};
    // Top set: a new record first, then the most informative kind of set
    // (tier: known-unit lift > lift without a saved unit > reps > hold >
    // cardio), then the biggest within that kind.
    ({String name, String label, bool record, int tier, double score})? top;
    void consider(
        String name, String label, bool record, int tier, double score) {
      if (!score.isFinite || score <= 0) return;
      final current = top;
      final better = current == null ||
          (record != current.record
              ? record
              : tier != current.tier
                  ? tier > current.tier
                  : score > current.score);
      if (better) {
        top = (
          name: name,
          label: label,
          record: record,
          tier: tier,
          score: score
        );
      }
    }

    for (final group in grouped.entries) {
      final snapshots = group.value;
      final sets =
          snapshots.expand((exercise) => _completed(exercise.sets)).toList();
      final names = snapshots
          .map((exercise) => exercise.exerciseName?.trim())
          .whereType<String>()
          .where((name) => name.isNotEmpty);
      final images = snapshots
          .map((exercise) => exercise.gifUrl?.trim())
          .whereType<String>()
          .where((image) => image.isNotEmpty);
      final exerciseRecords = matchingRecords
          .where((record) => record.exerciseId == group.key)
          .toList();
      final hasNewRecord = exerciseRecords.any((record) => !record.isBaseline);
      final displayedRecords = {
        for (final record in exerciseRecords)
          if (hasNewRecord ? !record.isBaseline : record.isBaseline)
            record.key: record,
      }.values;
      final recordLabel = displayedRecords
          .map((record) => record.label(weightUnit == 'lb' ? 'lb' : 'kg'))
          .join(' · ');
      final cardio =
          snapshots.any((exercise) => MonthlyStats.isCardio(exercise, null));
      final timed =
          snapshots.any((exercise) => exercise.exerciseType == 'timedHold');
      rows.add(WorkoutResultExercise(
        exerciseId: group.key,
        name: exerciseDisplayName(group.key,
            saved: names.firstOrNull, catalog: catalogNames),
        imageUrl: images.isEmpty ? null : images.first,
        resultLabel: recordLabel.isNotEmpty
            ? recordLabel
            : cardio
                ? _cardioResult(sets, distanceUnit)
                : timed
                    ? _timedResult(sets)
                    : _strengthResult(sets, weightUnit),
        isNewRecord: hasNewRecord,
        isBaseline:
            !hasNewRecord && exerciseRecords.any((record) => record.isBaseline),
      ));
      final row = rows.last;
      final known = definition(group.key);
      if (!cardio) {
        final group0 = snapshots
                .map((e) => e.muscleGroup?.trim())
                .whereType<String>()
                .where((m) => m.isNotEmpty)
                .firstOrNull ??
            known?.muscleGroup ??
            '';
        final primary = MonthlyStats.normalizeMuscle(group0);
        if (primary != 'Unspecified' && primary != 'Cardio') {
          primarySets[primary] = (primarySets[primary] ?? 0) + sets.length;
        }
        for (final muscle in known?.secondaryMuscles ?? const <String>[]) {
          final name = MonthlyStats.normalizeMuscle(muscle);
          if (name == 'Unspecified' || name == 'Cardio') continue;
          secondarySets[name] = (secondarySets[name] ?? 0) + sets.length;
        }
        final best = PRService.bestSet(sets.where(_knownWeighted));
        if (best != null) {
          consider(row.name, _strengthResult([best], weightUnit), hasNewRecord,
              4, best.weightKg! * (1 + best.reps! / 30));
        }
        for (final set in sets) {
          final weight = set.weight;
          final reps = set.reps ?? 0;
          if (_knownWeighted(set) || reps <= 0) continue;
          if (weight != null && weight.isFinite && weight > 0) {
            // Older sets saved a weight without kg or lb; show it as logged.
            consider(
                row.name,
                '${NumberFormat('#,##0.#').format(weight)} × $reps',
                hasNewRecord,
                3,
                weight * (1 + reps / 30));
          } else {
            consider(row.name, '$reps reps', hasNewRecord, 2, reps.toDouble());
          }
        }
        final hold = sets
            .map((set) => set.durationSeconds ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b);
        if (hold > 0 && sets.every((set) => (set.reps ?? 0) == 0)) {
          consider(
              row.name, _timedResult(sets), hasNewRecord, 1, hold.toDouble());
        }
      } else {
        final seconds =
            sets.fold<int>(0, (sum, set) => sum + (set.durationSeconds ?? 0));
        final distance = sets.fold<double>(
            0, (sum, set) => sum + (set.distance ?? 0).toDouble());
        consider(row.name, _cardioResult(sets, distanceUnit), hasNewRecord, 0,
            seconds > 0 ? seconds.toDouble() : distance);
      }
    }

    // The just-saved log may not yet be reflected in a provider's history list.
    // Replace by stable workout ID, then apply the same eligibility as stats.
    final deduplicated = <String, WorkoutLog>{
      for (final entry in history) entry.id: entry,
      workout.id: workout,
    };
    final streakHistory = deduplicated.values
        .where((entry) =>
            !entry.isTestData &&
            entry.exercises.any((exercise) => exercise.sets
                .any((set) => set.isCompleted && !set.isSuperSetRest)))
        .toList();
    final streak =
        WeeklyProgress.calculate(streakHistory, weeklyGoals, workout.timestamp);
    final displayWeightUnit = weightUnit == 'lb' ? 'lb' : 'kg';
    final volume = volumeKg * (displayWeightUnit == 'lb' ? 2.2046226218 : 1);
    return WorkoutResultData._(
      workout: workout,
      durationLabel: workout.durationSeconds > 0
          ? _duration(workout.durationSeconds)
          : 'Duration not recorded',
      dateLabel: DateFormat('MMM d, yyyy · h:mm a')
          .format(workout.timestamp.toLocal()),
      completedSets: completedSets,
      exerciseCount: rows.length,
      streakWeeks: streak.streak,
      newRecordCount: newKeys.length,
      volumeLabel: knownWeightedSets == 0 || !volume.isFinite
          ? '—'
          : '${NumberFormat('#,##0').format(volume)} $displayWeightUnit',
      exercises: List.unmodifiable(rows),
      topSet: switch (top) {
        null => null,
        final best => WorkoutResultTopSet(
            exerciseName: best.name,
            label: best.label,
            isNewRecord: best.record),
      },
      primaryMuscles: List.unmodifiable(_ranked(primarySets).take(5)),
      secondaryMuscles: List.unmodifiable(_ranked(secondarySets)
          .where((muscle) => !primarySets.containsKey(muscle))
          .take(6)),
    );
  }

  static List<String> _ranked(Map<String, int> sets) => (sets.entries.toList()
        ..sort((a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key)))
      .map((entry) => entry.key)
      .toList();

  static List<WorkoutSet> _completed(Iterable<WorkoutSet> sets) =>
      sets.where((set) => set.isCompleted && !set.isSuperSetRest).toList();

  static bool _knownWeighted(WorkoutSet set) =>
      (set.reps ?? 0) > 0 &&
      set.weight != null &&
      set.weight!.isFinite &&
      set.weight! > 0 &&
      ['kg', 'lb'].contains(set.weightUnit) &&
      set.weightKg != null &&
      set.weightKg!.isFinite &&
      set.weightKg! > 0;

  static String _strengthResult(List<WorkoutSet> sets, String unit) {
    final best = PRService.bestSet(sets.where(_knownWeighted));
    if (best != null) {
      final displayUnit = unit == 'lb' ? 'lb' : 'kg';
      final weight = best.weightKg! * (displayUnit == 'lb' ? 2.2046226218 : 1);
      if (weight.isFinite) {
        return '${NumberFormat('#,##0.#').format(weight)} $displayUnit × ${best.reps}';
      }
    }
    final unweightedReps = sets
        .where((set) =>
            (set.reps ?? 0) > 0 &&
            (set.weight == null || (set.weight!.isFinite && set.weight == 0)))
        .map((set) => set.reps!)
        .toList()
      ..sort();
    if (unweightedReps.isNotEmpty) return '${unweightedReps.last} reps';
    final unknownWeightReps = sets
        .where((set) =>
            (set.reps ?? 0) > 0 &&
            set.weight != null &&
            set.weight!.isFinite &&
            set.weight! > 0 &&
            !['kg', 'lb'].contains(set.weightUnit))
        .map((set) => set.reps!)
        .toList()
      ..sort();
    if (unknownWeightReps.isNotEmpty) {
      return '${unknownWeightReps.last} reps · weight unit not recorded';
    }
    // Older duration-only exercises may predate the saved exercise-type field.
    if (sets.any((set) => (set.durationSeconds ?? 0) > 0)) {
      return _timedResult(sets);
    }
    return 'Performance not recorded';
  }

  static String _timedResult(List<WorkoutSet> sets) {
    final durations = sets
        .map((set) => set.durationSeconds)
        .whereType<int>()
        .where((seconds) => seconds > 0)
        .toList()
      ..sort();
    return durations.isEmpty
        ? 'Time not recorded'
        : _duration(durations.last, precise: true);
  }

  static String _cardioResult(List<WorkoutSet> sets, String unit) {
    var seconds = 0;
    var distanceKm = 0.0;
    var knownDistances = 0;
    var unknownDistance = false;
    for (final set in sets) {
      if ((set.durationSeconds ?? 0) > 0) seconds += set.durationSeconds!;
      final distance = set.distance;
      if (distance == null || !distance.isFinite || distance <= 0) continue;
      if (!['km', 'mi'].contains(set.distanceUnit)) {
        unknownDistance = true;
        continue;
      }
      final converted = distance * (set.distanceUnit == 'mi' ? 1.609344 : 1);
      final nextDistance = distanceKm + converted;
      if (!converted.isFinite || !nextDistance.isFinite) continue;
      distanceKm = nextDistance;
      knownDistances++;
    }
    final displayUnit = unit == 'mi' ? 'mi' : 'km';
    final distance = distanceKm / (displayUnit == 'mi' ? 1.609344 : 1);
    final values = <String>[
      if (knownDistances > 0 && distance.isFinite)
        '${NumberFormat('#,##0.#').format(distance)} $displayUnit',
      if (seconds > 0) _duration(seconds),
      if (unknownDistance) 'Distance unit not recorded',
    ];
    return values.isEmpty ? 'Metrics not recorded' : values.join(' · ');
  }

  static String _duration(int seconds, {bool precise = false}) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (precise && seconds % 60 != 0) {
      return minutes < 60
          ? '${minutes}m ${seconds % 60}s'
          : '${minutes ~/ 60}h ${minutes % 60}m ${seconds % 60}s';
    }
    return minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class WorkoutResultExercise {
  final String exerciseId;
  final String name;
  final String? imageUrl;
  final String resultLabel;
  final bool isNewRecord;
  final bool isBaseline;

  const WorkoutResultExercise({
    required this.exerciseId,
    required this.name,
    this.imageUrl,
    required this.resultLabel,
    required this.isNewRecord,
    required this.isBaseline,
  });
}

/// The single standout result shown on the share image.
class WorkoutResultTopSet {
  final String exerciseName;
  final String label;
  final bool isNewRecord;

  const WorkoutResultTopSet({
    required this.exerciseName,
    required this.label,
    required this.isNewRecord,
  });
}
