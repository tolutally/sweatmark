import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/firebase_service.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/state/workout_notifier.dart';

class OfflineCloud implements FirebaseService {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(WorkoutNotifier, SyncService, StorageService)> setUp() async {
    final directory = await Directory.systemTemp.createTemp('idle-timer-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final sync = SyncService(OfflineCloud(), storage);
    final notifier = WorkoutNotifier(sync, storageService: storage);
    await notifier.ready;
    return (notifier, sync, storage);
  }

  final press = Exercise(
      id: 'press', name: 'Press', muscleGroup: 'Chest', equipment: 'Barbell');

  test('clock stops at the last activity after 10 idle minutes and resumes',
      () async {
    final (notifier, _, _) = await setUp();
    var now = DateTime(2026, 11, 8, 9);
    notifier.clock = () => now;
    notifier.startWorkout();
    notifier.addExercise(press);
    notifier.updateSet('press', 0, weight: 60, reps: 5, weightUnit: 'kg');
    notifier.toggleSetCompletion('press', 0); // clock starts at 9:00

    now = now.add(const Duration(minutes: 4));
    notifier.toggleSetCompletion('press', 1); // last activity 9:04
    now = now.add(const Duration(minutes: 9, seconds: 59));
    notifier.onAppResumed();
    expect(notifier.isTimerPaused, isFalse);
    expect(notifier.elapsedSeconds, 13 * 60 + 59);

    now = now.add(const Duration(seconds: 1)); // 10 minutes idle
    notifier.onAppResumed();
    expect(notifier.isTimerPaused, isTrue);
    expect(notifier.elapsedSeconds, 4 * 60, reason: 'idle time not counted');

    now = now.add(const Duration(minutes: 30));
    notifier.onAppResumed();
    expect(notifier.elapsedSeconds, 4 * 60, reason: 'stays stopped');

    notifier.resumeTimer();
    expect(notifier.isTimerPaused, isFalse);
    now = now.add(const Duration(minutes: 2));
    notifier.onAppResumed();
    expect(notifier.elapsedSeconds, 6 * 60);
    notifier.resetWorkout();
    notifier.dispose();
  });

  test('logging a set while paused restarts the clock', () async {
    final (notifier, _, _) = await setUp();
    var now = DateTime(2026, 11, 8, 9);
    notifier.clock = () => now;
    notifier.startWorkout();
    notifier.addExercise(press);
    notifier.toggleSetCompletion('press', 0);
    now = now.add(const Duration(minutes: 15));
    notifier.onAppResumed();
    expect(notifier.isTimerPaused, isTrue);
    expect(notifier.elapsedSeconds, 0);

    notifier.toggleSetCompletion('press', 1);
    expect(notifier.isTimerPaused, isFalse);
    now = now.add(const Duration(minutes: 1));
    notifier.onAppResumed();
    expect(notifier.elapsedSeconds, 60);
    notifier.resetWorkout();
    notifier.dispose();
  });

  test('a paused clock survives saving and restoring the draft', () async {
    final (original, sync, storage) = await setUp();
    var now = DateTime(2026, 11, 8, 9);
    original.clock = () => now;
    original.startWorkout();
    original.addExercise(press);
    original.toggleSetCompletion('press', 0);
    now = now.add(const Duration(minutes: 5));
    original.toggleSetCompletion('press', 1);
    now = now.add(const Duration(minutes: 20));
    original.onAppResumed();
    expect(original.isTimerPaused, isTrue);
    await original.saveDraftWorkout();
    original.dispose();

    final restored = WorkoutNotifier(sync, storageService: storage);
    restored.clock = () => now.add(const Duration(hours: 1));
    await restored.ready;
    expect(restored.isWorkoutActive, isTrue);
    expect(restored.isTimerPaused, isTrue);
    expect(restored.elapsedSeconds, 5 * 60);
    restored.resetWorkout();
    restored.dispose();
  });
}
