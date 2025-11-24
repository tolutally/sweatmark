import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
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
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  final StorageService _storageService = StorageService();
  final SyncService _syncService;
  final PRService _prService = PRService();
  
  List<WorkoutLog> _workoutHistory = [];
  List<WorkoutLog> get workoutHistory => _workoutHistory;

  // Callback for PR notification
  Function(List<String>)? onPersonalRecords;

  WorkoutNotifier(this._syncService) {
    _loadWorkoutHistory();
  }

  Future<void> _loadWorkoutHistory() async {
    _workoutHistory = await _storageService.getWorkouts();
    notifyListeners();
  }

  void startWorkout() {
    _isWorkoutActive = true;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
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

  void updateWorkoutName(String name) {
    _workoutName = name;
    notifyListeners();
  }

  void updateWorkoutNotes(String notes) {
    _workoutNotes = notes;
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

  Future<void> finishWorkout(String? userId) async {
    if (_currentWorkout == null) return;
    
    _timer?.cancel();
    _timer = null;
    
    // Update duration
    final finishedWorkout = WorkoutLog(
      id: _currentWorkout!.id,
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

    _isWorkoutActive = false;
    _currentWorkout = null;
    _startTime = null;
    _elapsedSeconds = 0;
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
    notifyListeners();
  }

  /// Refresh workout history from cloud
  Future<void> refreshWorkoutHistory(String? userId) async {
    _workoutHistory = await _syncService.getWorkouts(userId);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
