import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../models/workout_model.dart';

/// Local commits never wait for a network acknowledgement. Pending changes are
/// replayed on startup, foregrounding, and periodically until acknowledged.
class SyncService with WidgetsBindingObserver {
  final FirebaseService _firebaseService;
  final StorageService _storageService;
  Timer? _retryTimer;
  bool _disposed = false;
  Future<void>? _processing;
  Future<void>? _exerciseProcessing;
  String? get userId => _storageService.userId;
  bool get _isCurrentAccount =>
      !_disposed &&
      userId != null &&
      _firebaseService.currentUser?.uid == userId;

  SyncService(this._firebaseService, this._storageService) {
    WidgetsBinding.instance.addObserver(this);
    _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) => _retry());
    _retry();
  }

  void _retry() {
    unawaited(flushPending().catchError((Object error) {
      debugPrint('Sync deferred: $error');
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retry();
  }

  Future<void> flushPending() {
    if (!_isCurrentAccount) return Future.value();
    return Future.wait([
      _processing ??= _flushWorkouts().whenComplete(() => _processing = null),
      _exerciseProcessing ??=
          _flushExercises().whenComplete(() => _exerciseProcessing = null),
    ]).then((_) {});
  }

  Future<void> _flushExercises() async {
    final pending = await _storageService.pendingExercises();
    for (final entry in pending.entries) {
      if (!_isCurrentAccount) return;
      final operation = entry.value;
      try {
        if (operation['delete'] == true) {
          await _firebaseService.deleteCustomExercise(userId!, entry.key);
        } else {
          await _firebaseService.saveCustomExercise(
              userId!, Map<String, dynamic>.from(operation['exercise']));
        }
        if (!_isCurrentAccount) return;
        await _storageService.acknowledgeExercise(
            entry.key, operation['revision'] as int);
      } catch (_) {
        // Retain this operation until the server acknowledges it.
      }
    }
  }

  Future<void> _flushWorkouts() async {
    final pending = await _storageService.pendingWorkouts();
    for (final entry in pending.entries) {
      if (!_isCurrentAccount) return;
      final operation = entry.value;
      final workout =
          WorkoutLog.fromJson(Map<String, dynamic>.from(operation['workout']));
      // Do not timeout writes: Firestore may still finish a timed-out write,
      // allowing an older operation to overtake a newer edit or deletion.
      try {
        if (operation['delete'] == true) {
          await _firebaseService.deleteWorkout(userId!, workout);
        } else {
          await _firebaseService.saveWorkout(userId!, workout);
        }
        if (!_isCurrentAccount) return;
        await _storageService.acknowledgeWorkout(
            entry.key, operation['revision'] as int);
      } catch (_) {
        // Keep the durable operation for the next attempt, without a retry cap.
        continue;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> migrateLocalWorkouts(String userId) async {
    if (userId == this.userId) await flushPending();
  }

  Future<void> syncWorkout(String? userId, WorkoutLog workout) async {
    if (_disposed || (userId != null && userId != this.userId)) return;
    await _storageService.saveWorkout(workout);
    _retry();
  }

  Future<List<WorkoutLog>> getWorkouts(String? userId) async {
    if (_disposed || (userId != null && userId != this.userId)) return [];
    if (_isCurrentAccount) {
      try {
        final revision = await _storageService.workoutRevision();
        _retry();
        final cloud = await _firebaseService
            .getWorkouts(this.userId!)
            .timeout(const Duration(seconds: 3));
        if (!_isCurrentAccount) return [];
        await _storageService.mergeCloudWorkouts(cloud,
            expectedRevision: revision);
      } catch (_) {
        // A failed fetch never replaces locally saved history with an empty list.
      }
    }
    if (_disposed) return [];
    return _storageService.getWorkouts();
  }

  Future<List<WorkoutLog>> getRecentWorkouts(String? userId, int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (await getWorkouts(userId))
        .where((w) => w.timestamp.isAfter(cutoff))
        .toList();
  }

  Future<void> deleteWorkout(WorkoutLog workout) async {
    if (_disposed) return;
    await _storageService.deleteWorkout(workout);
    _retry();
  }
}
