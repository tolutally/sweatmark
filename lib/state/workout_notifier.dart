import 'session_notifier.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../data/exercise_data.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../data/exercise_catalog.dart';
import '../services/apple_health_service.dart';
import '../services/pr_service.dart';
import '../services/recovery_service.dart';
import '../services/notification_service.dart';

class WorkoutNotifier extends SessionNotifier {
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

  /// How long a workout can go without any logging before the clock stops.
  static const idleLimit = Duration(minutes: 30);

  /// How long without logging before the phone reminds the person.
  static const reminderAfter = Duration(minutes: 15);

  /// Schedules the logging reminder for a time, or cancels it with null;
  /// replaceable in tests.
  @visibleForTesting
  Future<void> Function(DateTime? at) remind = _notify;

  static Future<void> _notify(DateTime? at) async {
    try {
      final notifications = NotificationService();
      if (at == null) {
        await notifications.cancelLoggingReminder();
      } else {
        await notifications.scheduleLoggingReminder(at);
      }
    } catch (error) {
      debugPrint('Logging reminder unavailable: $error');
    }
  }

  DateTime? _reminderAt;

  /// Moves the reminder to [reminderAfter] past [activity], or cancels it.
  /// Small moves are skipped so typing doesn't reschedule on every key.
  void _planReminder(DateTime? activity) {
    final at = activity?.add(reminderAfter);
    final current = _reminderAt;
    if (at == null && current == null) return;
    if (at != null &&
        current != null &&
        at.difference(current).abs() < const Duration(seconds: 30)) {
      return;
    }
    _reminderAt = at;
    unawaited(remind(at));
  }

  /// Clock used for the workout timer; replaceable in tests.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  // Last time the person changed anything in the workout.
  DateTime? _lastActivity;
  // When the clock stopped for inactivity: the last activity, so idle time
  // is never counted.
  DateTime? _pausedAt;
  // Time spent paused that was later resumed.
  int _pausedSeconds = 0;

  /// Whether the clock stopped after [idleLimit] without activity.
  bool get isTimerPaused => _pausedAt != null;

  void _clearPause() {
    _lastActivity = null;
    _pausedAt = null;
    _pausedSeconds = 0;
    _cardioRunning.clear();
    _planReminder(null);
  }

  /// Records activity and restarts the clock if it had stopped.
  void _touch() {
    if (!_isWorkoutActive) return;
    if (_pausedAt != null) {
      _resume();
    } else {
      _lastActivity = clock();
    }
    // A running cardio stopwatch is activity; no reminder while it runs.
    _planReminder(_cardioRunning.isEmpty ? clock() : null);
  }

  void _resume() {
    final now = clock();
    final paused = now.difference(_pausedAt!).inSeconds;
    if (paused > 0) _pausedSeconds += paused;
    _pausedAt = null;
    _lastActivity = now;
    _elapsedSeconds = _calculateElapsedSeconds();
  }

  /// Restarts the clock after it stopped for inactivity.
  void resumeTimer() {
    if (_pausedAt == null) return;
    _resume();
    notifyListeners();
    _persistPresentation();
  }

  /// Stops the clock at the last activity once [idleLimit] has passed.
  /// Returns whether it just stopped.
  bool _checkIdle() {
    if (_cardioRunning.isNotEmpty) {
      _lastActivity = clock();
      return false;
    }
    final last = _lastActivity;
    if (!_timerStarted || _pausedAt != null || last == null) return false;
    if (clock().difference(last) < idleLimit) return false;
    _pausedAt = last;
    _elapsedSeconds = _calculateElapsedSeconds();
    _persistPresentation();
    return true;
  }

  // Track collapsed exercise cards (by exerciseId)
  final Set<String> _collapsedExercises = {};
  Set<String> get collapsedExercises => _collapsedExercises;

  bool isExerciseCollapsed(String exerciseId) =>
      _collapsedExercises.contains(exerciseId);

  void toggleExerciseCollapsed(String exerciseId) {
    if (_collapsedExercises.contains(exerciseId)) {
      _collapsedExercises.remove(exerciseId);
    } else {
      _collapsedExercises.add(exerciseId);
    }
    notifyListeners();
    _persistPresentation();
  }

  final Map<String, List<SetFieldType>> _exerciseFields = {};

  List<SetFieldType>? exerciseFields(String id) => _exerciseFields[id] == null
      ? null
      : List.unmodifiable(_exerciseFields[id]!);

  void setExerciseFields(String id, List<SetFieldType> fields) {
    if (fields.isEmpty) return;
    _exerciseFields[id] = fields.toSet().toList();
    notifyListeners();
    _persistPresentation();
  }

