import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import 'firebase_service.dart';

class StorageService {
  static const String _fileName = 'workout_logs.json';
  static const String _customExercisesFileName = 'custom_exercises.json';
  static const String _draftWorkoutFileName = 'draft_workout.json';

  final FirebaseService _firebaseService = FirebaseService();

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
    print('💾 Saving custom exercise: ${exercise.name} (ID: ${exercise.id})');

    // Save locally
    final exercises = await getCustomExercises();

    // Check for duplicates by ID
    final existingIndex = exercises.indexWhere((e) => e.id == exercise.id);
    if (existingIndex >= 0) {
      print('⚠️ Exercise with ID ${exercise.id} already exists, updating...');
      exercises[existingIndex] = exercise;
    } else {
      exercises.add(exercise);
    }

    final filePath = await _getCustomExercisesFilePath();
    final file = File(filePath);
    final jsonList = exercises.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
    print(
        '✅ Custom exercise saved locally to: $filePath (Total: ${exercises.length})');

    // Also sync to Firebase if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firebaseService.saveCustomExercise(user.uid, exercise.toJson());
        print('✅ Custom exercise synced to Firebase: ${exercise.name}');
      } catch (e) {
        print('⚠️ Failed to sync custom exercise to Firebase: $e');
        // Don't throw - local save succeeded
      }
    } else {
      print('ℹ️ User not logged in, skipping Firebase sync');
    }
  }

  Future<List<Exercise>> getCustomExercises() async {
    try {
      final filePath = await _getCustomExercisesFilePath();
      final file = File(filePath);
      if (!await file.exists()) {
        print('ℹ️ No local custom exercises file exists yet');
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final exercises = jsonList.map((e) => Exercise.fromJson(e)).toList();
      print(
          '📖 Loaded ${exercises.length} custom exercises from local storage');
      return exercises;
    } catch (e) {
      print('❌ Error reading custom exercises: $e');
      return [];
    }
  }

  /// Get custom exercises merged from local and Firebase
  Future<List<Exercise>> getCustomExercisesMerged() async {
    print('🔄 Getting merged custom exercises...');
    final localExercises = await getCustomExercises();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print(
          'ℹ️ User not logged in, returning ${localExercises.length} local exercises only');
      return localExercises;
    }

    try {
      print('☁️ Fetching custom exercises from Firebase for user: ${user.uid}');
      final firebaseExercises =
          await _firebaseService.getCustomExercises(user.uid);
      print('☁️ Retrieved ${firebaseExercises.length} exercises from Firebase');

      // Merge: use a map to avoid duplicates by ID
      final Map<String, Exercise> exerciseMap = {};

      // Add local exercises first
      for (final ex in localExercises) {
        exerciseMap[ex.id] = ex;
      }

      // Add/override with Firebase exercises
      for (final exMap in firebaseExercises) {
        final ex = Exercise.fromJson(exMap);
        exerciseMap[ex.id] = ex;
      }

      print('✅ Merged total: ${exerciseMap.length} custom exercises');
      return exerciseMap.values.toList();
    } catch (e) {
      print('⚠️ Error fetching Firebase exercises, using local only: $e');
      return localExercises;
    }
  }

  /// Sync local custom exercises to Firebase (call on login)
  Future<void> syncCustomExercisesToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final localExercises = await getCustomExercises();
      if (localExercises.isNotEmpty) {
        final jsonList = localExercises.map((e) => e.toJson()).toList();
        await _firebaseService.batchUploadCustomExercises(user.uid, jsonList);
        print('✅ Synced ${localExercises.length} local exercises to Firebase');
      }
    } catch (e) {
      print('⚠️ Error syncing exercises to Firebase: $e');
    }
  }

  Future<void> deleteCustomExercise(String exerciseId) async {
    // Delete locally
    final exercises = await getCustomExercises();
    exercises.removeWhere((e) => e.id == exerciseId);

    final file = File(await _getCustomExercisesFilePath());
    final jsonList = exercises.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));

    // Also delete from Firebase if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firebaseService.deleteCustomExercise(user.uid, exerciseId);
        print('✅ Custom exercise deleted from Firebase: $exerciseId');
      } catch (e) {
        print('⚠️ Failed to delete custom exercise from Firebase: $e');
      }
    }
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
