import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/pr_service.dart';

WorkoutLog workout(int day, List<WorkoutSet> sets) => WorkoutLog(
        workoutName: 'Press',
        timestamp: DateTime(2026, 1, day),
        durationSeconds: 60,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'press', exerciseName: 'Press', sets: sets)
        ]);
WorkoutSet set(double weight, String? unit, {int reps = 5, bool done = true}) =>
    WorkoutSet(weight: weight, weightUnit: unit, reps: reps, isCompleted: done);
void main() {
  test('incomplete heavy sets never become records', () {
    expect(
        PRService().detectPersonalRecords(
            workout(2, [set(200, 'kg', done: false), set(50, 'kg')]), [
          workout(1, [set(60, 'kg')])
        ]),
        isEmpty);
  });
  test('compares pounds and kilograms consistently', () {
    expect(
        PRService().detectPersonalRecords(workout(2, [set(100, 'lb')]), [
          workout(1, [set(50, 'kg')])
        ]),
        isEmpty);
    expect(
        PRService().detectPersonalRecords(workout(2, [set(120, 'lb')]), [
          workout(1, [set(50, 'kg')])
        ]),
        ['Press']);
  });
  test('more reps at equal weight is a record, first session is baseline', () {
    expect(
        PRService()
            .detectPersonalRecords(workout(2, [set(50, 'kg', reps: 6)]), [
          workout(1, [set(50, 'kg')])
        ]),
        ['Press']);
    expect(PRService().detectPersonalRecords(workout(2, [set(50, 'kg')]), []),
        isEmpty);
  });
  test('legacy units are unknown rather than silently interpreted', () {
    final legacy =
        WorkoutSet.fromJson({'weight': 100, 'reps': 5, 'isCompleted': true});
    expect(legacy.weightKg, isNull);
    expect(PRService.bestSet([legacy]), isNull);
    expect(legacy.weightLabel, contains('unit unknown'));
  });
  test('serialization and repeating retain unit and cardio fields', () {
    final original = WorkoutSet(
        weight: 50,
        weightUnit: 'kg',
        reps: 5,
        isCompleted: true,
        distance: 2,
        durationSeconds: 90);
    final repeated =
        WorkoutSet.fromJson(original.toJson()).copyWith(isCompleted: false);
    expect(repeated.weightUnit, 'kg');
    expect(repeated.weightKg, 50);
    expect(repeated.durationSeconds, 90);
    expect(repeated.distance, 2);
    expect(repeated.isCompleted, false);
  });
}
