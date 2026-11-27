import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'cardio_session_test.dart' show OfflineCloud;
import 'each_side_test.dart' show done, lift, workout;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WorkoutNotifier notifier(Directory dir) {
    final storage = StorageService(
        account: AccountStorage('test', documentsDirectory: () async => dir));
    return WorkoutNotifier(SyncService(OfflineCloud(), storage),
        storageService: storage)
      ..remind = (_) async {};
  }

  test('Start right after the app opens resumes the workout in progress',
      () async {
    final dir = await Directory.systemTemp.createTemp('start-');
    final first = notifier(dir);
    await first.ready;
    first.startWorkout();
    first.addExercise(lift('db-row', 'Dumbbell One Arm Row', 'Dumbbell'));
    await first.saveDraftWorkout();
    first.dispose();

    // Tapped before anything has loaded.
    final second = notifier(dir);
    final started = await second.resumeOrStart();
    expect(started, isFalse);
    expect(second.currentWorkout!.exercises.single.exerciseId, 'db-row');
    second.resetWorkout();
    second.dispose();
  });

  test('with nothing in progress, Start starts a new workout', () async {
    final dir = await Directory.systemTemp.createTemp('start-');
    final n = notifier(dir);
    expect(await n.resumeOrStart(), isTrue);
    expect(n.isWorkoutActive, isTrue);
    n.resetWorkout();
    n.dispose();
  });

  test('warm-ups are only what you mark, and never records', () async {
    final dir = await Directory.systemTemp.createTemp('warm-');
    final n = notifier(dir);
    await n.ready;
    n.startWorkout();
    n.addExercise(lift('db-row', 'Dumbbell One Arm Row', 'Dumbbell'));
    final sets = n.currentWorkout!.exercises.single.sets;
    n.updateSet('db-row', 0, weight: 20, weightUnit: 'lb', reps: 10);
    expect(sets.first.isWarmup, isFalse,
        reason: 'a light first set is not a warm-up unless you say so');
    n.toggleWarmup('db-row', 0);
    expect(sets.first.isWarmup, isTrue);
    expect(WorkoutSet.fromJson(sets.first.toJson()).isWarmup, isTrue);
    n.resetWorkout();
    n.dispose();

    final warm = done(100, 5)..isWarmup = true;
    final log = workout(DateTime(2026, 11, 26), [
      WorkoutExerciseLog(
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          sets: [warm, done(80, 8)]),
    ]);
    final records = PRService.records([log]);
    expect(records.single.label('kg'), '80 kg × 8');
  });

  test('an exercise is in a workout once', () async {
    final dir = await Directory.systemTemp.createTemp('once-');
    final n = notifier(dir);
    await n.ready;
    n.startWorkout();
    final row = lift('db-row', 'Dumbbell One Arm Row', 'Dumbbell');
    n.addExercise(row);
    n.updateSet('db-row', 0, weight: 20, weightUnit: 'kg', reps: 10);
    n.addExercise(row);
    n.addExerciseFromTemplate(name: 'Row', exerciseId: 'db-row');
    final logs = n.currentWorkout!.exercises;
    expect(logs, hasLength(1), reason: 'a second copy would be mixed up');
    expect(logs.single.sets.first.reps, 10, reason: 'nothing was replaced');
    expect(n.hasExercise('db-row'), isTrue);
    n.resetWorkout();
    n.dispose();
  });
}
