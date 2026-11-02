import 'dart:io';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/services/firebase_service.dart';
import 'package:sweatmark/state/workout_notifier.dart';

class OfflineCloud implements FirebaseService {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PR celebrations survive restore and do not replay on rechecking',
      () async {
    final directory = await Directory.systemTemp.createTemp('pr-draft-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final sync = SyncService(OfflineCloud(), storage);
    final baseline = WorkoutLog(
        workoutName: 'Old',
        timestamp: DateTime(2025),
        durationSeconds: 30,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'press',
              exerciseType: 'weightedStrength',
              sets: [
                WorkoutSet(
                    weight: 50, weightUnit: 'kg', reps: 5, isCompleted: true)
              ])
        ]);
    await sync.syncWorkout(null, baseline);
    final original = WorkoutNotifier(sync, storageService: storage);
    await original.ready;
    original.startWorkout();
    original.addExercise(Exercise(
        id: 'press',
        name: 'Press',
        muscleGroup: 'Chest',
        equipment: 'Barbell'));
    original.updateSet('press', 0, weight: 60, reps: 5, weightUnit: 'kg');
    var celebrations = 0;
    original.onPersonalRecords = (records) => celebrations += records.length;
    original.toggleSetCompletion('press', 0);
    expect(celebrations, 1);
    await original.saveDraftWorkout();
    original.resetWorkout();
    original.dispose();
    final restored = WorkoutNotifier(sync, storageService: storage);
    await restored.ready;
    restored.onPersonalRecords = (records) => celebrations += records.length;
    restored.toggleSetCompletion('press', 0);
    expect(restored.activeRecords, isEmpty);
    restored.toggleSetCompletion('press', 0);
    expect(celebrations, 1);
    restored.updateSet('press', 0, weight: 40);
    expect(restored.activeRecords, isEmpty);
    expect(restored.personalRecords.single.weightKg, 50);
    restored.resetWorkout();
    restored.dispose();
    sync.dispose();
    await storage.getDraftWorkout();
    await directory.delete(recursive: true);
  });
  test('draft restores exercise metadata, tracking fields and collapsed cards',
      () async {
    final directory = await Directory.systemTemp.createTemp('draft-display-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final sync = SyncService(OfflineCloud(), storage);
    final original = WorkoutNotifier(sync, storageService: storage);
    await original.ready;
    original.startWorkout();
    original.addExercise(Exercise(
        id: 'bike',
        name: 'Bike',
        muscleGroup: 'legs',
        equipment: 'bike',
        exerciseType: ExerciseType.cardio,
        gifUrl: 'https://example.com/bike.gif'));
    original.toggleExerciseCollapsed('bike');
    original.toggleExerciseCollapsed('superset_group');
    original.setExerciseFields(
        'bike', [SetFieldType.time, SetFieldType.resistance]);
    await original.saveDraftWorkout();
    original.resetWorkout();
    original.dispose();

    final restored = WorkoutNotifier(sync, storageService: storage);
    await restored.ready;
    expect(restored.isExerciseCollapsed('bike'), isTrue);
    expect(restored.isExerciseCollapsed('superset_group'), isTrue);
    expect(restored.exerciseFields('bike'),
        [SetFieldType.time, SetFieldType.resistance]);
    expect(restored.currentWorkout!.exercises.single.exerciseType, 'cardio');
    expect(restored.currentWorkout!.exercises.single.gifUrl,
        'https://example.com/bike.gif');
    restored.toggleExerciseCollapsed('bike');
    await restored.saveDraftWorkout();
    expect((await storage.getDraftWorkout())!['collapsedExercises'],
        ['superset_group']);
    restored.resetWorkout();
    expect(restored.exerciseFields('bike'), isNull);
    expect(restored.collapsedExercises, isEmpty);
    restored.dispose();
    sync.dispose();
    await directory.delete(recursive: true);
  });
  test(
      'repeat keeps exact set count and units; clearing an input clears stored data',
      () async {
    final directory = await Directory.systemTemp.createTemp('logging-flow-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final sync = SyncService(OfflineCloud(), storage);
    final notifier = WorkoutNotifier(sync, storageService: storage);
    await notifier.ready;
    final old = WorkoutLog(
        workoutName: 'Press',
        timestamp: DateTime(2026),
        durationSeconds: 60,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'custom-press',
              exerciseName: 'Custom press',
              averageHeartRate: 150,
              intensity: 'High',
              sets: [
                WorkoutSet(
                    weight: 50, weightUnit: 'kg', reps: 5, isCompleted: true),
                WorkoutSet(
                    weight: 55, weightUnit: 'kg', reps: 3, isCompleted: true)
              ])
        ]);
    await notifier.repeatWorkout(old);
    expect(notifier.currentWorkout!.exercises.single.averageHeartRate, isNull);
    expect(notifier.currentWorkout!.exercises.single.intensity, isNull);
    notifier.updateCardioDetails('custom-press',
        averageHeartRate: 130, intensity: 'Low');
    expect(notifier.currentWorkout!.exercises.single.averageHeartRate, 130);
    expect(notifier.currentWorkout!.exercises.single.intensity, 'Low');
    expect(
        () =>
            notifier.updateCardioDetails('custom-press', averageHeartRate: -1),
        throwsArgumentError);
    notifier.updateCardioDetails('custom-press');
    expect(notifier.currentWorkout!.exercises.single.averageHeartRate, isNull);
    expect(notifier.currentWorkout!.exercises.single.intensity, isNull);
    final sets = notifier.currentWorkout!.exercises.single.sets;
    expect(sets.length, 2);
    expect(sets.every((s) => !s.isCompleted), isTrue);
    expect(sets.first.weightUnit, 'kg');
    expect(sets.last.weight, 55);
    notifier.updateSet('custom-press', 0, clearWeight: true, clearReps: true);
    expect(sets.first.weight, isNull);
    expect(sets.first.weightUnit, isNull);
    expect(sets.first.reps, isNull);
    expect(old.exercises.single.sets.first.weight, 50);
    notifier.resetWorkout();
    notifier.dispose();
    sync.dispose();
    await storage.pendingWorkouts();
    await directory.delete(recursive: true);
  });
}
