import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../services/storage_service.dart';

class WorkoutNotifier extends ChangeNotifier {
  bool _isWorkoutActive = false;
  bool get isWorkoutActive => _isWorkoutActive;

  WorkoutLog? _currentWorkout;
  WorkoutLog? get currentWorkout => _currentWorkout;

  DateTime? _startTime;
  Timer? _timer;
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  final StorageService _storageService = StorageService();

  void startWorkout() {
    _isWorkoutActive = true;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _currentWorkout = WorkoutLog(
      id: DateTime.now().toIso8601String(),
      timestamp: DateTime.now(),
      durationSeconds: 0,
      exercises: [],
    );
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
    });
    
    notifyListeners();
  }

  void addExercise(Exercise exercise) {
    if (_currentWorkout == null) return;
    _currentWorkout!.exercises.add(WorkoutExerciseLog(
      exerciseId: exercise.id,
      sets: [WorkoutSet(weight: null, reps: null)], 
    ));
    notifyListeners();
  }

  void addSet(String exerciseId) {
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    exerciseLog.sets.add(WorkoutSet(weight: null, reps: null));
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> finishWorkout() async {
    if (_currentWorkout == null) return;
    
    _timer?.cancel();
    _timer = null;
    
    // Update duration
    final finishedWorkout = WorkoutLog(
      id: _currentWorkout!.id,
      timestamp: _currentWorkout!.timestamp,
      durationSeconds: _elapsedSeconds,
      exercises: _currentWorkout!.exercises,
    );

    await _storageService.saveWorkout(finishedWorkout);

    _isWorkoutActive = false;
    _currentWorkout = null;
    _startTime = null;
    _elapsedSeconds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
