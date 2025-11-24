import '../models/workout_model.dart';
import '../data/exercise_data.dart';

class PRService {
  /// Detect personal records by comparing current workout against history
  /// Returns list of exercise names that achieved new PRs
  List<String> detectPersonalRecords(WorkoutLog currentWorkout, List<WorkoutLog> history) {
    final List<String> newPRs = [];
    
    // Track best 1RM per exercise from history
    final Map<String, double> historicalBest = {};
    
    // Calculate historical bests (excluding current workout and test data)
    for (final workout in history) {
      if (workout.id == currentWorkout.id || workout.isTestData) continue;
      
      for (final exerciseLog in workout.exercises) {
        final best1RM = _calculateBest1RM(exerciseLog.sets);
        
        if (best1RM > 0) {
          if (!historicalBest.containsKey(exerciseLog.exerciseId) || 
              best1RM > historicalBest[exerciseLog.exerciseId]!) {
            historicalBest[exerciseLog.exerciseId] = best1RM;
          }
        }
      }
    }
    
    // Check current workout for new PRs
    for (final exerciseLog in currentWorkout.exercises) {
      final current1RM = _calculateBest1RM(exerciseLog.sets);
      
      if (current1RM > 0) {
        // If no history exists, it's a PR
        if (!historicalBest.containsKey(exerciseLog.exerciseId)) {
          final exerciseName = _getExerciseName(exerciseLog.exerciseId);
          if (exerciseName != null) {
            newPRs.add(exerciseName);
          }
        } 
        // If current exceeds historical best, it's a PR
        else if (current1RM > historicalBest[exerciseLog.exerciseId]!) {
          final exerciseName = _getExerciseName(exerciseLog.exerciseId);
          if (exerciseName != null) {
            newPRs.add(exerciseName);
          }
        }
      }
    }
    
    return newPRs;
  }
  
  /// Calculate best estimated 1RM from a list of sets using Epley formula
  /// Formula: weight × (1 + reps/30)
  double _calculateBest1RM(List<WorkoutSet> sets) {
    double best1RM = 0;
    
    for (final set in sets) {
      if (set.weight != null && set.reps != null && set.weight! > 0 && set.reps! > 0) {
        // Epley formula for 1RM estimation
        final estimated1RM = set.weight! * (1 + set.reps! / 30.0);
        
        if (estimated1RM > best1RM) {
          best1RM = estimated1RM;
        }
      }
    }
    
    return best1RM;
  }
  
  /// Get exercise name from exercise ID
  String? _getExerciseName(String exerciseId) {
    try {
      final exercise = EXERCISE_LIBRARY.firstWhere(
        (e) => e['id'] == exerciseId,
      );
      return exercise['name'] as String?;
    } catch (e) {
      return null;
    }
  }
}
