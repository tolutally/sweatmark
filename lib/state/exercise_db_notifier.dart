import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/exercise_db_repository.dart';
import '../models/exercise_model.dart';

/// State notifier for ExerciseDB browsing and search.
/// Handles debounced search, caching, and saved exercises.
class ExerciseDbNotifier extends ChangeNotifier {
  final ExerciseDbRepository _repository;

  ExerciseDbNotifier(this._repository);

  // Search results state
  List<Exercise> _exercises = [];
  bool _isLoading = false;
  String? _error;
  String _currentQuery = '';
  String? _currentBodyPart;
  String? _currentEquipment;

  // Saved exercises state
  List<Exercise> _savedExercises = [];
  bool _isLoadingSaved = false;
  final Set<String> _savedExerciseIds = {};

  // Filter options
  List<String> _bodyParts = [];
  List<String> _equipmentList = [];
  bool _filtersLoaded = false;

  // Debounce timer
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 400);
  static const int _minSearchLength = 2;

  // Request tracking for cancellation
  int _currentRequestId = 0;

  // Getters
  List<Exercise> get exercises => _exercises;
  List<Exercise> get savedExercises => _savedExercises;
  List<String> get bodyParts => _bodyParts;
  List<String> get equipmentList => _equipmentList;
  bool get isLoading => _isLoading;
  bool get isLoadingSaved => _isLoadingSaved;
  String? get error => _error;
  String get currentQuery => _currentQuery;
  String? get currentBodyPart => _currentBodyPart;
  String? get currentEquipment => _currentEquipment;
  bool get hasResults => _exercises.isNotEmpty;
  bool get hasFilters =>
      _currentQuery.isNotEmpty ||
      _currentBodyPart != null ||
      _currentEquipment != null;
  bool get filtersLoaded => _filtersLoaded;

  /// Initialize filter options (body parts and equipment)
  Future<void> initialize() async {
    if (_filtersLoaded) return;

    try {
      final results = await Future.wait([
        _repository.getBodyParts(),
        _repository.getEquipmentList(),
      ]);
      _bodyParts = results[0];
      _equipmentList = results[1];
      _filtersLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing ExerciseDbNotifier: $e');
      // Use defaults if initialization fails
      _bodyParts = [
        'back',
        'cardio',
        'chest',
        'lower arms',
        'lower legs',
        'neck',
        'shoulders',
        'upper arms',
        'upper legs',
        'waist',
      ];
      _equipmentList = [
        'barbell',
        'dumbbell',
        'body weight',
        'cable',
        'kettlebell',
        'machine',
      ];
      _filtersLoaded = true;
      notifyListeners();
    }
  }

  /// Search with debounce (call from UI text field onChange)
  void searchWithDebounce(String query) {
    _debounceTimer?.cancel();
    _currentQuery = query;

    // Clear results if query is too short and no filters
    if (query.length < _minSearchLength &&
        _currentBodyPart == null &&
        _currentEquipment == null) {
      _exercises = [];
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Show loading immediately for better UX
    _isLoading = true;
    notifyListeners();

    _debounceTimer = Timer(_debounceDuration, () {
      _executeSearch();
    });
  }

  /// Execute search immediately (for filter changes)
  Future<void> search({
    String? query,
    String? bodyPart,
    String? equipment,
    bool forceLoad = false,
  }) async {
    _debounceTimer?.cancel();

    if (query != null) _currentQuery = query;
    if (bodyPart != null || bodyPart == null) _currentBodyPart = bodyPart;
    if (equipment != null || equipment == null) _currentEquipment = equipment;

    await _executeSearch(forceLoad: forceLoad);
  }

  /// Internal search execution with cancellation support
  Future<void> _executeSearch({bool forceLoad = false}) async {
    // Increment request ID to track current request
    final requestId = ++_currentRequestId;

    // Skip if no search criteria (unless forceLoad is true)
    if (!forceLoad &&
        _currentQuery.length < _minSearchLength &&
        _currentBodyPart == null &&
        _currentEquipment == null) {
      _exercises = [];
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _repository.searchExercises(
        query: _currentQuery.length >= _minSearchLength ? _currentQuery : null,
        bodyPart: _currentBodyPart,
        equipment: _currentEquipment,
        limit: 500,
      );

      // Check if this request is still current (not superseded)
      if (requestId != _currentRequestId) {
        return; // Discard stale results
      }

      _exercises = results;
      _error = null;
    } catch (e) {
      // Check if this request is still current
      if (requestId != _currentRequestId) {
        return;
      }

      _error = 'Failed to search exercises. Please try again.';
      _exercises = [];
      print('Search error: $e');
    } finally {
      // Only update loading state if this is still the current request
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Filter by body part
  Future<void> filterByBodyPart(String? bodyPart) async {
    _currentBodyPart = bodyPart;
    await _executeSearch();
  }

  /// Filter by equipment
  Future<void> filterByEquipment(String? equipment) async {
    _currentEquipment = equipment;
    await _executeSearch();
  }

  /// Clear all filters and results
  void clearFilters() {
    _debounceTimer?.cancel();
    _currentRequestId++; // Cancel any in-flight requests
    _currentQuery = '';
    _currentBodyPart = null;
    _currentEquipment = null;
    _exercises = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Load user's saved exercises
  Future<void> loadSavedExercises(String userId) async {
    _isLoadingSaved = true;
    notifyListeners();

    try {
      _savedExercises = await _repository.getUserSavedExercises(userId);
      _savedExerciseIds.clear();
      for (final exercise in _savedExercises) {
        final id = exercise.externalId ?? exercise.id;
        _savedExerciseIds.add(id);
      }
    } catch (e) {
      print('Error loading saved exercises: $e');
    } finally {
      _isLoadingSaved = false;
      notifyListeners();
    }
  }

  /// Save exercise to user's library
  Future<bool> saveExercise(String userId, Exercise exercise) async {
    try {
      await _repository.saveToUserLibrary(userId, exercise);

      // Add to local state
      final id = exercise.externalId ?? exercise.id;
      if (!_savedExerciseIds.contains(id)) {
        _savedExercises = [exercise, ..._savedExercises];
        _savedExerciseIds.add(id);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('Error saving exercise: $e');
      return false;
    }
  }

  /// Remove exercise from user's library
  Future<bool> removeExercise(String userId, Exercise exercise) async {
    try {
      final id = exercise.externalId ?? exercise.id;
      await _repository.removeFromUserLibrary(userId, id);

      // Remove from local state
      _savedExercises =
          _savedExercises.where((e) => (e.externalId ?? e.id) != id).toList();
      _savedExerciseIds.remove(id);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error removing exercise: $e');
      return false;
    }
  }

  /// Check if exercise is saved (instant, uses local cache)
  bool isExerciseSaved(Exercise exercise) {
    final id = exercise.externalId ?? exercise.id;
    return _savedExerciseIds.contains(id);
  }

  /// Get featured exercises (browse without search)
  Future<void> loadFeatured({String? bodyPart}) async {
    _currentQuery = '';
    _currentBodyPart = bodyPart;
    _currentEquipment = null;
    await _executeSearch();
  }

  /// Populate the exercise database by fetching from ExerciseDB API
  /// Returns a map with results including total exercises before/after
  Future<Map<String, dynamic>> populateExerciseDatabase({
    Function(String term, int progress, int total)? onProgress,
  }) async {
    return await _repository.populateExerciseDatabase(onProgress: onProgress);
  }

  /// Get current exercise count in database
  Future<int> getExerciseCount() async {
    return await _repository.getExerciseCount();
  }

  /// Clear the local cache (forces reload from Firestore)
  void clearCache() {
    _repository.clearCache();
    _exercises = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