  void _persistPresentation() {
    unawaited(saveDraftWorkout().catchError((Object error) {
      debugPrint('Could not save workout display preferences: $error');
    }));
  }

  final StorageService _storageService;
  final SyncService _syncService;
  final Set<String> _celebratedRecords = {};
  List<PersonalRecord> get personalRecords =>
      PRService.records(_workoutHistory);
  List<PersonalRecord> get activeRecords => _currentWorkout == null
      ? []
      : PRService.forWorkout(
          _currentWorkout!,
          PRService.bests(
              _workoutHistory.where((w) => w.id != _currentWorkout!.id)));
  List<PersonalRecord> bestForExercise(String id) {
    final canonical = ExerciseCatalog.canonicalId(id);
    return PRService.bests(_workoutHistory)
        .values
        .where((r) => (r.canonicalId ?? r.exerciseId) == canonical)
        .toList();
  }

  List<WorkoutLog> _workoutHistory = [];
  List<WorkoutLog> get workoutHistory => _workoutHistory;

  // Callback for PR notification
  Function(List<PersonalRecord>)? onPersonalRecords;

  late final Future<void> ready;

  WorkoutNotifier(this._syncService,
      {StorageService? storageService, RecoveryService? recoveryService})
      : _storageService = storageService ?? StorageService() {
    ready = _initialize();
    unawaited(ready.catchError((Object error) {
      debugPrint('Could not read saved workouts: $error');
    }));
  }

  Future<void> _initialize() async {
    await _loadWorkoutHistory();
    if (!isDisposed) await _autoRestoreDraftWorkout();
  }

  Future<void> _loadWorkoutHistory() async {
    _workoutHistory = await _storageService.getWorkouts();
    notifyListeners();
  }

  /// Load workout history from cloud (called on auth)
  Future<void> loadWorkoutHistoryFromCloud(String userId) async {
    _workoutHistory = await _syncService.getWorkouts(userId);
    notifyListeners();
  }

  Future<bool> hasDraftWorkout() async {
    return await _storageService.hasDraftWorkout();
  }

  Future<void> saveDraftWorkout() async {
    if (_currentWorkout == null) return;

    final draftData = {
      'celebratedRecords': _celebratedRecords.toList(),
      'collapsedExercises': _collapsedExercises.toList(),
      'exerciseFields': _exerciseFields.map((id, fields) =>
          MapEntry(id, fields.map((field) => field.name).toList())),
      'workoutName': _workoutName,
      'workoutNotes': _workoutNotes,
      'startTime': _startTime?.toIso8601String(),
      'elapsedSeconds': _elapsedSeconds,
      'lastActivity': _lastActivity?.toIso8601String(),
      'pausedAt': _pausedAt?.toIso8601String(),
      'pausedSeconds': _pausedSeconds,
      'timestamp': _currentWorkout!.timestamp.toIso8601String(),
      'exercises': _currentWorkout!.exercises.map((e) => e.toJson()).toList(),
      'superSets': _currentWorkout!.superSets.map((s) => s.toJson()).toList(),
    };

    await _storageService.saveDraftWorkout(draftData);
  }

