import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/exercise_model.dart';

/// Repository for interacting with ExerciseDB exercises stored in Firestore.
/// Reads directly from the exercisedb_exercises collection (cached from Cloud Functions).
class ExerciseDbRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for exercises (loaded once per app session)
  List<Exercise>? _allExercises;
  bool _isLoading = false;

  /// Infer muscle group from exercise name
  String _inferMuscleGroup(String name) {
    final lowerName = name.toLowerCase();

    // Chest exercises
    if (lowerName.contains('chest') ||
        lowerName.contains('pec') ||
        lowerName.contains('bench press') ||
        lowerName.contains('push up') ||
        lowerName.contains('pushup') ||
        lowerName.contains('fly') ||
        lowerName.contains('dip')) {
      return 'chest';
    }

    // Back exercises
    if (lowerName.contains('back') ||
        lowerName.contains('lat') ||
        lowerName.contains('row') ||
        lowerName.contains('pull up') ||
        lowerName.contains('pullup') ||
        lowerName.contains('chin up') ||
        lowerName.contains('pulldown') ||
        lowerName.contains('deadlift')) {
      return 'back';
    }

    // Shoulder exercises
    if (lowerName.contains('shoulder') ||
        lowerName.contains('delt') ||
        lowerName.contains('overhead press') ||
        lowerName.contains('military press') ||
        lowerName.contains('lateral raise') ||
        lowerName.contains('front raise') ||
        lowerName.contains('shrug')) {
      return 'shoulders';
    }

    // Biceps
    if (lowerName.contains('bicep') ||
        lowerName.contains('curl') && !lowerName.contains('leg')) {
      return 'upper arms';
    }

    // Triceps
    if (lowerName.contains('tricep') ||
        lowerName.contains('pushdown') ||
        lowerName.contains('skull crusher') ||
        lowerName.contains('kickback') ||
        lowerName.contains('extension') && lowerName.contains('arm')) {
      return 'upper arms';
    }

    // Upper legs (quads, hamstrings, glutes)
    if (lowerName.contains('squat') ||
        lowerName.contains('lunge') ||
        lowerName.contains('leg press') ||
        lowerName.contains('leg extension') ||
        lowerName.contains('leg curl') ||
        lowerName.contains('hamstring') ||
        lowerName.contains('quad') ||
        lowerName.contains('glute') ||
        lowerName.contains('hip thrust') ||
        lowerName.contains('thigh')) {
      return 'upper legs';
    }

    // Lower legs (calves)
    if (lowerName.contains('calf') ||
        lowerName.contains('calves') ||
        lowerName.contains('tibialis')) {
      return 'lower legs';
    }

    // Core/Abs
    if (lowerName.contains('ab') ||
        lowerName.contains('core') ||
        lowerName.contains('crunch') ||
        lowerName.contains('plank') ||
        lowerName.contains('sit up') ||
        lowerName.contains('situp') ||
        lowerName.contains('oblique') ||
        lowerName.contains('russian twist')) {
      return 'waist';
    }

    // Forearms
    if (lowerName.contains('forearm') ||
        lowerName.contains('wrist curl') ||
        lowerName.contains('grip')) {
      return 'lower arms';
    }

    // Cardio
    if (lowerName.contains('cardio') ||
        lowerName.contains('run') ||
        lowerName.contains('jog') ||
        lowerName.contains('cycling') ||
        lowerName.contains('jump') ||
        lowerName.contains('burpee')) {
      return 'cardio';
    }

    // Neck
    if (lowerName.contains('neck')) {
      return 'neck';
    }

    return 'General';
  }

  /// Infer equipment from exercise name
  String _inferEquipment(String name) {
    final lowerName = name.toLowerCase();

    // Barbell exercises
    if (lowerName.contains('barbell') ||
        lowerName.contains('bench press') ||
        lowerName.contains('deadlift') ||
        lowerName.contains('squat') && !lowerName.contains('bodyweight') ||
        lowerName.contains('overhead press') ||
        lowerName.contains('military press') ||
        lowerName.contains('barbell row') ||
        lowerName.contains('clean') ||
        lowerName.contains('snatch')) {
      return 'barbell';
    }

    // Dumbbell exercises
    if (lowerName.contains('dumbbell') || lowerName.contains('db ')) {
      return 'dumbbell';
    }

    // Cable exercises
    if (lowerName.contains('cable') ||
        lowerName.contains('pulldown') ||
        lowerName.contains('pushdown') ||
        lowerName.contains('crossover') ||
        lowerName.contains('face pull')) {
      return 'cable';
    }

    // Machine exercises
    if (lowerName.contains('machine') ||
        lowerName.contains('leg press') ||
        lowerName.contains('leg extension') ||
        lowerName.contains('leg curl') ||
        lowerName.contains('pec deck') ||
        lowerName.contains('smith') ||
        lowerName.contains('hack squat') ||
        lowerName.contains('seated row')) {
      return 'machine';
    }

    // Kettlebell exercises
    if (lowerName.contains('kettlebell') ||
        lowerName.contains('kb ') ||
        lowerName.contains('swing')) {
      return 'kettlebell';
    }

    // Resistance band exercises
    if (lowerName.contains('band') || lowerName.contains('resistance')) {
      return 'band';
    }

    // EZ bar exercises
    if (lowerName.contains('ez bar') ||
        lowerName.contains('ez-bar') ||
        lowerName.contains('preacher curl')) {
      return 'ez barbell';
    }

    // Body weight exercises
    if (lowerName.contains('bodyweight') ||
        lowerName.contains('body weight') ||
        lowerName.contains('push up') ||
        lowerName.contains('pushup') ||
        lowerName.contains('pull up') ||
        lowerName.contains('pullup') ||
        lowerName.contains('chin up') ||
        lowerName.contains('chinup') ||
        lowerName.contains('dip') ||
        lowerName.contains('plank') ||
        lowerName.contains('crunch') ||
        lowerName.contains('sit up') ||
        lowerName.contains('situp') ||
        lowerName.contains('lunge') ||
        lowerName.contains('burpee') ||
        lowerName.contains('squat jump') ||
        lowerName.contains('mountain climber')) {
      return 'body weight';
    }

    // Default - try to be smart about common patterns
    if (lowerName.contains('curl') && !lowerName.contains('leg')) {
      return 'dumbbell'; // Most curls are dumbbell
    }

    if (lowerName.contains('raise')) {
      return 'dumbbell'; // Most raises are dumbbell
    }

    if (lowerName.contains('fly') || lowerName.contains('flye')) {
      return 'dumbbell'; // Most flies are dumbbell
    }

    return 'body weight'; // Default to body weight
  }

  /// Infer exercise type from name, equipment, and muscle group
  ExerciseType _inferExerciseType(
      String name, String equipment, String muscleGroup) {
    final lowerName = name.toLowerCase();
    final lowerEquipment = equipment.toLowerCase();
    final lowerMuscle = muscleGroup.toLowerCase();

    // Cardio exercises - check muscle group first
    if (lowerMuscle == 'cardio' ||
        lowerName.contains('treadmill') ||
        lowerName.contains('cycling') ||
        lowerName.contains('bike') ||
        lowerName.contains('rowing') ||
        lowerName.contains('elliptical') ||
        lowerName.contains('stair') ||
        lowerName.contains('run') ||
        lowerName.contains('jog') ||
        lowerName.contains('sprint')) {
      return ExerciseType.cardio;
    }

    // Timed hold exercises - bodyweight + specific patterns
    if (lowerEquipment == 'body weight' || lowerEquipment == 'bodyweight') {
      if (lowerName.contains('plank') ||
          lowerName.contains('hold') ||
          lowerName.contains('hang') ||
          lowerName.contains('wall sit') ||
          lowerName.contains('l-sit') ||
          lowerName.contains('bridge') && lowerName.contains('hold') ||
          lowerName.contains('hollow') ||
          lowerName.contains('superman') && !lowerName.contains('push')) {
        return ExerciseType.timedHold;
      }

      // Bodyweight reps exercises
      return ExerciseType.bodyweightReps;
    }

    // Weighted strength - default for barbell, dumbbell, cable, machine, kettlebell
    return ExerciseType.weightedStrength;
  }

  /// Load all exercises from Firestore cache
  Future<List<Exercise>> _loadAllExercises() async {
    if (_allExercises != null && _allExercises!.isNotEmpty) {
      return _allExercises!;
    }

    if (_isLoading) {
      // Wait for loading to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _allExercises ?? [];
    }

    _isLoading = true;

    try {
      print('📚 Loading ALL exercises from Firestore cache...');

      // Fetch all exercises using pagination to ensure we get everything
      List<Exercise> allExercises = [];
      DocumentSnapshot? lastDoc;
      const int batchSize = 500;

      while (true) {
        Query query =
            _firestore.collection('exercisedb_exercises').limit(batchSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) {
          break;
        }

        print('📦 Fetched batch of ${snapshot.docs.length} exercises...');

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? '';

          // Get muscle group - use stored value if not "General", otherwise infer from name
          String muscleGroup =
              data['muscleGroup'] ?? data['bodyPart'] ?? 'General';
          if (muscleGroup == 'General' && name.isNotEmpty) {
            muscleGroup = _inferMuscleGroup(name);
          }

          // Get equipment - use stored value if not "Various", otherwise infer from name
          String equipment = data['equipment'] ?? 'Various';
          if ((equipment == 'Various' || equipment.isEmpty) &&
              name.isNotEmpty) {
            equipment = _inferEquipment(name);
          }

          // Infer exercise type from name, equipment, and muscle group
          final exerciseType = _inferExerciseType(name, equipment, muscleGroup);

          // Handle instructions - can be String or List<String> from different sources
          String? instructions;
          final rawInstructions = data['instructions'];
          if (rawInstructions is String) {
            instructions = rawInstructions;
          } else if (rawInstructions is List && rawInstructions.isNotEmpty) {
            instructions = rawInstructions.join('\n');
          }

          allExercises.add(Exercise(
            id: data['id'] ?? doc.id,
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            icon: data['icon'] ?? '💪',
            instructions: instructions,
            gifUrl: data['gifUrl'],
            externalId: data['externalId'] ?? doc.id,
            source: data['source'] ?? 'exercisedb',
            secondaryMuscles: data['secondaryMuscles'] != null
                ? List<String>.from(data['secondaryMuscles'])
                : null,
            exerciseType: exerciseType,
          ));
        }

        lastDoc = snapshot.docs.last;

        // If we got less than batchSize, we've reached the end
        if (snapshot.docs.length < batchSize) {
          break;
        }
      }

      _allExercises = allExercises;

      // Sort by name
      _allExercises!.sort((a, b) => a.name.compareTo(b.name));

      print('✅ Loaded ${_allExercises!.length} total exercises');
      return _allExercises!;
    } catch (e) {
      print('❌ Error loading exercises from Firestore: $e');
      _allExercises = [];
      return [];
    } finally {
      _isLoading = false;
    }
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

    // Filter by query (name search)
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results
          .where((e) =>
              e.name.toLowerCase().contains(lowerQuery) ||
              e.muscleGroup.toLowerCase().contains(lowerQuery) ||
              e.equipment.toLowerCase().contains(lowerQuery))
          .toList();
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
      final callable = FirebaseFunctions.instance.httpsCallable(
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
          _allExercises![index] = _allExercises![index].copyWith(gifUrl: imageUrl);
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
      final callable = FirebaseFunctions.instance.httpsCallable(
        'downloadAllExercisesComplete',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
      );

      if (onProgress != null) {
        onProgress('Downloading all exercises (this may take several minutes)...', 1, 2);
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
