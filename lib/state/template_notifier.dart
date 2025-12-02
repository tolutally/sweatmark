import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/template_model.dart';
import '../services/template_service.dart';

class TemplateNotifier extends ChangeNotifier {
  final TemplateService _templateService = TemplateService();
  
  List<WorkoutTemplate> _templates = [];
  List<TemplateCollection> _collections = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  StreamSubscription<List<WorkoutTemplate>>? _templatesSubscription;
  StreamSubscription<List<TemplateCollection>>? _collectionsSubscription;

  // Getters
  List<WorkoutTemplate> get templates => _templates;
  List<TemplateCollection> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get templates grouped by collection
  Map<String?, List<WorkoutTemplate>> get templatesByCollection {
    final Map<String?, List<WorkoutTemplate>> grouped = {};
    for (final template in _templates) {
      final key = template.collectionId;
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(template);
    }
    return grouped;
  }

  /// Get uncategorized templates
  List<WorkoutTemplate> get uncategorizedTemplates =>
      _templates.where((t) => t.collectionId == null).toList();

  /// Get scheduled templates
  List<WorkoutTemplate> get scheduledTemplates =>
      _templates.where((t) => t.schedule?.isActive == true).toList();

  /// Initialize and start listening to user's templates
  void initialize(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _startListening();
  }

  void _startListening() {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    // Listen to templates
    _templatesSubscription?.cancel();
    _templatesSubscription = _templateService
        .getUserTemplates(_userId!)
        .listen(
          (templates) {
            _templates = templates;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );

    // Listen to collections
    _collectionsSubscription?.cancel();
    _collectionsSubscription = _templateService
        .getUserCollections(_userId!)
        .listen(
          (collections) {
            _collections = collections;
            notifyListeners();
          },
          onError: (error) {
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Create a new template
  Future<WorkoutTemplate?> createTemplate({
    required String name,
    required List<TemplateExercise> exercises,
    String? description,
    TemplateIcon icon = TemplateIcon.dumbbell,
    WorkoutSchedule? schedule,
    String? collectionId,
  }) async {
    if (_userId == null) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final template = await _templateService.createTemplateFromWorkout(
        userId: _userId!,
        name: name,
        exercises: exercises,
        description: description,
        icon: icon,
        schedule: schedule,
        collectionId: collectionId,
      );

      _isLoading = false;
      notifyListeners();
      return template;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update an existing template
  Future<bool> updateTemplate(WorkoutTemplate template) async {
    try {
      await _templateService.updateTemplate(template);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a template
  Future<bool> deleteTemplate(String templateId, String? collectionId) async {
    try {
      await _templateService.deleteTemplate(templateId, collectionId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Increment times used when starting workout from template
  Future<void> useTemplate(String templateId) async {
    try {
      await _templateService.incrementTimesUsed(templateId);
    } catch (e) {
      debugPrint('Error incrementing template usage: $e');
    }
  }

  /// Move template to a different collection
  Future<bool> moveTemplateToCollection(
      String templateId, String? oldCollectionId, String? newCollectionId) async {
    try {
      await _templateService.moveTemplateToCollection(
          templateId, oldCollectionId, newCollectionId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== COLLECTIONS ====================

  /// Create a new collection
  Future<TemplateCollection?> createCollection({
    required String name,
    String? description,
    TemplateIcon icon = TemplateIcon.dumbbell,
  }) async {
    if (_userId == null) return null;

    try {
      final collection = TemplateCollection(
        id: '',
        userId: _userId!,
        name: name,
        description: description,
        icon: icon,
      );
      return await _templateService.createCollection(collection);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update a collection
  Future<bool> updateCollection(TemplateCollection collection) async {
    try {
      await _templateService.updateCollection(collection);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a collection
  Future<bool> deleteCollection(String collectionId,
      {bool deleteTemplates = false}) async {
    try {
      await _templateService.deleteCollection(collectionId,
          deleteTemplates: deleteTemplates);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get collection by ID
  TemplateCollection? getCollectionById(String id) {
    try {
      return _collections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get templates in a specific collection
  List<WorkoutTemplate> getTemplatesInCollection(String collectionId) {
    return _templates.where((t) => t.collectionId == collectionId).toList();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _templatesSubscription?.cancel();
    _collectionsSubscription?.cancel();
    super.dispose();
  }
}