  Future<void> loadDraftWorkout() async {
    if (_isWorkoutActive) return;
    final draftData = await _storageService.getDraftWorkout();
    if (isDisposed || draftData == null) return;

    _celebratedRecords
      ..clear()
      ..addAll(
          (draftData['celebratedRecords'] as List? ?? []).whereType<String>());
    _collapsedExercises
      ..clear()
      ..addAll(
          (draftData['collapsedExercises'] as List? ?? []).whereType<String>());
    _exerciseFields.clear();
    final savedFields = draftData['exerciseFields'];
    if (savedFields is Map) {
      for (final entry in savedFields.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        final fields = (entry.value as List)
            .whereType<String>()
            .map((name) =>
                SetFieldType.values.where((field) => field.name == name))
            .expand((fields) => fields)
            .toSet()
            .toList();
        if (fields.isNotEmpty) _exerciseFields[entry.key as String] = fields;
      }
    }
    _workoutName = draftData['workoutName'] as String? ?? 'My Workout 1';
    _workoutNotes = draftData['workoutNotes'] as String? ?? '';
    _elapsedSeconds = draftData['elapsedSeconds'] as int? ?? 0;
    _lastActivity =
        DateTime.tryParse(draftData['lastActivity'] as String? ?? '');
    _pausedAt = DateTime.tryParse(draftData['pausedAt'] as String? ?? '');
    _pausedSeconds = draftData['pausedSeconds'] as int? ?? 0;

    if (draftData['startTime'] != null) {
      try {
        _startTime = DateTime.parse(draftData['startTime'] as String);
      } catch (_) {
        _startTime = null;
      }
    }

    final exercises = (draftData['exercises'] as List? ?? [])
        .map((e) => WorkoutExerciseLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final superSets = (draftData['superSets'] as List? ?? [])
        .map((s) => SuperSet.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    _currentWorkout = WorkoutLog(
      workoutName: _workoutName,
      timestamp: DateTime.tryParse(draftData['timestamp'] as String? ?? '') ??
          _startTime ??
          DateTime.now(),
      durationSeconds: 0,
      exercises: exercises,
      superSets: superSets,
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
    _clearPause();
    _celebratedRecords.clear();
    _collapsedExercises.clear();
    _exerciseFields.clear();
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void startWorkout({String? workoutName}) {
    _celebratedRecords.clear();
    _collapsedExercises.clear();
    _exerciseFields.clear();
    _stopAutoSave();
    _isWorkoutActive = true;
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _clearPause();
    _workoutName = workoutName ?? 'My Workout 1';
    _workoutNotes = '';
    _currentWorkout = WorkoutLog(
      workoutName: _workoutName,
      timestamp: DateTime.now(),
      durationSeconds: 0,
      exercises: [],
    );

    _startAutoSave();
    _planReminder(clock());
    // Timer will be started when first set is marked complete
    notifyListeners();
  }

  void updateWorkoutName(String name) {
    _touch();
    _workoutName = name;
    notifyListeners();
  }

  void updateWorkoutNotes(String notes) {
    _touch();
    _workoutNotes = notes;
    notifyListeners();
  }

  void _startTimer({bool restart = false}) {
    if (_timerStarted && !restart) return;
    _timer?.cancel();
    _timerStarted = true;
    _startTime ??= clock();
    _lastActivity ??= clock();
    _checkIdle();
    _elapsedSeconds = _calculateElapsedSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final stopped = _checkIdle();
      final elapsed = _calculateElapsedSeconds();
      if (!stopped && _pausedAt != null && elapsed == _elapsedSeconds) return;
      _elapsedSeconds = elapsed;
      notifyListeners();
    });
    notifyListeners();
  }

  void addExercise(Exercise exercise) {
    _touch();
    if (_currentWorkout == null) return;
    _currentWorkout!.exercises.add(WorkoutExerciseLog(
      exerciseId: exercise.id,
      exerciseType: exercise.exerciseType.name,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
      gifUrl: exercise.gifUrl,
      // Cardio is one session, not sets.
      sets: exercise.exerciseType == ExerciseType.cardio
          ? [WorkoutSet()]
          : [
              WorkoutSet(weight: null, reps: null),
              WorkoutSet(weight: null, reps: null),
              WorkoutSet(weight: null, reps: null),
            ],
    ));
    notifyListeners();
  }

  // Cardio stopwatches by exercise: when each started running.
  final Map<String, DateTime> _cardioRunning = {};

  WorkoutSet? _cardioSet(String exerciseId) {
    final log = _currentWorkout?.exercises
        .where((e) => e.exerciseId == exerciseId)
        .firstOrNull;
    if (log == null) return null;
    if (log.sets.isEmpty) log.sets.add(WorkoutSet());
    return log.sets.first;
  }

  bool isCardioRunning(String exerciseId) =>
      _cardioRunning.containsKey(exerciseId);

  /// Seconds on a cardio session, including a stopwatch still running.
  int cardioSeconds(String exerciseId) {
    final saved = _cardioSet(exerciseId)?.durationSeconds ?? 0;
    final since = _cardioRunning[exerciseId];
    return since == null ? saved : saved + clock().difference(since).inSeconds;
  }

  /// Starts (or resumes) a cardio session's stopwatch; the workout clock
  /// starts with it.
  void startCardio(String exerciseId) {
    if (_cardioSet(exerciseId) == null || isCardioRunning(exerciseId)) return;
    _cardioRunning[exerciseId] = clock();
    _touch();
    if (!_timerStarted) _startTimer();
    notifyListeners();
  }

  /// Stops a cardio stopwatch and keeps the time.
  void stopCardio(String exerciseId) {
    final since = _cardioRunning.remove(exerciseId);
    final set = _cardioSet(exerciseId);
    if (since == null || set == null) return;
    set.durationSeconds =
        (set.durationSeconds ?? 0) + clock().difference(since).inSeconds;
    _settleCardio(set);
  }

  /// Stops every running cardio stopwatch, e.g. before saving.
  void stopAllCardio() {
    for (final id in _cardioRunning.keys.toList()) {
      stopCardio(id);
    }
  }

  /// Changes a cardio session's numbers. A session counts as logged once it
  /// has a time or a distance.
  void updateCardio(String exerciseId, void Function(WorkoutSet set) change) {
    final set = _cardioSet(exerciseId);
    if (set == null) return;
    change(set);
    _settleCardio(set);
  }

  void _settleCardio(WorkoutSet set) {
    set.isCompleted = (set.durationSeconds ?? 0) > 0 || (set.distance ?? 0) > 0;
    _touch();
    if (set.isCompleted && !_timerStarted) _startTimer();
    _persistPresentation();
    notifyListeners();
  }

  /// Add exercise from a template with pre-configured sets
  void addExerciseFromTemplate({
    required String name,
    String? exerciseId,
    int targetSets = 3,
    int? targetReps,
    double? targetWeight,
    Exercise? exerciseDefinition,
  }) {
    _touch();
    if (_currentWorkout == null) return;

    // Try to find the exercise in the database, or create a custom one
    final exerciseData = EXERCISE_LIBRARY.firstWhere(
      (e) => (e['name'] as String).toLowerCase() == name.toLowerCase(),
      orElse: () => {
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'muscleGroup': '',
        'equipment': 'None',
      },
    );

    // Create sets with template values; cardio is one session.
    final cardio = exerciseDefinition?.exerciseType == ExerciseType.cardio;
    final sets = List.generate(
      cardio ? 1 : targetSets,
      (_) => WorkoutSet(
        weight: targetWeight,
        reps: targetReps,
      ),
    );

    _currentWorkout!.exercises.add(WorkoutExerciseLog(
      exerciseId: exerciseId ?? exerciseData['id'] as String,
      exerciseName: exerciseDefinition?.name ?? exerciseData['name'] as String?,
      muscleGroup: exerciseDefinition?.muscleGroup ??
          exerciseData['muscleGroup'] as String?,
      equipment:
          exerciseDefinition?.equipment ?? exerciseData['equipment'] as String?,
      exerciseType: exerciseDefinition?.exerciseType.name,
      gifUrl: exerciseDefinition?.gifUrl,
      sets: sets,
    ));
    notifyListeners();
  }

  void addSet(String exerciseId) {
    _touch();
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises
        .firstWhere((e) => e.exerciseId == exerciseId);

    // Get the last set to prepopulate values (or first set if available)
    WorkoutSet? templateSet;
    if (exerciseLog.sets.isNotEmpty) {
      // Try to find the last completed set (with values)
      for (int i = exerciseLog.sets.length - 1; i >= 0; i--) {
        final set = exerciseLog.sets[i];
        if (set.weight != null ||
            set.reps != null ||
            set.durationSeconds != null) {
          templateSet = set;
          break;
        }
      }
      // If no completed set, use the first set
      templateSet ??= exerciseLog.sets.first;
    }

    // Create new set with prepopulated values from template
    exerciseLog.sets.add(WorkoutSet(
      weight: templateSet?.weight,
      weightUnit: templateSet?.weightUnit,
      reps: templateSet?.reps,
      durationSeconds: templateSet?.durationSeconds,
      distance: templateSet?.distance,
      distanceUnit: templateSet?.distanceUnit,
      speed: templateSet?.speed,
      incline: templateSet?.incline,
      resistance: templateSet?.resistance,
    ));
    notifyListeners();
  }

  /// Add a set to all exercises in a superset
  void addSetToSuperSet(String superSetId) {
    _touch();
    if (_currentWorkout == null) return;
    final superSet = getSuperSet(superSetId);
    if (superSet == null) return;

    for (final exerciseId in superSet.exerciseIds) {
      final exerciseLog = _currentWorkout!.exercises.firstWhere(
          (e) => e.exerciseId == exerciseId,
          orElse: () => throw Exception('Exercise not found'));

      // Get template set for prepopulation
      WorkoutSet? templateSet;
      if (exerciseLog.sets.isNotEmpty) {
        for (int i = exerciseLog.sets.length - 1; i >= 0; i--) {
          final set = exerciseLog.sets[i];
          if (set.weight != null ||
              set.reps != null ||
              set.durationSeconds != null) {
            templateSet = set;
            break;
          }
        }
        templateSet ??= exerciseLog.sets.first;
      }

      exerciseLog.sets.add(WorkoutSet(
        weight: templateSet?.weight,
        weightUnit: templateSet?.weightUnit,
        reps: templateSet?.reps,
        durationSeconds: templateSet?.durationSeconds,
        distance: templateSet?.distance,
        distanceUnit: templateSet?.distanceUnit,
        speed: templateSet?.speed,
        incline: templateSet?.incline,
        resistance: templateSet?.resistance,
      ));
    }
    notifyListeners();
  }

  void removeSet(String exerciseId, int setIndex) {
    _touch();
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises
        .firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length && exerciseLog.sets.length > 1) {
      exerciseLog.sets.removeAt(setIndex);
      notifyListeners();
    }
  }

  void updateCardioDetails(String exerciseId,
      {int? averageHeartRate, String? intensity}) {
    _touch();
    if (_currentWorkout == null) return;
    if (averageHeartRate != null &&
        (averageHeartRate < 1 || averageHeartRate > 300))
      throw ArgumentError('Invalid heart rate');
    if (intensity != null && !['Low', 'Moderate', 'High'].contains(intensity))
      throw ArgumentError('Invalid effort');
    final index = _currentWorkout!.exercises
        .indexWhere((e) => e.exerciseId == exerciseId);
    if (index < 0) return;
    final e = _currentWorkout!.exercises[index];
    _currentWorkout!.exercises[index] = WorkoutExerciseLog(
        exerciseId: e.exerciseId,
        exerciseName: e.exerciseName,
        exerciseType: e.exerciseType,
        muscleGroup: e.muscleGroup,
        equipment: e.equipment,
        gifUrl: e.gifUrl,
        sets: e.sets,
        superSetId: e.superSetId,
        orderInSuperSet: e.orderInSuperSet,
        averageHeartRate: averageHeartRate,
        intensity: intensity);
    notifyListeners();
  }

  void updateSet(
    String exerciseId,
    int setIndex, {
    double? weight,
    String? weightUnit,
    bool clearWeight = false,
    bool clearReps = false,
    int? reps,
    int? durationSeconds,
    double? distance,
    String? distanceUnit,
    double? speed,
    double? incline,
    int? resistance,
  }) {
    _touch();
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises
        .firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length) {
      final set = exerciseLog.sets[setIndex];
      final before = (
        weight: set.weight,
        weightUnit: set.weightUnit,
        reps: set.reps,
        durationSeconds: set.durationSeconds,
        distance: set.distance,
        distanceUnit: set.distanceUnit,
      );
      // Only update provided fields, keep existing values for null
      if (clearWeight) {
        set.weight = null;
        set.weightUnit = null;
      }
      if (clearReps) set.reps = null;
      if (weight != null) {
        set.weight = weight;
        set.weightUnit = weightUnit ?? set.weightUnit;
      }
      if (reps != null) set.reps = reps;
      if (durationSeconds != null) set.durationSeconds = durationSeconds;
      if (distance != null) {
        set.distance = distance;
        set.distanceUnit = distanceUnit ?? set.distanceUnit;
      }
      if (speed != null) set.speed = speed;
      if (incline != null) set.incline = incline;
      if (resistance != null) set.resistance = resistance;
      // Later sets still showing this set's old value follow the change, so
      // entering set 1 fills the rest. Completed sets and any set given its
      // own value are left alone.
      for (final later in exerciseLog.sets.skip(setIndex + 1)) {
        if (later.isCompleted || later.isSuperSetRest) continue;
        if (set.weight != before.weight &&
            later.weight == before.weight &&
            later.weightUnit == before.weightUnit) {
          later.weight = set.weight;
          later.weightUnit = set.weightUnit;
        }
        if (set.reps != before.reps && later.reps == before.reps) {
          later.reps = set.reps;
        }
        if (set.durationSeconds != before.durationSeconds &&
            later.durationSeconds == before.durationSeconds) {
          later.durationSeconds = set.durationSeconds;
        }
        if (set.distance != before.distance &&
            later.distance == before.distance &&
            later.distanceUnit == before.distanceUnit) {
          later.distance = set.distance;
          later.distanceUnit = set.distanceUnit;
        }
      }
      notifyListeners();
    }
  }

