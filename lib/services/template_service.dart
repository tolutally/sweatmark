import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/template_model.dart';

class TemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections reference
  CollectionReference<Map<String, dynamic>> get _templatesRef =>
      _firestore.collection('templates');

  CollectionReference<Map<String, dynamic>> get _collectionsRef =>
      _firestore.collection('template_collections');

  // ==================== TEMPLATES ====================

  /// Create a new workout template
  Future<WorkoutTemplate> createTemplate(WorkoutTemplate template) async {
    try {
      print('📝 Creating template: ${template.name} for user: ${template.userId}');
      final docRef = _templatesRef.doc();
      final newTemplate = template.copyWith(id: docRef.id);
      await docRef.set(newTemplate.toMap());
      print('✅ Template saved to Firebase with ID: ${docRef.id}');
      
      // Update collection template count if part of a collection
      if (newTemplate.collectionId != null) {
        await _updateCollectionTemplateCount(newTemplate.collectionId!, 1);
        print('✅ Updated collection template count for: ${newTemplate.collectionId}');
      }
      
      return newTemplate;
    } catch (e) {
      print('❌ Error creating template: $e');
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate(WorkoutTemplate template) async {
    await _templatesRef.doc(template.id).update(template.toMap());
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId, String? collectionId) async {
    await _templatesRef.doc(templateId).delete();
    
    // Update collection template count
    if (collectionId != null) {
      await _updateCollectionTemplateCount(collectionId, -1);
    }
  }

  /// Get a single template by ID
  Future<WorkoutTemplate?> getTemplate(String templateId) async {
    final doc = await _templatesRef.doc(templateId).get();
    if (!doc.exists) return null;
    return WorkoutTemplate.fromMap(doc.data()!);
  }

  /// Get all templates for a user
  Stream<List<WorkoutTemplate>> getUserTemplates(String userId) {
    print('🔍 Fetching templates for user: $userId');
    return _templatesRef
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ Error fetching templates: $error');
          print('💡 TIP: You may need to create a composite index in Firebase Console');
        })
        .map((snapshot) {
          print('📦 Received ${snapshot.docs.length} templates from Firebase');
          return snapshot.docs
              .map((doc) => WorkoutTemplate.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get templates in a specific collection
  Stream<List<WorkoutTemplate>> getTemplatesInCollection(
      String userId, String collectionId) {
    return _templatesRef
        .where('userId', isEqualTo: userId)
        .where('collectionId', isEqualTo: collectionId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutTemplate.fromMap(doc.data()))
            .toList());
  }

  /// Get templates without a collection (uncategorized)
  Stream<List<WorkoutTemplate>> getUncategorizedTemplates(String userId) {
    return _templatesRef
        .where('userId', isEqualTo: userId)
        .where('collectionId', isNull: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutTemplate.fromMap(doc.data()))
            .toList());
  }

  /// Get scheduled templates (templates with active schedules)
  Stream<List<WorkoutTemplate>> getScheduledTemplates(String userId) {
    return _templatesRef
        .where('userId', isEqualTo: userId)
        .where('schedule.isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutTemplate.fromMap(doc.data()))
            .toList());
  }

  /// Increment times used counter
  Future<void> incrementTimesUsed(String templateId) async {
    await _templatesRef.doc(templateId).update({
      'timesUsed': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Move template to a different collection
  Future<void> moveTemplateToCollection(
      String templateId, String? oldCollectionId, String? newCollectionId) async {
    await _templatesRef.doc(templateId).update({
      'collectionId': newCollectionId,
      'updatedAt': Timestamp.now(),
    });

    // Update old collection count
    if (oldCollectionId != null) {
      await _updateCollectionTemplateCount(oldCollectionId, -1);
    }

    // Update new collection count
    if (newCollectionId != null) {
      await _updateCollectionTemplateCount(newCollectionId, 1);
    }
  }

  // ==================== COLLECTIONS ====================

  /// Create a new collection
  Future<TemplateCollection> createCollection(TemplateCollection collection) async {
    try {
      print('📁 Creating collection: ${collection.name} for user: ${collection.userId}');
      final docRef = _collectionsRef.doc();
      final newCollection = collection.copyWith(id: docRef.id);
      await docRef.set(newCollection.toMap());
      print('✅ Collection saved to Firebase with ID: ${docRef.id}');
      return newCollection;
    } catch (e) {
      print('❌ Error creating collection: $e');
      rethrow;
    }
  }

  /// Update a collection
  Future<void> updateCollection(TemplateCollection collection) async {
    await _collectionsRef.doc(collection.id).update(collection.toMap());
  }

  /// Delete a collection (and optionally its templates)
  Future<void> deleteCollection(String collectionId, {bool deleteTemplates = false}) async {
    if (deleteTemplates) {
      // Delete all templates in the collection
      final templates = await _templatesRef
          .where('collectionId', isEqualTo: collectionId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in templates.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } else {
      // Move templates to uncategorized
      final templates = await _templatesRef
          .where('collectionId', isEqualTo: collectionId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in templates.docs) {
        batch.update(doc.reference, {'collectionId': null});
      }
      await batch.commit();
    }

    await _collectionsRef.doc(collectionId).delete();
  }

  /// Get all collections for a user
  Stream<List<TemplateCollection>> getUserCollections(String userId) {
    print('🔍 Fetching collections for user: $userId');
    return _collectionsRef
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ Error fetching collections: $error');
          print('💡 TIP: You may need to create a composite index in Firebase Console');
        })
        .map((snapshot) {
          print('📦 Received ${snapshot.docs.length} collections from Firebase');
          return snapshot.docs
              .map((doc) => TemplateCollection.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get a single collection by ID
  Future<TemplateCollection?> getCollection(String collectionId) async {
    final doc = await _collectionsRef.doc(collectionId).get();
    if (!doc.exists) return null;
    return TemplateCollection.fromMap(doc.data()!);
  }

  // ==================== HELPERS ====================

  /// Update the template count for a collection
  Future<void> _updateCollectionTemplateCount(
      String collectionId, int delta) async {
    await _collectionsRef.doc(collectionId).update({
      'templateCount': FieldValue.increment(delta),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Create template from current workout
  Future<WorkoutTemplate> createTemplateFromWorkout({
    required String userId,
    required String name,
    required List<TemplateExercise> exercises,
    String? description,
    TemplateIcon icon = TemplateIcon.dumbbell,
    WorkoutSchedule? schedule,
    String? collectionId,
  }) async {
    final template = WorkoutTemplate(
      id: '',
      userId: userId,
      name: name,
      description: description,
      icon: icon,
      exercises: exercises,
      schedule: schedule,
      collectionId: collectionId,
    );
    return createTemplate(template);
  }
}
