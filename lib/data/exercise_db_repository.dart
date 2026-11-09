import '../services/exercise_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/exercise_model.dart';
import 'exercise_catalog.dart';
import 'exercise_data.dart';

/// Exercise catalog access. Browsing and search use the bundled catalog;
/// Firestore is used only for a user's saved exercises.
class ExerciseDbRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for exercises (loaded once per app session)
  List<Exercise>? _allExercises;

  /// Loads the bundled catalog once per session. The old Firestore
  /// `exercisedb_exercises` cache is no longer read by the app.
  Future<List<Exercise>> _loadAllExercises() async {
    if (_allExercises != null) return _allExercises!;
    try {
      _allExercises = await ExerciseCatalog.load();
    } catch (e) {
      debugPrint('Could not load the bundled exercise catalog: $e');
      _allExercises =
          EXERCISE_LIBRARY.map((json) => Exercise.fromJson(json)).toList();
    }
    return _allExercises!;
  }

  /// Search exercises by name, body part, or equipment
  /// Returns cached results from Firestore
  Future<List<Exercise>> searchExercises({
    String? query,
    String? bodyPart,
    String? equipment,
    int limit = 500,
  }) async {
    final allExercises = await _loadAllExercises();

    if (allExercises.isEmpty) {
      print('⚠️ No exercises loaded from Firestore');
      return [];
    }

    var results = List<Exercise>.from(allExercises);

    // Filter and rank by query (name, muscle, equipment, shorthand).
    if (query != null && query.trim().isNotEmpty) {
      results = ExerciseSearch.search(results, query);
    }

    // Filter by body part / muscle group
    if (bodyPart != null && bodyPart.isNotEmpty) {
      final lowerBodyPart = bodyPart.toLowerCase();
      results = results
          .where((e) =>
              e.muscleGroup.toLowerCase() == lowerBodyPart ||
              e.muscleGroup.toLowerCase().contains(lowerBodyPart))
          .toList();
    }

    // Filter by equipment
    if (equipment != null && equipment.isNotEmpty) {
      final lowerEquipment = equipment.toLowerCase();
      results = results
          .where((e) =>
              e.equipment.toLowerCase() == lowerEquipment ||
              e.equipment.toLowerCase().contains(lowerEquipment))
          .toList();
    }

    // Limit results
    if (results.length > limit) {
      results = results.sublist(0, limit);
    }

    return results;
  }

  /// Get exercise by external ID
  Future<Exercise?> getExerciseById(String externalId) async {
    final allExercises = await _loadAllExercises();
    try {
      return allExercises.firstWhere(
        (e) => e.externalId == externalId || e.id == externalId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get available body parts for filtering
  Future<List<String>> getBodyParts() async {
    final allExercises = await _loadAllExercises();

    if (allExercises.isEmpty) {
      // Return defaults if no exercises loaded
      return [
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
    }

    final bodyParts = allExercises
        .map((e) => e.muscleGroup)
        .where((bp) => bp.isNotEmpty)
        .toSet()
        .toList();
    bodyParts.sort();
    return bodyParts;
  }

  /// Get available equipment for filtering
  Future<List<String>> getEquipmentList() async {
    final allExercises = await _loadAllExercises();

    if (allExercises.isEmpty) {
      // Return defaults if no exercises loaded
      return [
        'barbell',
        'dumbbell',
        'body weight',
        'cable',
        'kettlebell',
        'machine',
        'band',
      ];
    }

    final equipment = allExercises
        .map((e) => e.equipment)
        .where((eq) => eq.isNotEmpty)
        .toSet()
        .toList();
    equipment.sort();
    return equipment;
  }

  /// Save an ExerciseDB exercise to user's library
  Future<void> saveToUserLibrary(String userId, Exercise exercise) async {
    final docId = exercise.externalId ?? exercise.id;
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_exercises')
        .doc(docId);

    await docRef.set({
      ...exercise.toJson(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user's saved exercises from ExerciseDB
  Future<List<Exercise>> getUserSavedExercises(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_exercises')
        .orderBy('savedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Exercise.fromJson(doc.data())).toList();
  }

  /// Remove exercise from user's library
  Future<void> removeFromUserLibrary(String userId, String exerciseId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_exercises')
        .doc(exerciseId)
        .delete();
  }

  /// Check if exercise is saved in user's library
  Future<bool> isExerciseSaved(String userId, String externalId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_exercises')
        .doc(externalId)
        .get();
    return doc.exists;
  }

  /// Clear in-memory cache (forces reload from Firestore)
  void clearCache() {
    _allExercises = null;
  }

  /// Refresh GymFit exercise image URL (they expire after 24 hours)
  /// Returns the new image URL or null if refresh failed
  Future<String?> refreshGymFitImage(String exerciseId) async {
    if (!exerciseId.startsWith('gymfit_')) {
      return null; // Only GymFit exercises need refresh
    }

    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-east1').httpsCallable(
        'refreshGymFitImage',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({'exerciseId': exerciseId});
      final data = result.data as Map<String, dynamic>;

      final imageUrl = data['imageUrl'] as String?;

      // Update the cached exercise if we have it
      if (imageUrl != null && _allExercises != null) {
        final index = _allExercises!.indexWhere(
          (e) => e.externalId == exerciseId || e.id == exerciseId,
        );
        if (index != -1) {
          _allExercises![index] =
              _allExercises![index].copyWith(gifUrl: imageUrl);
        }
      }

      return imageUrl;
    } catch (e) {
      print('Error refreshing GymFit image: $e');
      return null;
    }
  }

  /// Check if a GymFit image URL is expired (signed URLs expire after 24h)
  bool isGymFitImageExpired(String? gifUrl) {
    if (gifUrl == null || gifUrl.isEmpty) return true;
    if (!gifUrl.contains('gym-fit.s3')) return false; // Not a GymFit URL

    // Check X-Amz-Date and X-Amz-Expires in the URL
    try {
      final uri = Uri.parse(gifUrl);
      final amzDate = uri.queryParameters['X-Amz-Date'];
      final amzExpires = uri.queryParameters['X-Amz-Expires'];

      if (amzDate != null && amzExpires != null) {
        // Parse the date (format: 20260104T000001Z)
        final year = int.parse(amzDate.substring(0, 4));
        final month = int.parse(amzDate.substring(4, 6));
        final day = int.parse(amzDate.substring(6, 8));
        final hour = int.parse(amzDate.substring(9, 11));
        final minute = int.parse(amzDate.substring(11, 13));
        final second = int.parse(amzDate.substring(13, 15));

        final signedAt = DateTime.utc(year, month, day, hour, minute, second);
        final expiresInSeconds = int.parse(amzExpires);
        final expiresAt = signedAt.add(Duration(seconds: expiresInSeconds));

        return DateTime.now().toUtc().isAfter(expiresAt);
      }
    } catch (e) {
      print('Error parsing GymFit URL expiry: $e');
    }

    return false; // Assume not expired if we can't parse
  }

  /// Get total exercise count
  Future<int> getExerciseCount() async {
    final allExercises = await _loadAllExercises();
    return allExercises.length;
  }

  /// Populate the exercise database by calling the comprehensive Cloud Function
  /// This downloads ALL exercises from ExerciseDB API and stores them in Firestore
  /// Returns statistics about the download
  Future<Map<String, dynamic>> populateExerciseDatabase({
    Function(String term, int progress, int total)? onProgress,
  }) async {
    final beforeCount = await getExerciseCount();

    // Notify that we're starting
    if (onProgress != null) {
      onProgress('Calling Cloud Function...', 0, 1);
    }

    try {
      // Call the comprehensive download Cloud Function
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-east1').httpsCallable(
        'downloadAllExercisesComplete',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
      );

      if (onProgress != null) {
        onProgress(
            'Downloading all exercises (this may take several minutes)...',
            1,
            2);
      }

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      // Clear cache and reload to get accurate count
      clearCache();
      final afterCount = await getExerciseCount();

      if (onProgress != null) {
        onProgress('Complete!', 2, 2);
      }

      return {
        'totalBefore': beforeCount,
        'totalAfter': afterCount,
        'totalAdded': data['totalAdded'] ?? (afterCount - beforeCount),
        'totalInDb': data['totalInDb'] ?? afterCount,
        'searchTermsProcessed': data['searchTermsProcessed'] ?? 0,
        'errors': data['errors'] ?? [],
      };
    } catch (e) {
      print('Error calling downloadAllExercisesComplete: $e');

      // Fallback: try the old method with individual search terms
      return await _populateExerciseDatabaseFallback(
        onProgress: onProgress,
        beforeCount: beforeCount,
      );
    }
  }

  /// Fallback method for populating exercises if the Cloud Function fails
  Future<Map<String, dynamic>> _populateExerciseDatabaseFallback({
    Function(String term, int progress, int total)? onProgress,
    required int beforeCount,
  }) async {
    final searchTerms = [
      // Body parts
      'chest', 'back', 'shoulders', 'biceps', 'triceps', 'forearms',
      'abs', 'core', 'quads', 'hamstrings', 'glutes', 'calves',
      'lats', 'traps', 'neck',
      // Equipment
      'barbell', 'dumbbell', 'kettlebell', 'cable', 'machine', 'bodyweight',
      'band', 'smith machine', 'ez bar',
      // Common exercises
      'press', 'row', 'curl', 'extension', 'fly', 'raise', 'shrug',
      'squat', 'lunge', 'deadlift', 'leg press', 'hip thrust',
      'plank', 'crunch', 'pull up', 'push up', 'dip',
      // Position modifiers
      'incline', 'decline', 'seated', 'standing', 'lying',
      // Specific exercises
      'bench press', 'lat pulldown', 'face pull', 'cable crossover',
      'hammer curl', 'skull crusher', 'lateral raise', 'front raise',
      'romanian deadlift', 'sumo squat', 'goblet squat',
    ];

    final errors = <String>[];

    for (int i = 0; i < searchTerms.length; i++) {
      final term = searchTerms[i];

      if (onProgress != null) {
        onProgress(term, i + 1, searchTerms.length);
      }

      try {
        // Search using the term - this triggers the Cloud Function to fetch and cache
        await searchExercises(query: term, limit: 100);

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error fetching exercises for "$term": $e');
        errors.add(term);
      }
    }

    // Clear cache and reload to get accurate count
    clearCache();
    final afterCount = await getExerciseCount();
    final totalAdded = afterCount - beforeCount;

    return {
      'totalBefore': beforeCount,
      'totalAfter': afterCount,
      'totalAdded': totalAdded,
      'errors': errors,
      'searchTermsProcessed': searchTerms.length,
    };
  }
}
