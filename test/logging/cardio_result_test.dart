import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/workout_result.dart';

WorkoutExerciseLog cardio(String id, String name, List<WorkoutSet> sets) =>
    WorkoutExerciseLog(
        exerciseId: id,
        exerciseName: name,
        exerciseType: 'cardio',
        muscleGroup: 'Cardio',
        sets: sets);

void main() {
  test('cardio shows its time, distance or reps', () {
    final log = WorkoutLog(
      workoutName: 'Cardio',
      timestamp: DateTime(2026, 11, 26),
      durationSeconds: 1800,
      exercises: [
        cardio('run', 'Treadmill Run', [
          WorkoutSet(durationSeconds: 1200, isCompleted: true),
        ]),
        cardio('bike', 'Bike', [
          WorkoutSet(distance: 5, distanceUnit: 'km', isCompleted: true),
        ]),
        cardio('jacks', 'Jumping Jacks', [
          WorkoutSet(reps: 50, isCompleted: true),
          WorkoutSet(reps: 40, isCompleted: true),
        ]),
      ],
    );
    final result = WorkoutResultData.fromWorkout(
        workout: log,
        history: [log],
        records: const [],
        weightUnit: 'kg',
        distanceUnit: 'km',
        weeklyGoals: const {});
    String label(String id) =>
        result.exercises.firstWhere((e) => e.exerciseId == id).resultLabel;
    expect(label('run'), '20 min');
    expect(label('bike'), '5 km');
    expect(label('jacks'), '90 reps');
    expect(result.exercises.firstWhere((e) => e.exerciseId == 'jacks').sets,
        2);
  });
}
