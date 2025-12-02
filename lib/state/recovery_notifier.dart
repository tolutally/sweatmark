import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../data/muscle_assets.dart';
import '../services/storage_service.dart';
import '../data/exercise_data.dart';

class RecoveryNotifier extends ChangeNotifier {
  // Store the last time a muscle was worked
  final Map<String, DateTime> _lastWorked = {};
  final StorageService _storageService = StorageService();

  /// Expose last worked timestamps per muscle group
  Map<String, DateTime> get lastWorkedMap => Map.unmodifiable(_lastWorked);

  /// Check if any workout history exists
  bool get hasWorkoutHistory => _lastWorked.isNotEmpty;

  RecoveryNotifier() {
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await _storageService.getWorkouts();
    for (final log in logs) {
      for (final exerciseLog in log.exercises) {
        // Find muscle group for this exercise
        final exerciseData = EXERCISE_LIBRARY.firstWhere(
          (e) => e['id'] == exerciseLog.exerciseId,
          orElse: () => {},
        );
        
        if (exerciseData.isNotEmpty) {
          final String muscle = exerciseData['muscleGroup'];
          // Update if this log is newer than what we have
          if (!_lastWorked.containsKey(muscle) || log.timestamp.isAfter(_lastWorked[muscle]!)) {
            _lastWorked[muscle] = log.timestamp;
          }
        }
      }
    }
    notifyListeners();
  }

  Map<String, MuscleStatus> get muscleStatus {
    final Map<String, MuscleStatus> statusMap = {};
    final now = DateTime.now();

    // Initialize all known muscles to recovered first
    MUSCLE_MAP.forEach((key, value) {
      statusMap[key] = MuscleStatus.recovered;
    });

    // Update based on timestamps
    _lastWorked.forEach((muscle, timestamp) {
      final difference = now.difference(timestamp);
      if (difference.inHours < 24) {
        statusMap[muscle] = MuscleStatus.fatigued;
      } else if (difference.inHours < 48) {
        statusMap[muscle] = MuscleStatus.recovering;
      } else {
        statusMap[muscle] = MuscleStatus.recovered;
      }
    });

    return statusMap;
  }

  void updateRecovery(List<String> muscleGroups) {
    final now = DateTime.now();
    for (final muscle in muscleGroups) {
      if (MUSCLE_MAP.containsKey(muscle)) {
        _lastWorked[muscle] = now;
      }
    }
    notifyListeners();
  }
}
