import '../models/workout_model.dart';
import '../services/firebase_service.dart';

class SeedData {
  /// Generate and upload 3 test workouts to Firebase
  static Future<void> seedWorkouts(String userId, FirebaseService firebaseService) async {
    final workouts = [
      _createPushDayWorkout(),
      _createLegDayWorkout(),
      _createPullDayWorkout(),
    ];

    // Upload each workout to Firestore
    for (final workout in workouts) {
      await firebaseService.saveWorkout(userId, workout);
    }
  }

  /// Clear all test data workouts
  static Future<void> clearTestData(String userId, FirebaseService firebaseService) async {
    final allWorkouts = await firebaseService.getWorkouts(userId);
    final testWorkouts = allWorkouts.where((w) => w.isTestData).toList();

    for (final workout in testWorkouts) {
      await firebaseService.deleteWorkout(userId, workout.id);
    }
  }

  /// Push Day workout - 3 days ago
  static WorkoutLog _createPushDayWorkout() {
    final timestamp = DateTime.now().subtract(const Duration(days: 3));
    
    return WorkoutLog(
      id: timestamp.toIso8601String(),
      timestamp: timestamp,
      durationSeconds: 3600, // 1 hour
      isTestData: true,
      exercises: [
        // Bench Press - Progressive overload
        WorkoutExerciseLog(
          exerciseId: 'ex_bench_press',
          sets: [
            WorkoutSet(weight: 60, reps: 10, isCompleted: true),
            WorkoutSet(weight: 70, reps: 8, isCompleted: true),
            WorkoutSet(weight: 80, reps: 6, isCompleted: true),
            WorkoutSet(weight: 85, reps: 5, isCompleted: true),
          ],
        ),
        // Overhead Press
        WorkoutExerciseLog(
          exerciseId: 'ex_overhead_press',
          sets: [
            WorkoutSet(weight: 40, reps: 10, isCompleted: true),
            WorkoutSet(weight: 45, reps: 8, isCompleted: true),
            WorkoutSet(weight: 50, reps: 6, isCompleted: true),
          ],
        ),
        // Tricep Dip - Bodyweight
        WorkoutExerciseLog(
          exerciseId: 'ex_tricep_dip',
          sets: [
            WorkoutSet(weight: 0, reps: 12, isCompleted: true),
            WorkoutSet(weight: 0, reps: 10, isCompleted: true),
            WorkoutSet(weight: 0, reps: 8, isCompleted: true),
          ],
        ),
      ],
    );
  }

  /// Leg Day workout - 2 days ago
  static WorkoutLog _createLegDayWorkout() {
    final timestamp = DateTime.now().subtract(const Duration(days: 2));
    
    return WorkoutLog(
      id: timestamp.toIso8601String(),
      timestamp: timestamp,
      durationSeconds: 4200, // 70 minutes
      isTestData: true,
      exercises: [
        // Squat - Progressive overload
        WorkoutExerciseLog(
          exerciseId: 'ex_squat',
          sets: [
            WorkoutSet(weight: 100, reps: 10, isCompleted: true),
            WorkoutSet(weight: 120, reps: 8, isCompleted: true),
            WorkoutSet(weight: 140, reps: 6, isCompleted: true),
            WorkoutSet(weight: 140, reps: 5, isCompleted: true),
          ],
        ),
        // Hamstring Curl
        WorkoutExerciseLog(
          exerciseId: 'ex_hamstring_curl',
          sets: [
            WorkoutSet(weight: 50, reps: 12, isCompleted: true),
            WorkoutSet(weight: 60, reps: 10, isCompleted: true),
            WorkoutSet(weight: 60, reps: 8, isCompleted: true),
          ],
        ),
        // Calf Raise - Bodyweight
        WorkoutExerciseLog(
          exerciseId: 'ex_calf_raise',
          sets: [
            WorkoutSet(weight: 0, reps: 20, isCompleted: true),
            WorkoutSet(weight: 0, reps: 18, isCompleted: true),
            WorkoutSet(weight: 0, reps: 15, isCompleted: true),
          ],
        ),
      ],
    );
  }

  /// Pull Day workout - 1 day ago
  static WorkoutLog _createPullDayWorkout() {
    final timestamp = DateTime.now().subtract(const Duration(days: 1));
    
    return WorkoutLog(
      id: timestamp.toIso8601String(),
      timestamp: timestamp,
      durationSeconds: 3300, // 55 minutes
      isTestData: true,
      exercises: [
        // Deadlift - Progressive overload (potential PR)
        WorkoutExerciseLog(
          exerciseId: 'ex_deadlift',
          sets: [
            WorkoutSet(weight: 100, reps: 8, isCompleted: true),
            WorkoutSet(weight: 120, reps: 6, isCompleted: true),
            WorkoutSet(weight: 140, reps: 4, isCompleted: true),
            WorkoutSet(weight: 150, reps: 2, isCompleted: true), // PR weight
          ],
        ),
        // Pull-ups - Bodyweight
        WorkoutExerciseLog(
          exerciseId: 'ex_pull_ups',
          sets: [
            WorkoutSet(weight: 0, reps: 10, isCompleted: true),
            WorkoutSet(weight: 0, reps: 8, isCompleted: true),
            WorkoutSet(weight: 0, reps: 6, isCompleted: true),
          ],
        ),
        // Bicep Curl
        WorkoutExerciseLog(
          exerciseId: 'ex_bicep_curl',
          sets: [
            WorkoutSet(weight: 15, reps: 12, isCompleted: true),
            WorkoutSet(weight: 17, reps: 10, isCompleted: true),
            WorkoutSet(weight: 20, reps: 8, isCompleted: true),
          ],
        ),
      ],
    );
  }
}
