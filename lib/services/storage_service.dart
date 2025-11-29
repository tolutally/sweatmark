import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';

class StorageService {
  static const String _fileName = 'workout_logs.json';
  static const String _customExercisesFileName = 'custom_exercises.json';
  static const String _draftWorkoutFileName = 'draft_workout.json';

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  Future<String> _getCustomExercisesFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_customExercisesFileName';
  }

  Future<String> _getDraftWorkoutFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_draftWorkoutFileName';
  }

  Future<void> saveWorkout(WorkoutLog log) async {
    final List<WorkoutLog> logs = await getWorkouts();
    logs.add(log);
    
    final file = File(await _getFilePath());
    final jsonList = logs.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<List<WorkoutLog>> getWorkouts() async {
    try {
      final file = File(await _getFilePath());
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => WorkoutLog.fromJson(e)).toList();
    } catch (e) {
      print('Error reading workouts: $e');
      return [];
    }
  }

  Future<void> clearWorkouts() async {
    try {
      final file = File(await _getFilePath());
      if (await file.exists()) {
        await file.writeAsString(jsonEncode([]));
      }
    } catch (e) {
      print('Error clearing workouts: $e');
    }
  }

  // Custom Exercises
  Future<void> saveCustomExercise(Exercise exercise) async {
    final exercises = await getCustomExercises();
    exercises.add(exercise);
    
    final file = File(await _getCustomExercisesFilePath());
    final jsonList = exercises.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<List<Exercise>> getCustomExercises() async {
    try {
      final file = File(await _getCustomExercisesFilePath());
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Exercise.fromJson(e)).toList();
    } catch (e) {
      print('Error reading custom exercises: $e');
      return [];
    }
  }

  Future<void> deleteCustomExercise(String exerciseId) async {
    final exercises = await getCustomExercises();
    exercises.removeWhere((e) => e.id == exerciseId);
    
    final file = File(await _getCustomExercisesFilePath());
    final jsonList = exercises.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  // Draft Workout (Save for Later)
  Future<void> saveDraftWorkout(Map<String, dynamic> draftData) async {
    final file = File(await _getDraftWorkoutFilePath());
    await file.writeAsString(jsonEncode(draftData));
  }

  Future<Map<String, dynamic>?> getDraftWorkout() async {
    try {
      final file = File(await _getDraftWorkoutFilePath());
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading draft workout: $e');
      return null;
    }
  }

  Future<void> deleteDraftWorkout() async {
    try {
      final file = File(await _getDraftWorkoutFilePath());
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting draft workout: $e');
    }
  }

  Future<bool> hasDraftWorkout() async {
    try {
      final file = File(await _getDraftWorkoutFilePath());
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