  /// Update set with explicit null clearing (for clearing fields)
  void updateSetFields(
    String exerciseId,
    int setIndex, {
    required double? weight,
    required int? reps,
    required int? durationSeconds,
    required double? distance,
    required double? speed,
    required double? incline,
    required int? resistance,
  }) {
    _touch();
    if (_currentWorkout == null) return;
    final exerciseLog = _currentWorkout!.exercises
        .firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < exerciseLog.sets.length) {
      final set = exerciseLog.sets[setIndex];
      set.weight = weight;
      set.reps = reps;
      set.durationSeconds = durationSeconds;
      set.distance = distance;
      set.speed = speed;
      set.incline = incline;
      set.resistance = resistance;
      notifyListeners();
    }
  }

  void toggleSetCompletion(String exerciseId, int setIndex) {
    if (_currentWorkout == null) return;
    final exercise = _currentWorkout!.exercises
        .firstWhere((e) => e.exerciseId == exerciseId);
    if (setIndex < 0 || setIndex >= exercise.sets.length) return;
    final before = {for (final r in activeRecords) r.key: r};
    final set = exercise.sets[setIndex];
    set.isCompleted = !set.isCompleted;
    _touch();
    if (set.isCompleted && !_timerStarted) _startTimer();
    final celebrate = <PersonalRecord>[];
    if (set.isCompleted) {
      for (final record in activeRecords.where((r) =>
          r.exerciseId == exerciseId &&
          r.setIndex == setIndex &&
          !r.isBaseline)) {
        final prior = before[record.key];
        if ((prior == null ||
                PRService.compare(record.weightKg, record.reps, prior.weightKg,
                        prior.reps) >
                    0) &&
            _celebratedRecords.add(record.celebrationId)) celebrate.add(record);
      }
    }
    _persistPresentation();
    notifyListeners();
    if (celebrate.isNotEmpty) onPersonalRecords?.call(celebrate);
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
      superSets: _currentWorkout!.superSets,
      notes: _workoutNotes,
      isTestData: false,
    );

    // Sync to cloud (with local fallback)
    await _syncService.syncWorkout(userId, finishedWorkout);
    if (isDisposed) return;

    // Optional copy to Apple Health; never blocks or fails the save.
    unawaited(AppleHealthService.instance.saveWorkout(userId, finishedWorkout));

    // Reload history
    await _loadWorkoutHistory();

    if (isDisposed) return;

    try {
      // Show workout completion notification
      final notificationService = NotificationService();
      await notificationService.showWorkoutCompleteNotification(
        workoutName: finishedWorkout.workoutName,
        duration: Duration(seconds: _elapsedSeconds),
        exerciseCount: finishedWorkout.exercises.length,
      );
    } catch (error) {
      debugPrint('Workout saved; notification unavailable: $error');
    }

    // Delete draft workout if it exists
    await deleteDraftWorkout();

    _isWorkoutActive = false;
    _currentWorkout = null;
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _clearPause();
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
    notifyListeners();
  }

  /// Finish and save a specific workout with provided data
  /// Used when workout data is passed from summary screen to avoid timing issues
  Future<void> finishWorkoutWithData(
    WorkoutLog workout,
    int durationSeconds,
    String notes,
    String? userId,
  ) async {
    _timer?.cancel();
    _timer = null;
    _stopAutoSave();

    // Create finished workout with provided data
    final finishedWorkout = WorkoutLog(
      workoutName: workout.workoutName,
      timestamp: workout.timestamp,
      durationSeconds: durationSeconds,
      exercises: workout.exercises,
      superSets: workout.superSets,
      notes: notes.trim().isEmpty ? null : notes.trim(),
      isTestData: false,
    );

    // Sync to cloud (with local fallback)
    await _syncService.syncWorkout(userId, finishedWorkout);
    if (isDisposed) return;

    // Reload history
    await _loadWorkoutHistory();

    if (isDisposed) return;

    try {
      // Show workout completion notification
      final notificationService = NotificationService();
      await notificationService.showWorkoutCompleteNotification(
        workoutName: finishedWorkout.workoutName,
        duration: Duration(seconds: durationSeconds),
        exerciseCount: finishedWorkout.exercises.length,
      );
    } catch (error) {
      debugPrint('Workout saved; notification unavailable: $error');
    }

    // Delete draft workout if it exists
    await deleteDraftWorkout();

    // Reset local state
    _isWorkoutActive = false;
    _currentWorkout = null;
    _startTime = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
    _clearPause();
    _workoutName = 'My Workout 1';
    _workoutNotes = '';
    notifyListeners();

    debugPrint(
        'Workout saved successfully with data: ${finishedWorkout.workoutName}');
  }

  /// Refresh workout history from cloud
  Future<void> refreshWorkoutHistory(String? userId) async {
    _workoutHistory = await _syncService.getWorkouts(userId);
    notifyListeners();
  }

  void removeExercise(int exerciseIndex) {
    _touch();
    if (_currentWorkout == null) return;
    _currentWorkout!.exercises.removeAt(exerciseIndex);
    notifyListeners();
  }

  /// Create a super set from selected exercises
  void createSuperSet(List<String> exerciseIds) {
    _touch();
    if (_currentWorkout == null || exerciseIds.length < 2) return;

    final superSetId = 'superset_${DateTime.now().millisecondsSinceEpoch}';
    final superSet = SuperSet(
      id: superSetId,
      exerciseIds: exerciseIds,
    );

    _currentWorkout!.superSets.add(superSet);

    // Update exercise logs with super set info
    for (int i = 0; i < exerciseIds.length; i++) {
      final exerciseIndex = _currentWorkout!.exercises
          .indexWhere((e) => e.exerciseId == exerciseIds[i]);
      if (exerciseIndex != -1) {
        final exercise = _currentWorkout!.exercises[exerciseIndex];
        _currentWorkout!.exercises[exerciseIndex] = WorkoutExerciseLog(
          exerciseId: exercise.exerciseId,
          exerciseType: exercise.exerciseType,
          averageHeartRate: exercise.averageHeartRate,
          intensity: exercise.intensity,
          exerciseName: exercise.exerciseName,
          muscleGroup: exercise.muscleGroup,
          equipment: exercise.equipment,
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
    _touch();
    if (_currentWorkout == null) return;

    final exerciseIndex = _currentWorkout!.exercises
        .indexWhere((e) => e.exerciseId == exerciseId);

    if (exerciseIndex != -1) {
      final exercise = _currentWorkout!.exercises[exerciseIndex];
      if (exercise.superSetId != null) {
        // Find the super set and remove exercise
        final superSetIndex = _currentWorkout!.superSets
            .indexWhere((s) => s.id == exercise.superSetId);

        if (superSetIndex != -1) {
          final superSet = _currentWorkout!.superSets[superSetIndex];
          final updatedExerciseIds =
              superSet.exerciseIds.where((id) => id != exerciseId).toList();

          if (updatedExerciseIds.length < 2) {
            // Remove entire super set if less than 2 exercises
            _currentWorkout!.superSets.removeAt(superSetIndex);
            // Clear super set info from remaining exercises
            for (final remainingId in updatedExerciseIds) {
              final remainingIndex = _currentWorkout!.exercises
                  .indexWhere((e) => e.exerciseId == remainingId);
              if (remainingIndex != -1) {
                final remainingExercise =
                    _currentWorkout!.exercises[remainingIndex];
                _currentWorkout!.exercises[remainingIndex] = WorkoutExerciseLog(
                  exerciseId: remainingExercise.exerciseId,
                  exerciseType: remainingExercise.exerciseType,
                  averageHeartRate: remainingExercise.averageHeartRate,
                  intensity: remainingExercise.intensity,
                  exerciseName: remainingExercise.exerciseName,
                  muscleGroup: remainingExercise.muscleGroup,
                  equipment: remainingExercise.equipment,
                  sets: remainingExercise.sets,
                );
              }
            }
          } else {
            // Update super set with remaining exercises
            _currentWorkout!.superSets[superSetIndex] =
                superSet.copyWith(exerciseIds: updatedExerciseIds);
            // Update order for remaining exercises
            for (int i = 0; i < updatedExerciseIds.length; i++) {
              final remainingIndex = _currentWorkout!.exercises
                  .indexWhere((e) => e.exerciseId == updatedExerciseIds[i]);
              if (remainingIndex != -1) {
                final remainingExercise =
                    _currentWorkout!.exercises[remainingIndex];
                _currentWorkout!.exercises[remainingIndex] = WorkoutExerciseLog(
                  exerciseId: remainingExercise.exerciseId,
                  exerciseType: remainingExercise.exerciseType,
                  averageHeartRate: remainingExercise.averageHeartRate,
                  intensity: remainingExercise.intensity,
                  exerciseName: remainingExercise.exerciseName,
                  muscleGroup: remainingExercise.muscleGroup,
                  equipment: remainingExercise.equipment,
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
          exerciseType: exercise.exerciseType,
          averageHeartRate: exercise.averageHeartRate,
          intensity: exercise.intensity,
          exerciseName: exercise.exerciseName,
          muscleGroup: exercise.muscleGroup,
          equipment: exercise.equipment,
          sets: exercise.sets,
        );
      }
    }

    notifyListeners();
  }

  /// Reorder exercises within a super set
  void reorderSuperSetExercises(String superSetId, List<String> newOrder) {
    _touch();
    if (_currentWorkout == null) return;

    final superSetIndex =
        _currentWorkout!.superSets.indexWhere((s) => s.id == superSetId);

    if (superSetIndex != -1) {
      _currentWorkout!.superSets[superSetIndex] = _currentWorkout!
          .superSets[superSetIndex]
          .copyWith(exerciseIds: newOrder);

      // Update order in exercise logs
      for (int i = 0; i < newOrder.length; i++) {
        final exerciseIndex = _currentWorkout!.exercises
            .indexWhere((e) => e.exerciseId == newOrder[i]);
        if (exerciseIndex != -1) {
          final exercise = _currentWorkout!.exercises[exerciseIndex];
          _currentWorkout!.exercises[exerciseIndex] = WorkoutExerciseLog(
            exerciseId: exercise.exerciseId,
            exerciseType: exercise.exerciseType,
            averageHeartRate: exercise.averageHeartRate,
            intensity: exercise.intensity,
            exerciseName: exercise.exerciseName,
            muscleGroup: exercise.muscleGroup,
            equipment: exercise.equipment,
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
    return _currentWorkout!.exercises
        .where((e) => e.superSetId == null)
        .toList();
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
    await _syncService.deleteWorkout(workout);
    _workoutHistory.removeWhere((w) => w.id == workout.id);

    notifyListeners();
  }

  /// Corrects the length of a saved workout, e.g. when the clock ran on
  /// after the last set or was never started.
  Future<void> updateWorkoutDuration(WorkoutLog workout, int seconds) async {
    final index = _workoutHistory.indexWhere((w) => w.id == workout.id);
    if (index == -1 || seconds <= 0) return;
    final saved = _workoutHistory[index];
    _workoutHistory[index] = WorkoutLog(
      workoutName: saved.workoutName,
      exercises: saved.exercises,
      timestamp: saved.timestamp,
      durationSeconds: seconds,
      notes: saved.notes,
      superSets: saved.superSets,
      isTestData: saved.isTestData,
    );
    notifyListeners();
    await _syncService.syncWorkout(
        _storageService.userId, _workoutHistory[index]);
  }

  /// Update workout notes for an existing workout
  Future<void> updateWorkoutHistoryNotes(
      WorkoutLog workout, String notes) async {
    // Find the workout in history and update it
    final index =
        _workoutHistory.indexWhere((w) => w.timestamp == workout.timestamp);
    if (index != -1) {
      _workoutHistory[index] = WorkoutLog(
        workoutName: workout.workoutName,
        exercises: workout.exercises,
        timestamp: workout.timestamp,
        durationSeconds: workout.durationSeconds,
        notes: notes.trim().isEmpty ? null : notes.trim(),
        superSets: workout.superSets,
        isTestData: workout.isTestData,
      );

      await _syncService.syncWorkout(
          _storageService.userId, _workoutHistory[index]);

      notifyListeners();
    }
  }

  /// Repeat a workout - start a new workout with the same exercises
  Future<void> repeatWorkout(WorkoutLog workout) async {
    // Reset current workout state
    resetWorkout();

    // Start new workout with same name and exercises
    startWorkout(workoutName: '${workout.workoutName} (Copy)');

    _currentWorkout!.exercises
        .addAll(workout.exercises.map((exercise) => WorkoutExerciseLog(
              exerciseId: exercise.exerciseId,
              exerciseType: exercise.exerciseType,
              exerciseName: exercise.exerciseName,
              muscleGroup: exercise.muscleGroup,
              equipment: exercise.equipment,
              gifUrl: exercise.gifUrl,
              sets: exercise.sets
                  .where((set) => !set.isSuperSetRest)
                  .map((set) => set.copyWith(isCompleted: false))
                  .toList(),
              superSetId: exercise.superSetId,
              orderInSuperSet: exercise.orderInSuperSet,
            )));
    _currentWorkout!.superSets.addAll(workout.superSets.map((set) =>
        set.copyWith(
            currentExerciseIndex: 0, currentRound: 1, isCompleted: false)));
    notifyListeners();
  }

  @override
  void dispose() {
    // Keep this account's latest draft without exposing it to the next session.
    if (_isWorkoutActive && _currentWorkout != null) {
      unawaited(saveDraftWorkout().catchError((Object error) {
        debugPrint('Could not preserve draft on session close: $error');
      }));
    }
    onPersonalRecords = null;
    _timer?.cancel();
    _stopAutoSave();
    super.dispose();
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    if (isDisposed || !_isWorkoutActive || _currentWorkout == null) return;

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
    if (isDisposed || !hasDraft || _isWorkoutActive) return;
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
    final end = _pausedAt ?? clock();
    final seconds = end.difference(_startTime!).inSeconds - _pausedSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}
