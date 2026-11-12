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

  Future<WorkoutNotifier> setUp(List<DateTime?> reminders,
      {DateTime Function()? clock}) async {
    final directory = await Directory.systemTemp.createTemp('logging-flow-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final notifier = WorkoutNotifier(SyncService(OfflineCloud(), storage),
        storageService: storage);
    notifier.remind = (at) async => reminders.add(at);
    if (clock != null) notifier.clock = clock;
    await notifier.ready;
    return notifier;
  }

  final press = Exercise(
      id: 'press', name: 'Press', muscleGroup: 'Chest', equipment: 'Barbell');

  test('entering set 1 fills the later sets, which stay editable', () async {
    final notifier = await setUp([]);
    notifier.startWorkout();
    notifier.addExercise(press);
    final sets = notifier.currentWorkout!.exercises.single.sets;
    expect(sets.length, greaterThan(2));

    notifier.updateSet('press', 0, weight: 60, weightUnit: 'kg', reps: 8);
    for (final set in sets) {
      expect((set.weight, set.weightUnit, set.reps), (60.0, 'kg', 8));
    }

    // Changing a later set fills the sets after it, and keeps its own
    // value when set 1 changes again.
    notifier.updateSet('press', 1, weight: 65, weightUnit: 'kg');
    expect(sets[2].weight, 65, reason: 'follows set 2');
    notifier.updateSet('press', 0, weight: 62.5, weightUnit: 'kg');
    expect(sets[0].weight, 62.5);
    expect(sets[1].weight, 65, reason: 'edited by hand');

    // Completed sets never change.
    notifier.toggleSetCompletion('press', 2);
    notifier.updateSet('press', 0, reps: 5);
    expect(sets[2].reps, 8);
    expect(sets[1].reps, 5);
    notifier.resetWorkout();
    notifier.dispose();
  });

  test('a reminder is due 15 minutes after the last change', () async {
    final reminders = <DateTime?>[];
    var now = DateTime(2026, 11, 12, 9);
    final notifier = await setUp(reminders, clock: () => now);
    notifier.startWorkout();
    expect(reminders.last, DateTime(2026, 11, 12, 9, 15));

    notifier.addExercise(press);
    now = now.add(const Duration(seconds: 10));
    notifier.updateSet('press', 0, reps: 9);
    expect(reminders.length, 1, reason: 'typing does not reschedule');

    now = now.add(const Duration(minutes: 4));
    notifier.toggleSetCompletion('press', 0);
    expect(reminders.last, now.add(WorkoutNotifier.reminderAfter));

    notifier.resetWorkout();
    expect(reminders.last, isNull, reason: 'cancelled when the workout ends');
    notifier.dispose();
  });

  test('a saved workout\'s time can be corrected', () async {
    final notifier = await setUp([]);
    notifier.startWorkout();
    notifier.addExercise(press);
    notifier.toggleSetCompletion('press', 0);
    final workout = notifier.currentWorkout!;
    await notifier.finishWorkoutWithData(workout, 125 * 60, '', null);
    final saved = notifier.workoutHistory.firstWhere((w) => w.id == workout.id);
    expect(saved.durationSeconds, 125 * 60);

    await notifier.updateWorkoutDuration(saved, 52 * 60);
    expect(
        notifier.workoutHistory
            .firstWhere((w) => w.id == workout.id)
            .durationSeconds,
        52 * 60);
    notifier.dispose();
  });
}
