import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/workout_result.dart';
import 'package:sweatmark/services/pr_service.dart';

WorkoutExerciseLog lift(String id, String muscle, double kg, int reps,
        {String type = 'weightedStrength'}) =>
    WorkoutExerciseLog(
        exerciseId: id,
        exerciseName: id,
        exerciseType: type,
        muscleGroup: muscle,
        sets: [
          WorkoutSet(
              weight: kg, weightUnit: 'kg', reps: reps, isCompleted: true),
          WorkoutSet(
              weight: kg, weightUnit: 'kg', reps: reps, isCompleted: true),
        ]);

Exercise def(String id, String name, String muscle, List<String> secondary) =>
    Exercise(
        id: id,
        name: name,
        muscleGroup: muscle,
        equipment: 'Machine',
        secondaryMuscles: secondary);

WorkoutResultData result(WorkoutLog workout, List<WorkoutLog> history,
        Map<String, Exercise> catalog) =>
    WorkoutResultData.fromWorkout(
        workout: workout,
        history: history,
        records: PRService.records(history),
        weightUnit: 'kg',
        distanceUnit: 'km',
        weeklyGoals: const {},
        catalogNames: {for (final e in catalog.values) e.id: e.name},
        catalog: catalog);

void main() {
  final catalog = {
    'press': def('press', 'Leg Press', 'Quadriceps', ['Glutes', 'Calves']),
    'thrust':
        def('thrust', 'Hip Thrust', 'Glutes', ['Hamstrings', 'Quadriceps']),
    'raise': def('raise', 'Lateral Raise', 'Shoulders', ['Traps']),
  };

  test('top set is the strongest lift, muscles are ranked and split', () {
    final workout = WorkoutLog(
        workoutName: 'Legs',
        timestamp: DateTime(2026, 11, 7, 9),
        durationSeconds: 3600,
        exercises: [
          lift('press', 'Quadriceps', 120, 10),
          lift('thrust', 'Glutes', 110, 10),
          lift('raise', 'Shoulders', 14, 15),
        ]);
    final data = result(workout, [workout], catalog);
    expect(data.topSet?.exerciseName, 'Leg Press');
    expect(data.topSet?.label, '120 kg × 10');
    expect(data.primaryMuscles, ['Glutes', 'Quadriceps', 'Shoulders']);
    expect(data.secondaryMuscles, ['Calves', 'Hamstrings', 'Traps'],
        reason: 'muscles already primary are left out');
  });

  test('a new record wins top set over a heavier lift', () {
    final before = WorkoutLog(
        workoutName: 'Before',
        timestamp: DateTime(2026, 11, 1, 9),
        durationSeconds: 1800,
        exercises: [
          lift('press', 'Quadriceps', 150, 10),
          lift('raise', 'Shoulders', 10, 15)
        ]);
    final workout = WorkoutLog(
        workoutName: 'Today',
        timestamp: DateTime(2026, 11, 7, 9),
        durationSeconds: 1800,
        exercises: [
          lift('press', 'Quadriceps', 120, 10),
          lift('raise', 'Shoulders', 16, 15)
        ]);
    final data = result(workout, [before, workout], catalog);
    expect(data.topSet?.exerciseName, 'Lateral Raise');
    expect(data.topSet?.isNewRecord, isTrue);
  });

  test('cardio-only workouts use the longest session as the top set', () {
    final workout = WorkoutLog(
        workoutName: 'Run',
        timestamp: DateTime(2026, 11, 7, 9),
        durationSeconds: 1800,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'run',
              exerciseName: 'Treadmill',
              exerciseType: 'cardio',
              sets: [
                WorkoutSet(
                    durationSeconds: 1500,
                    distance: 4,
                    distanceUnit: 'km',
                    isCompleted: true)
              ])
        ]);
    final data = result(workout, [workout], const {});
    expect(data.topSet?.exerciseName, 'Treadmill');
    expect(data.topSet?.label, '4 km · 25 min');
    expect(data.primaryMuscles, isEmpty);
  });

  test('streak on an older workout counts only up to that week', () {
    WorkoutLog at(DateTime day) => WorkoutLog(
        workoutName: 'W',
        timestamp: day,
        durationSeconds: 600,
        exercises: [lift('press', 'Quadriceps', 50, 5)]);
    final weeks = [
      for (var i = 0; i < 6; i++)
        at(DateTime(2026, 10, 1).add(Duration(days: 7 * i)))
    ];
    final early = WorkoutResultData.fromWorkout(
        workout: weeks[1],
        history: weeks,
        records: PRService.records(weeks),
        weightUnit: 'kg',
        distanceUnit: 'km',
        weeklyGoals: const {'default': 1});
    final late = WorkoutResultData.fromWorkout(
        workout: weeks[5],
        history: weeks,
        records: PRService.records(weeks),
        weightUnit: 'kg',
        distanceUnit: 'km',
        weeklyGoals: const {'default': 1});
    expect(early.streakWeeks, lessThan(late.streakWeeks));
  });

  test('every workout gets a top set, even without units or weights', () {
    WorkoutLog only(List<WorkoutExerciseLog> exercises) => WorkoutLog(
        workoutName: 'Old',
        timestamp: DateTime(2026, 2, 4, 8),
        durationSeconds: 600,
        exercises: exercises);
    WorkoutExerciseLog log(String id, List<WorkoutSet> sets,
            {String type = 'weightedStrength'}) =>
        WorkoutExerciseLog(
            exerciseId: 'id-$id',
            exerciseName: id,
            exerciseType: type,
            sets: sets);

    final noUnit = only([
      log('Back Squat', [WorkoutSet(weight: 60, reps: 10, isCompleted: true)]),
      log('Dumbbell Curl',
          [WorkoutSet(weight: 20, reps: 12, isCompleted: true)]),
    ]);
    final unitless = result(noUnit, [noUnit], catalog).topSet;
    expect(unitless?.exerciseName, 'Back Squat');
    expect(unitless?.label, '60 × 10');

    final bodyweight = only([
      log(
          'Push Ups',
          [
            WorkoutSet(reps: 15, isCompleted: true),
            WorkoutSet(reps: 22, isCompleted: true)
          ],
          type: 'bodyweight'),
    ]);
    expect(result(bodyweight, [bodyweight], catalog).topSet?.label, '22 reps');

    final hold = only([
      log('Plank Hold', [WorkoutSet(durationSeconds: 75, isCompleted: true)],
          type: 'timedHold'),
    ]);
    expect(result(hold, [hold], catalog).topSet?.label, '1m 15s');
  });
}
