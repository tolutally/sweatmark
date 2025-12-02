import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../data/exercise_data.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/pr_service.dart';

class WorkoutNotifier extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool get isWorkoutActive => _isWorkoutActive;

  WorkoutLog? _currentWorkout;
  WorkoutLog? get currentWorkout => _currentWorkout;

  String _workoutName = 'My Workout 1';
  String get workoutName => _workoutName;

  String _workoutNotes = '';
  String get workoutNotes => _workoutNotes;

  DateTime? _startTime;
  Timer? _timer;
  Timer? _autoSaveTimer;
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;
  bool _timerStarted = false;

  final StorageService _storageService = StorageService();
  final SyncService _syncService;
  final PRService _prService = PRService();
  
  List<WorkoutLog> _workoutHistory = [];
  List<WorkoutLog> get workoutHistory => _workoutHistory;

  // Callback for PR notification
  Function(List<String>)? onPersonalRecords;

  WorkoutNotifier(this._syncService) {
    _loadWorkoutHistory();
    _autoRestoreDraftWorkout();
  }

  Future<void> _loadWorkoutHistory() async {
    _workoutHistory = await _storageService.getWorkouts();
    notifyListeners();
  }

  Future<bool> hasDraftWorkout() async {
    return await _storageService.hasDraftWorkout();
  }

  Future<void> saveDraftWorkout() async {
    if (_currentWorkout == null) return;

    final draftData = {
      'workoutName': _workoutName,
      'workoutNotes': _workoutNotes,
      'startTime': _startTime?.toIso8601String(),
      'elapsedSeconds': _elapsedSeconds,
      'exercises': _currentWorkout!.exercises.map((e) => {
        'exerciseId': e.exerciseId,
        'sets': e.sets.map((s) => {
          'weight': s.weight,
          'reps': s.reps,
          'isCompleted': s.isCompleted,
        }).toList(),
      }).toList(),
    };

    await _storageService.saveDraftWorkout(draftData);
  }

  Future<void> loadDraftWorkout() async {
    if (_isWorkoutActive) return;
    final draftData = await _storageService.getDraftWorkout();
    if (draftData == null) return;

    _workoutName = draftData['workoutName'] as String? ?? 'My Workout 1';
    _workoutNotes = draftData['workoutNotes'] as String? ?? '';
    _elapsedSeconds = draftData['elapsedSeconds'] as int? ?? 0;
    
    if (draftData['startTime'] != null) {
      try {
        _startTime = DateTime.parse(draftData['startTime'] as String);
      } catch (_) {
        _startTime = null;
      }
    }

    final exercises = (draftData['exercises'] as List?)?.map((e) {
      final sets = (e['sets'] as List?)?.map((s) {
        return WorkoutSet(
          weight: s['weight'] as int?,
          reps: s['reps'] as int?,
          isCompleted: s['isCompleted'] as bool? ?? false,
        );
      }).toList() ?? [];

      return WorkoutExerciseLog(
        exerciseId: e['exerciseId'] as String,
        sets: sets,
      );
    }).toList() ?? [];

    _currentWorkout = WorkoutLog(
      workoutName: _workoutName,
      timestamp: _startTime ?? DateTime.now(),
      durationSeconds: 0,
      exercises: exercises,
    );

    _isWorkoutActive = true;
    _timerStarted = false;

    if (_startTime != null) {
      _elapsedSeconds = _calculateElapsedSeconds();
      _startTimer(restart: true);
    }

    _startAutoSave();
    notifyListeners();
  }

  Future<void> deleteDraftWorkout() async {
    await _storageService.deleteDraftWorkout();
  }

  void resetWorkout() {
    _stopAutoSave();
    _isWorkoutActive = false;
    _currentWorkout = null;
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void startWorkout({String? workoutName}) {
    _stopAutoSave();
    _isWorkoutActive = true;
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _workoutName = workoutName ?? 'My Workout 1';
    _workoutNotes = '';
    _currentWorkout = WorkoutLog(
      workoutName: _workoutName,
      timestamp: DateTime.now(),
      durationSeconds: 0,
      exercises: [],
    );

    _startAutoSave();
    // Timer will be started when first set is marked complete
    notifyListeners();
  }

  void updateWorkoutName(String name) {
    _workoutName = name;
    notifyListeners();
  }

  void updateWorkoutNotes(String notes) {
    _workoutNotes = notes;
    notifyListeners();
  }

  void _startTimer({bool restart = false}) {
    if (_timerStarted && !restart) return;
    _timer?.cancel();
    _timerStarted = true;
    _startTime ??= DateTime.now();
    _elapsedSeconds = _calculateElapsedSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds = _calculateElapsedSeconds();
      notifyListeners();
    });
    notifyListeners();
  }

  void addExercise(Exercise exercise) {
    if (_currentWorkout == null) return;
    _currentWorkout!.exercises.add(WorkoutExerciseLog(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
      sets: [
        WorkoutSet(weight: null, reps: null),
        WorkoutSet(weight: null, reps: null),
        WorkoutSet(weight: null, reps: null),
      ], 
    ));
    notifyListeners();
  }

  /// Add exercise from a template with pre-configured sets
  void addExerciseFromTemplate({
    required String name,
    int targetSets = 3,
    int? targetReps,
    double? targetWeight,
  }) {
    if (_currentWorkout == null) return;
    
    // Try to find the exercise in the database, or create a custom one
    final exerciseData = EXERCISE_LIBRARY.firstWhere(
      (e) => (e['name'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => {
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'muscleGroup': 'Full Body',
        'equipment': 'None',
      },
    );

    // Create sets with template values
    final sets = List.generate(
      targetSets,
      (_) => WorkoutSet(
        weight: targetWeight?.toInt(),
        reps: targetReps,
      ),
    );

    _currentWorkout!.exercises.add(WorkoutExerciseLog(
      exerciseId: exerciseData['id'] as String,
      exerciseName: exerciseData['name'] as String?,
      muscleGroup: exerciseData['muscleGroup'] as String?,
      equipment: exerciseData['equipment'] as String?,
      sets: sets,
    ));
    notifyListeners();
  }

  void addSet(String exerciseId) {
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    exerciseLog.sets.add(WorkoutSet(weight: null, reps: null));
    notifyListeners();
  }

  void removeSet(String exerciseId, int setIndex) {
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length && exerciseLog.sets.length > 1) {
      exerciseLog.sets.removeAt(setIndex);
      notifyListeners();
    }
  }

  void updateSet(String exerciseId, int setIndex, int? weight, int? reps) {
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length) {
      exerciseLog.sets[setIndex].weight = weight;
      exerciseLog.sets[setIndex].reps = reps;
      notifyListeners();
    }
  }

  void toggleSetCompletion(String exerciseId, int setIndex) {
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length) {
      exerciseLog.sets[setIndex].isCompleted = !exerciseLog.sets[setIndex].isCompleted;
      
      // Start timer on first set completion
      if (exerciseLog.sets[setIndex].isCompleted && !_timerStarted) {
        _startTimer();
      }
      
      notifyListeners();
    }
  }

  Future<void> finishWorkout(String? userId) async {
    if (_currentWorkout == null) return;
    
    _elapsedSeconds = _calculateElapsedSeconds();
    _timer?.cancel();
    _timer = null;
    _stopAutoSave();
    
    // Update duration
    final finishedWorkout = WorkoutLog(
      workoutName: _currentWorkout!.workoutName,
      timestamp: _currentWorkout!.timestamp,
      durationSeconds: _elapsedSeconds,
      exercises: _currentWorkout!.exercises,
      isTestData: false,
    );

    // Detect personal records BEFORE syncing
    final newPRs = _prService.detectPersonalRecords(finishedWorkout, _workoutHistory);
    
    // Sync to cloud (with local fallback)
    await _syncService.syncWorkout(userId, finishedWorkout);
    
    // Reload history
    await _loadWorkoutHistory();

    // Trigger PR notification callback immediately
    if (newPRs.isNotEmpty && onPersonalRecords != null) {
      onPersonalRecords!(newPRs);
    }

    // Delete draft workout if it exists
    await deleteDraftWorkout();

    _isWorkoutActive = false;
    _currentWorkout = null;
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
    notifyListeners();
  }

  /// Refresh workout history from cloud
  Future<void> refreshWorkoutHistory(String? userId) async {
    _workoutHistory = await _syncService.getWorkouts(userId);
    notifyListeners();
  }

  void removeExercise(int exerciseIndex) {
    if (_currentWorkout == null) return;
    _currentWorkout!.exercises.removeAt(exerciseIndex);
    notifyListeners();
  }

  /// Create a super set from selected exercises
  void createSuperSet(List<String> exerciseIds) {
    if (_currentWorkout == null || exerciseIds.length < 2) return;
    
    final superSetId = 'superset_${DateTime.now().millisecondsSinceEpoch}';
    final superSet = SuperSet(
      id: superSetId,
      exerciseIds: exerciseIds,
    );
    
    _currentWorkout!.superSets.add(superSet);
    
    // Update exercise logs with super set info
    for (int i = 0; i < exerciseIds.length; i++) {
      final exerciseIndex = _currentWorkout!.exercises.indexWhere(
        (e) => e.exerciseId == exerciseIds[i]
      );
      if (exerciseIndex != -1) {
        final exercise = _currentWorkout!.exercises[exerciseIndex];
        _currentWorkout!.exercises[exerciseIndex] = WorkoutExerciseLog(
          exerciseId: exercise.exerciseId,
          sets: exercise.sets,
          superSetId: superSetId,
          orderInSuperSet: i,
        );
      }
    }
    
    notifyListeners();
  }

  /// Remove exercise from super set
  void removeFromSuperSet(String exerciseId) {
    if (_currentWorkout == null) return;
    
    final exerciseIndex = _currentWorkout!.exercises.indexWhere(
      (e) => e.exerciseId == exerciseId
    );
    
    if (exerciseIndex != -1) {
      final exercise = _currentWorkout!.exercises[exerciseIndex];
      if (exercise.superSetId != null) {
        // Find the super set and remove exercise
        final superSetIndex = _currentWorkout!.superSets.indexWhere(
          (s) => s.id == exercise.superSetId
        );
        
        if (superSetIndex != -1) {
          final superSet = _currentWorkout!.superSets[superSetIndex];
          final updatedExerciseIds = superSet.exerciseIds.where(
            (id) => id != exerciseId
          ).toList();
          
          if (updatedExerciseIds.length < 2) {
            // Remove entire super set if less than 2 exercises
            _currentWorkout!.superSets.removeAt(superSetIndex);
            // Clear super set info from remaining exercises
            for (final remainingId in updatedExerciseIds) {
              final remainingIndex = _currentWorkout!.exercises.indexWhere(
                (e) => e.exerciseId == remainingId
              );
              if (remainingIndex != -1) {
                final remainingExercise = _currentWorkout!.exercises[remainingIndex];
                _currentWorkout!.exercises[remainingIndex] = WorkoutExerciseLog(
                  exerciseId: remainingExercise.exerciseId,
                  sets: remainingExercise.sets,
                );
              }
            }
          } else {
            // Update super set with remaining exercises
            _currentWorkout!.superSets[superSetIndex] = superSet.copyWith(
              exerciseIds: updatedExerciseIds
            );
            // Update order for remaining exercises
            for (int i = 0; i < updatedExerciseIds.length; i++) {
              final remainingIndex = _currentWorkout!.exercises.indexWhere(
                (e) => e.exerciseId == updatedExerciseIds[i]
              );
              if (remainingIndex != -1) {
                final remainingExercise = _currentWorkout!.exercises[remainingIndex];
                _currentWorkout!.exercises[remainingIndex] = WorkoutExerciseLog(
                  exerciseId: remainingExercise.exerciseId,
                  sets: remainingExercise.sets,
                  superSetId: exercise.superSetId,
                  orderInSuperSet: i,
                );
              }
            }
          }
        }
        
        // Clear super set info from removed exercise
        _currentWorkout!.exercises[exerciseIndex] = WorkoutExerciseLog(
          exerciseId: exercise.exerciseId,
          sets: exercise.sets,
        );
      }
    }
    
    notifyListeners();
  }

  /// Reorder exercises within a super set
  void reorderSuperSetExercises(String superSetId, List<String> newOrder) {
    if (_currentWorkout == null) return;
    
    final superSetIndex = _currentWorkout!.superSets.indexWhere(
      (s) => s.id == superSetId
    );
    
    if (superSetIndex != -1) {
      _currentWorkout!.superSets[superSetIndex] = 
          _currentWorkout!.superSets[superSetIndex].copyWith(
        exerciseIds: newOrder
      );
      
      // Update order in exercise logs
      for (int i = 0; i < newOrder.length; i++) {
        final exerciseIndex = _currentWorkout!.exercises.indexWhere(
          (e) => e.exerciseId == newOrder[i]
        );
        if (exerciseIndex != -1) {
          final exercise = _currentWorkout!.exercises[exerciseIndex];
          _currentWorkout!.exercises[exerciseIndex] = WorkoutExerciseLog(
            exerciseId: exercise.exerciseId,
            sets: exercise.sets,
            superSetId: superSetId,
            orderInSuperSet: i,
          );
        }
      }
      
      notifyListeners();
    }
  }

  /// Get exercises that are not in any super set
  List<WorkoutExerciseLog> getAvailableExercisesForSuperSet() {
    if (_currentWorkout == null) return [];
    return _currentWorkout!.exercises.where((e) => e.superSetId == null).toList();
  }

  /// Get super set by ID
  SuperSet? getSuperSet(String superSetId) {
    if (_currentWorkout == null) return null;
    try {
      return _currentWorkout!.superSets.firstWhere((s) => s.id == superSetId);
    } catch (e) {
      return null;
    }
  }

  /// Delete a workout from history
  Future<void> deleteWorkout(WorkoutLog workout) async {
    _workoutHistory.removeWhere((w) => w.timestamp == workout.timestamp);
    
    // Update local storage
    await _storageService.clearWorkouts();
    for (var w in _workoutHistory) {
      await _storageService.saveWorkout(w);
    }
    
    // Sync to cloud if user is authenticated
    await _syncService.deleteWorkout(workout);
    
    notifyListeners();
  }

  /// Update workout notes for an existing workout
  Future<void> updateWorkoutHistoryNotes(WorkoutLog workout, String notes) async {
    // Find the workout in history and update it
    final index = _workoutHistory.indexWhere((w) => w.timestamp == workout.timestamp);
    if (index != -1) {
      _workoutHistory[index] = WorkoutLog(
        workoutName: workout.workoutName,
        exercises: workout.exercises,
        timestamp: workout.timestamp,
        durationSeconds: workout.durationSeconds,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );
      
      // Update local storage
      await _storageService.clearWorkouts();
      for (var w in _workoutHistory) {
        await _storageService.saveWorkout(w);
      }
      
      // Sync to cloud
      await _syncService.syncWorkout(null, _workoutHistory[index]);
      
      notifyListeners();
    }
  }

  /// Repeat a workout - start a new workout with the same exercises
  Future<void> repeatWorkout(WorkoutLog workout) async {
    // Reset current workout state
    resetWorkout();
    
    // Start new workout with same name and exercises
    startWorkout(workoutName: '${workout.workoutName} (Copy)');
    
    // Add all exercises from the previous workout
    for (var exerciseLog in workout.exercises) {
      // Find the exercise data
      final exerciseData = await _getExerciseById(exerciseLog.exerciseId);
      if (exerciseData != null) {
        addExercise(exerciseData);
        
        // Add the same number of sets (but not completed)
        for (int i = 1; i < exerciseLog.sets.length; i++) {
          addSet(exerciseLog.exerciseId);
        }
      }
    }
  }

  /// Helper method to get exercise by ID
  Future<Exercise?> _getExerciseById(String exerciseId) async {
    try {
      // Check custom exercises first
      final customExercises = await _storageService.getCustomExercises();
      for (var exercise in customExercises) {
        if (exercise.id == exerciseId) {
          return exercise;
        }
      }
      
      // Check built-in exercises  
      final exerciseData = EXERCISE_LIBRARY
          .firstWhere((e) => e['id'] == exerciseId, orElse: () => <String, dynamic>{});
      
      if (exerciseData.isNotEmpty) {
        return Exercise.fromJson(exerciseData);
      }
    } catch (e) {
      print('Error getting exercise by ID: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAutoSave();
    super.dispose();
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    if (!_isWorkoutActive || _currentWorkout == null) return;

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      saveDraftWorkout();
    });
  }

  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<void> _autoRestoreDraftWorkout() async {
    if (_isWorkoutActive) return;
    final hasDraft = await _storageService.hasDraftWorkout();
    if (!hasDraft || _isWorkoutActive) return;
    await loadDraftWorkout();
  }

  Future<void> onAppPaused() async {
    if (_isWorkoutActive) {
      await saveDraftWorkout();
    }
  }

  void onAppResumed() {
    if (!_isWorkoutActive) return;
    if (_startTime != null) {
      _elapsedSeconds = _calculateElapsedSeconds();
      _startTimer(restart: true);
    }
    _startAutoSave();
    notifyListeners();
  }

  int _calculateElapsedSeconds() {
    if (_startTime == null) return _elapsedSeconds;
    final seconds = DateTime.now().difference(_startTime!).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}
