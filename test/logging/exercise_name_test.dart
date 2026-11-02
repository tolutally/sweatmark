import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/workout_result.dart';

void main() {
  test('saved names win, then catalog, then readable free IDs', () {
    expect(
        exerciseDisplayName('free_Upright_Barbell_Row', saved: 'Upright Row'),
        'Upright Row');
    expect(
        exerciseDisplayName('ex_bench_press',
            catalog: {'ex_bench_press': 'Bench Press'}),
        'Bench Press');
    expect(
        exerciseDisplayName('free_Upright_Barbell_Row'), 'Upright Barbell Row');
    expect(exerciseDisplayName('free_Dips_-_Triceps_Version'),
        'Dips - Triceps Version');
    // A name that is just the ID is not a name.
    expect(
        exerciseDisplayName('free_Leg_Extensions',
            saved: 'free_Leg_Extensions'),
        'Leg Extensions');
    expect(exerciseDisplayName('custom_1712345678'), 'Saved exercise');
    expect(
        exerciseDisplayName('exercisedb_0042', saved: '  '), 'Saved exercise');
  });

  test('older logs without names never expose IDs in results', () {
    final workout = WorkoutLog(
      workoutName: 'Legs',
      timestamp: DateTime(2026, 2, 4),
      durationSeconds: 1800,
      exercises: [
        WorkoutExerciseLog(exerciseId: 'free_Standing_Calf_Raises', sets: [
          WorkoutSet(weight: 110, weightUnit: 'lb', reps: 12, isCompleted: true)
        ]),
      ],
    );
    final result = WorkoutResultData.fromWorkout(
        workout: workout,
        history: [workout],
        records: const [],
        weightUnit: 'lb',
        distanceUnit: 'km',
        weeklyGoals: const {});
    expect(result.exercises.single.name, 'Standing Calf Raises');
    expect(workout.exercises.single.displayName, 'Standing Calf Raises');
  });
}
