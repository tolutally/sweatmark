import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/pr_service.dart';

WorkoutLog session(int day, List<WorkoutSet> sets,
        {String type = 'weightedStrength',
        String id = 'press',
        String name = 'Press',
        bool test = false}) =>
    WorkoutLog(
        workoutName: 'Workout',
        timestamp: DateTime(2026, 1, day),
        durationSeconds: 60,
        isTestData: test,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: id,
              exerciseName: name,
              exerciseType: type,
              sets: sets)
        ]);
WorkoutSet set(double? weight, int reps,
        {String? unit = 'kg', bool done = true}) =>
    WorkoutSet(weight: weight, weightUnit: unit, reps: reps, isCompleted: done);

void main() {
  test('one final record per workout, chronological baselines and ties', () {
    final records = PRService.records([
      session(3, [set(60, 8)]),
      session(1, [set(50, 8)]),
      session(2, [set(55, 8), set(60, 8), set(100, 3, done: false)]),
    ]);
    expect(records.length, 2);
    expect(records.first.isBaseline, true);
    expect(records.last.weightKg, 60);
    expect(records.last.setIndex, 1);
    expect(records.last.previous!.weightKg, 50);
  });
  test('bodyweight and additional weight are independent records', () {
    final records = PRService.records([
      session(1, [set(null, 10), set(10, 5)], type: 'bodyweightReps'),
      session(2, [set(null, 12), set(10, 6)], type: 'bodyweightReps'),
    ]);
    expect(records.length, 4);
    expect(records.where((r) => !r.isBaseline).length, 2);
    expect(records.last.label('lb'), '22 lb × 6');
  });
  test('excludes cardio, holds, assisted, test data and invalid values', () {
    expect(
        PRService.records([
          session(1, [set(50, 5)], type: 'cardio'),
          session(2, [set(50, 5)], type: 'timedHold'),
          session(3, [set(50, 5)], name: 'Assisted pull up'),
          session(4, [set(50, 5)], test: true),
          session(5, [
            set(50, 5, unit: null),
            set(double.nan, 5),
            set(-1, 5),
            set(50, 0),
            WorkoutSet(
                weight: 50,
                weightUnit: 'kg',
                reps: 5,
                isCompleted: true,
                isSuperSetRest: true)
          ]),
        ]),
        isEmpty);
  });
  test('equivalent units tie and more reps improve, snapshots are immutable',
      () {
    final oldSet = set(50, 5);
    final records = PRService.records([
      session(1, [oldSet]),
      session(2, [set(50 * 2.2046226218, 5, unit: 'lb')]),
      session(3, [set(50, 6)]),
    ]);
    oldSet.weight = 90;
    expect(records.length, 2);
    expect(records.first.weightKg, 50);
    expect(records.last.previous!.reps, 5);
  });
  test('editing/deleting history recomputes records and IDs remain separate',
      () {
    final first = session(1, [set(50, 5)]);
    final second = session(2, [set(60, 5)]);
    expect(PRService.records([second]).single.isBaseline, true);
    second.exercises.single.sets.single.weight = 40;
    expect(PRService.records([first, second]).length, 1);
    expect(
        PRService.bests([
          first,
          session(3, [set(70, 5)], id: 'other')
        ]).length,
        2);
  });
  test('month/year record timestamps retain exact logged date', () {
    final records = PRService.records([
      session(31, [set(50, 5)]),
      session(32, [set(60, 5)])
    ]);
    expect(records.first.timestamp.month, 1);
    expect(records.last.timestamp.month, 2);
    expect(records.last.timestamp.year, 2026);
  });
}
