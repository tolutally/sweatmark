import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/each_side.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/monthly_stats.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/workout_result.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'cardio_session_test.dart' show OfflineCloud;

Exercise lift(String id, String name, String equipment) => Exercise(
    id: id,
    name: name,
    muscleGroup: 'Back',
    equipment: equipment,
    exerciseType: ExerciseType.weightedStrength);

WorkoutLog workout(DateTime when, List<WorkoutExerciseLog> exercises) =>
    WorkoutLog(
        workoutName: 'Pull',
        timestamp: when,
        durationSeconds: 3600,
        exercises: exercises);

WorkoutSet done(double kg, int reps, {double? rightKg, int? right}) =>
    WorkoutSet(
        weight: kg,
        weightUnit: 'kg',
        reps: reps,
        weightRight: rightKg,
        repsRight: right,
        isCompleted: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only one arm, one leg and alternating moves are each side', () {
    bool on(String name, [String equipment = '']) =>
        EachSide.defaultFor(name, equipment: equipment);
    expect(on('Dumbbell One Arm Bent-Over Row'), isTrue);
    expect(on('Dumbbell Single-Arm Bent-Over Row'), isTrue);
    expect(on('Single Leg Split Squat'), isTrue);
    expect(on('Barbell Alternate Bicep Curl'), isTrue);
    expect(on('Walking Lunge'), isTrue);
    expect(on('Cable Glute Kickback'), isTrue);
    expect(on('Band Single-Arm Twisting Chest Press'), isTrue);
    // Both sides together: whole sets, and no each side at all.
    expect(on('Dumbbell Bench Press', 'Dumbbell'), isFalse);
    expect(on('Dumbbell Bicep Curl', 'Dumbbell'), isFalse);
    expect(on('Barbell Bent-Over Row', 'Barbell'), isFalse);
    expect(on('Cable Two Arm Tricep Kickback'), isFalse);
    expect(on('Lat Pulldown', 'Cable'), isFalse);
    // Alternating core moves have no per-side weight.
    expect(on('Alternating Heel Touches'), isFalse);
    expect(on('Barbell Seated Alternate Leg Raise'), isFalse);
    expect(EachSide.defaultFor('Single Arm Row', type: 'cardio'), isFalse);
  });

  test('each side is saved; older logs say nothing about it', () {
    final log = WorkoutExerciseLog(
        exerciseId: 'x', eachSide: true, sets: [done(20, 10, right: 8)]);
    final back = WorkoutExerciseLog.fromJson(log.toJson());
    expect((back.eachSide, back.sideSaved, back.sets.single.repsRight),
        (true, true, 8));

    final old = WorkoutExerciseLog.fromJson({
      'exerciseId': 'x',
      'sets': [done(40, 10).toJson()]
    });
    expect((old.eachSide, old.sideSaved), (false, false));
    expect(old.toJson().containsKey('eachSide'), isFalse,
        reason: 're-saving an old workout must not invent a choice');
  });

  test('each side counts both sides in volume; whole sets count once', () {
    final row = WorkoutExerciseLog(
        exerciseId: 'row',
        exerciseName: 'Dumbbell One Arm Row',
        eachSide: true,
        sets: [done(20, 10), done(20, 10, rightKg: 15, right: 8)]);
    final bench = WorkoutExerciseLog(
        exerciseId: 'bench',
        exerciseName: 'Dumbbell Bench Press',
        sets: [done(40, 10)]);
    final log = workout(DateTime(2026, 11, 20), [row, bench]);

    // 20×10 + 20×10, then left 20×10 + right 15×8, then 40×10
    final month = MonthlyStats.calculate([log], DateTime(2026, 11),
        now: DateTime(2026, 11, 26));
    expect(month.volumeKg, 400 + 320 + 400);
    expect(month.reps, 20 + 18 + 10);

    final result = WorkoutResultData.fromWorkout(
        workout: log,
        history: [log],
        records: const [],
        weightUnit: 'kg',
        distanceUnit: 'km',
        weeklyGoals: const {});
    expect(result.volumeLabel, '1,120 kg');
    expect(result.exercises.first.resultLabel, '20 kg × 10 each side');
    String kg(double w) => '${w.toStringAsFixed(0)} kg';
    expect(row.setText(row.sets.first, kg), '20 kg × 10 each side');
    expect(row.setText(row.sets.last, kg), 'L 20 kg × 10 / R 15 kg × 8');
  });

  test('records compare each side with each side, using the weaker side', () {
    final before = workout(DateTime(2026, 11, 1), [
      WorkoutExerciseLog(
          exerciseId: 'db-row',
          exerciseName: 'Dumbbell Bent-Over Row',
          sets: [done(40, 10)]),
    ]);
    final after = workout(DateTime(2026, 11, 8), [
      WorkoutExerciseLog(
          exerciseId: 'db-row',
          exerciseName: 'Dumbbell Bent-Over Row',
          eachSide: true,
          sets: [done(22, 10, rightKg: 20, right: 12)]),
    ]);
    final records = PRService.records([before, after]);
    expect(records, hasLength(2),
        reason: '22 kg each side is not compared with 40 kg for both');
    final side = records.firstWhere((r) => r.eachSide);
    expect(side.label('kg'), '20 kg × 12 each side',
        reason: 'the weaker side counts: right 20 kg is under left 22 kg');
    expect(records.firstWhere((r) => !r.eachSide).label('kg'), '40 kg × 10');
  });

  group('logging', () {
    late Directory dir;
    Future<WorkoutNotifier> notifier(
        {List<WorkoutLog> history = const []}) async {
      final storage = StorageService(
          account: AccountStorage('test', documentsDirectory: () async => dir));
      for (final log in history) {
        await storage.saveWorkout(log);
      }
      final n = WorkoutNotifier(SyncService(OfflineCloud(), storage),
          storageService: storage)
        ..remind = (_) async {};
      await n.ready;
      return n;
    }

    setUp(() async => dir = await Directory.systemTemp.createTemp('side-'));

    test('new exercises start each side by default and can be switched',
        () async {
      final n = await notifier();
      n.startWorkout();
      n.addExercise(lift('db-row', 'Dumbbell One Arm Row', 'Dumbbell'));
      n.addExercise(lift('bb-row', 'Barbell Row', 'Barbell'));
      final logs = n.currentWorkout!.exercises;
      expect(logs.map((e) => e.eachSide), [true, false]);

      final sets = logs.first.sets;
      n.updateRightSide('db-row', 0, weight: 15, reps: 8);
      expect((sets[0].weightRight, sets[0].repsRight), (15, 8));
      expect((sets[1].weightRight, sets[1].repsRight), (15, 8),
          reason: 'later open sets follow, like the left side');
      n.updateRightSide('db-row', 0, clearWeight: true);
      expect(sets[0].weightRight, isNull,
          reason: 'an empty box matches the left again');
      n.setEachSide('db-row', false);
      expect((logs.first.eachSide, sets[0].repsRight), (false, null));
      n.resetWorkout();
      n.dispose();
    });

    test('your last choice for a one-sided exercise wins over the default',
        () async {
      final chosen = WorkoutExerciseLog(
          exerciseId: 'sa-row',
          exerciseName: 'Dumbbell Single-Arm Row',
          eachSide: false,
          sets: [done(20, 10)]);
      // Logged before the setting existed: says nothing.
      final legacy = WorkoutExerciseLog.fromJson({
        'exerciseId': 'lunge',
        'exerciseName': 'Dumbbell Lunge',
        'sets': [done(30, 10).toJson()]
      });
      // Turned on long ago for a two-sided exercise: never again.
      final bench = WorkoutExerciseLog(
          exerciseId: 'db-bench',
          exerciseName: 'Dumbbell Bench Press',
          eachSide: true,
          sets: [done(20, 10)]);
      final n = await notifier(history: [
        workout(DateTime(2026, 11, 20), [chosen, legacy, bench])
      ]);
      n.startWorkout();
      n.addExercise(lift('sa-row', 'Dumbbell Single-Arm Row', 'Dumbbell'));
      n.addExercise(lift('lunge', 'Dumbbell Lunge', 'Dumbbell'));
      n.addExercise(lift('db-bench', 'Dumbbell Bench Press', 'Dumbbell'));
      expect(n.currentWorkout!.exercises.map((e) => e.eachSide),
          [false, true, false]);
      n.setEachSide('db-bench', true);
      expect(n.currentWorkout!.exercises.last.eachSide, isFalse,
          reason: 'not available for two-sided exercises');
      n.resetWorkout();
      n.dispose();
    });

    test('a custom exercise marked one-sided gets each side', () async {
      final n = await notifier();
      n.startWorkout();
      final custom = Exercise(
          id: 'custom_1',
          name: 'Landmine Press',
          muscleGroup: 'Shoulders',
          equipment: 'Barbell',
          source: 'custom',
          oneSided: true);
      expect(Exercise.fromJson(custom.toJson()).oneSided, isTrue);
      n.addExercise(custom);
      n.addExercise(Exercise(
          id: 'custom_2',
          name: 'Landmine Squat',
          muscleGroup: 'Legs',
          equipment: 'Barbell',
          source: 'custom'));
      final logs = n.currentWorkout!.exercises;
      expect(logs.map((e) => (e.eachSide, e.canEachSide)),
          [(true, true), (false, false)]);
      // Saved with the workout, so it is still offered later.
      final saved = WorkoutExerciseLog.fromJson(logs.first.toJson());
      expect(saved.canEachSide, isTrue);
      n.setEachSide('custom_2', true);
      expect(logs.last.eachSide, isFalse);
      n.resetWorkout();
      n.dispose();
    });
  });
}
