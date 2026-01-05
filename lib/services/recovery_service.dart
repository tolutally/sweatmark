import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/muscle_recovery_model.dart';
import '../models/workout_model.dart';

class RecoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _recoveryFileName = 'muscle_recovery.json';

  /// Muscle groups to skip in recovery calculations
  static const List<String> excludedMuscleGroups = ['General', 'Cardio'];

  /// Sanitize muscle group names for use as Firestore document IDs
  /// Replaces forward slashes and other invalid characters
  static String sanitizeMuscleGroupId(String muscleGroup) {
    return muscleGroup.replaceAll('/', '_').replaceAll(' ', '_');
  }

  // ============================================
  // RECOVERY RATE CLASSIFICATION
  // ============================================

  /// Get recovery rate constant (k) for muscle group
  /// Fast (k=0.06): ~24-36h recovery
  /// Medium (k=0.04): ~36-60h recovery
  /// Slow (k=0.03): ~48-96h recovery
  static double getMuscleRecoveryRate(String muscleGroup) {
    final muscle = muscleGroup.toLowerCase();

    // Fast recovery muscles (k=0.06)
    if (muscle.contains('bicep') ||
        muscle.contains('tricep') ||
        muscle.contains('forearm') ||
        muscle.contains('core') ||
        muscle.contains('abs') ||
        muscle.contains('calf')) {
      return 0.06;
    }

    // Slow recovery muscles (k=0.03)
    if (muscle.contains('back') ||
        muscle.contains('lat') ||
        muscle.contains('quad') ||
        muscle.contains('hamstring') ||
        muscle.contains('glute') ||
        muscle.contains('leg')) {
      return 0.03;
    }

    // Medium recovery muscles (k=0.04) - includes Chest, Shoulders, Delts
    // Also default for unknown muscle groups
    return 0.04;
  }

  /// Get human-readable recovery speed classification
  static String getMuscleRecoverySpeed(String muscleGroup) {
    final k = getMuscleRecoveryRate(muscleGroup);
    if (k >= 0.06) return 'Fast (24-36h)';
    if (k >= 0.04) return 'Medium (36-60h)';
    return 'Slow (48-96h)';
  }

  /// Log new muscle group for analytics
  static void _logNewMuscleGroup(String muscleGroup) {
    print('📊 New muscle group detected: $muscleGroup (Recovery rate: ${getMuscleRecoverySpeed(muscleGroup)})');
    // TODO: Add analytics event here if needed
  }

  // ============================================
  // FATIGUE DECAY CALCULATION
  // ============================================

  /// Apply exponential decay to fatigue based on time elapsed
  /// fatigue(t) = fatigue0 × exp(-k × hours)
  static double _applyDecay(double currentFatigue, String muscleGroup, int hoursSinceUpdate) {
    if (hoursSinceUpdate <= 0) return currentFatigue;
    
    final k = getMuscleRecoveryRate(muscleGroup);
    final decayedFatigue = currentFatigue * math.exp(-k * hoursSinceUpdate);
    
    return math.max(0.0, decayedFatigue);
  }

  /// Calculate current fatigue with decay applied
  static double getCurrentFatigue(MuscleRecovery recovery) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceUpdate = ((now - recovery.lastUpdatedAt) / (1000 * 60 * 60));
    return _applyDecay(recovery.fatigue, recovery.muscleGroup, hoursSinceUpdate.floor());
  }

  // ============================================
  // STRAIN CALCULATION
  // ============================================

  /// Calculate strain for a single exercise
  /// Returns map of muscle group -> strain points
  static Map<String, double> _calculateExerciseStrain(WorkoutExerciseLog exercise) {
    final strainMap = <String, double>{};
    
    // Skip excluded muscle groups
    if (exercise.muscleGroup == null || excludedMuscleGroups.contains(exercise.muscleGroup)) {
      return strainMap;
    }

    // Calculate base strain from sets, reps, and weight
    double totalStrain = 0.0;

    for (final set in exercise.sets) {
      if (!set.isCompleted) continue;

      final reps = set.reps ?? 0;
      final weight = set.weight ?? 0;

      if (weight > 0) {
        // Weighted exercise: sets × reps × (weight/10)
        totalStrain += reps * (weight / 10);
      } else if (reps > 0) {
        // Bodyweight with reps: sets × 10
        totalStrain += 10;
      } else {
        // Time-based/holds with no weight or reps: fixed strain per set
        totalStrain += 20;
      }
    }

    if (totalStrain == 0) return strainMap;

    // Split strain for hybrid muscle groups (e.g., "Glutes/Quads")
    final muscleGroups = exercise.muscleGroup!.split('/');
    
    if (muscleGroups.length > 1) {
      // Hybrid muscle: split strain 50/50
      final strainPerMuscle = totalStrain / muscleGroups.length;
      for (final muscle in muscleGroups) {
        final trimmed = muscle.trim();
        if (!excludedMuscleGroups.contains(trimmed)) {
          strainMap[trimmed] = strainPerMuscle;
        }
      }
    } else {
      // Single muscle: apply full strain
      strainMap[exercise.muscleGroup!] = totalStrain;
    }

    return strainMap;
  }

  /// Update recovery tracking after a workout
  Future<void> updateRecoveryAfterWorkout(WorkoutLog workout, String? userId) async {
    // Calculate total strain per muscle group
    final Map<String, double> muscleStrain = {};

    for (final exercise in workout.exercises) {
      final exerciseStrain = _calculateExerciseStrain(exercise);
      for (final entry in exerciseStrain.entries) {
        muscleStrain[entry.key] = (muscleStrain[entry.key] ?? 0) + entry.value;
      }
    }

    if (muscleStrain.isEmpty) return;

    // Load existing recovery data
    final existing = userId != null
        ? await getRecoveryFirestore(userId)
        : await getRecoveryLocal();
    final existingMap = {for (var r in existing) r.muscleGroup: r};

    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedRecoveries = <MuscleRecovery>[];

    // Update each affected muscle
    for (final entry in muscleStrain.entries) {
      final muscleGroup = entry.key;
      final newStrain = entry.value;

      final existing = existingMap[muscleGroup];
      double currentFatigue = 0.0;

      if (existing != null) {
        // Apply decay to existing fatigue
        final hoursSinceUpdate = ((now - existing.lastUpdatedAt) / (1000 * 60 * 60)).floor();
        currentFatigue = _applyDecay(existing.fatigue, muscleGroup, hoursSinceUpdate);

        // Apply consecutive-day penalty if training while not recovered
        final readiness = 100 - currentFatigue;
        if (readiness < 60) {
          print('⚠️ Training $muscleGroup while fatigued (readiness: ${readiness.toStringAsFixed(1)}%) - applying 1.3x penalty');
          currentFatigue *= 1.3;
        }
      } else {
        // New muscle group - log it
        _logNewMuscleGroup(muscleGroup);
      }

      // Add new strain and clamp to 0-100
      final updatedFatigue = (currentFatigue + newStrain).clamp(0.0, 100.0);

      updatedRecoveries.add(MuscleRecovery(
        muscleGroup: muscleGroup,
        fatigue: updatedFatigue,
        lastUpdatedAt: now,
      ));
    }

    // Save to local storage
    await _saveRecoveryLocal(updatedRecoveries);

    // Save to Firestore if authenticated
    if (userId != null) {
      await _saveRecoveryFirestore(userId, updatedRecoveries);
    }
  }

  // ============================================
  // LOCAL STORAGE
  // ============================================

  Future<String> _getRecoveryFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_recoveryFileName';
  }

  Future<void> _saveRecoveryLocal(List<MuscleRecovery> recoveries) async {
    try {
      // Load existing recovery data
      final existing = await getRecoveryLocal();
      final Map<String, MuscleRecovery> recoveryMap = {
        for (var r in existing) r.muscleGroup: r,
      };

      // Update with new data
      for (final recovery in recoveries) {
        recoveryMap[recovery.muscleGroup] = recovery;
      }

      // Save to file
      final file = File(await _getRecoveryFilePath());
      final jsonList = recoveryMap.values.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving recovery data locally: $e');
    }
  }

  Future<List<MuscleRecovery>> getRecoveryLocal() async {
    try {
      final file = File(await _getRecoveryFilePath());
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final recoveries = jsonList.map((json) => MuscleRecovery.fromJson(json)).toList();
      
      // Check if migration is needed (old schema detected)
      await _migrateRecoveriesIfNeeded(recoveries, null);
      
      return recoveries;
    } catch (e) {
      print('Error reading recovery data: $e');
      return [];
    }
  }

  // ============================================
  // DATA MIGRATION
  // ============================================

  /// Migrate old recovery data to new schema if needed
  Future<void> _migrateRecoveriesIfNeeded(List<MuscleRecovery> recoveries, String? userId) async {
    bool needsMigration = false;
    final migratedRecoveries = <MuscleRecovery>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final recovery in recoveries) {
      // Check if this is old schema (has lastTrainedDate)
      if (recovery.lastTrainedDate != null) {
        needsMigration = true;
        
        // Calculate hours elapsed since last trained
        final hoursSinceLastTrained = DateTime.now().difference(recovery.lastTrainedDate!).inHours;
        
        // Apply medium strain (35 points) decayed over time
        const initialFatigue = 35.0;
        final k = getMuscleRecoveryRate(recovery.muscleGroup);
        final currentFatigue = initialFatigue * math.exp(-k * hoursSinceLastTrained);
        
        print('🔄 Migrating ${recovery.muscleGroup}: ${hoursSinceLastTrained}h since last trained → ${currentFatigue.toStringAsFixed(1)} fatigue');
        
        migratedRecoveries.add(MuscleRecovery(
          muscleGroup: recovery.muscleGroup,
          fatigue: currentFatigue.clamp(0.0, 100.0),
          lastUpdatedAt: now,
        ));
      } else {
        migratedRecoveries.add(recovery);
      }
    }

    // Save migrated data if needed
    if (needsMigration) {
      print('📝 Migration complete: ${migratedRecoveries.length} muscles updated');
      await _saveRecoveryLocal(migratedRecoveries);
      if (userId != null) {
        await _saveRecoveryFirestore(userId, migratedRecoveries);
      }
    }
  }

  // ============================================
  // FIRESTORE OPERATIONS
  // ============================================

  Future<void> _saveRecoveryFirestore(String userId, List<MuscleRecovery> recoveries) async {
    try {
      final batch = _firestore.batch();

      for (final recovery in recoveries) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('muscle_recovery')
            .doc(sanitizeMuscleGroupId(recovery.muscleGroup));
        batch.set(docRef, recovery.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error saving recovery to Firestore: $e');
    }
  }

  Future<List<MuscleRecovery>> getRecoveryFirestore(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('muscle_recovery')
          .get();

      final recoveries = snapshot.docs
          .map((doc) => MuscleRecovery.fromFirestore(doc.data()))
          .toList();
      
      // Check if migration is needed
      await _migrateRecoveriesIfNeeded(recoveries, userId);
      
      return recoveries;
    } catch (e) {
      print('Error fetching recovery from Firestore: $e');
      return [];
    }
  }

  Stream<List<MuscleRecovery>> getRecoveryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('muscle_recovery')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MuscleRecovery.fromFirestore(doc.data()))
            .toList());
  }

  // ============================================
  // SMART QUERIES
  // ============================================

  /// Get recovery status for specific muscle group
  Future<MuscleRecovery?> getRecoveryForMuscle(String muscleGroup, String? userId) async {
    // Try Firestore first if authenticated
    if (userId != null) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('muscle_recovery')
            .doc(sanitizeMuscleGroupId(muscleGroup))
            .get();

        if (doc.exists && doc.data() != null) {
          return MuscleRecovery.fromFirestore(doc.data()!);
        }
      } catch (e) {
        print('Error fetching muscle recovery from Firestore: $e');
      }
    }

    // Fallback to local storage
    final localRecoveries = await getRecoveryLocal();
    return localRecoveries.cast<MuscleRecovery?>().firstWhere(
          (r) => r?.muscleGroup == muscleGroup,
          orElse: () => null,
        );
  }

  /// Get all muscle groups that should show warnings (readiness < 60)
  Future<List<MuscleRecovery>> getFatiguedMuscles(String? userId) async {
    final recoveries = userId != null
        ? await getRecoveryFirestore(userId)
        : await getRecoveryLocal();

    // Apply decay and filter by readiness
    return recoveries.where((r) {
      final currentFatigue = getCurrentFatigue(r);
      return (100 - currentFatigue) < 60;
    }).toList();
  }

  /// Get recommended muscle groups to train (readiness >= 80)
  Future<List<String>> getRecommendedMuscles(String? userId) async {
    final recoveries = userId != null
        ? await getRecoveryFirestore(userId)
        : await getRecoveryLocal();

    final recovered = recoveries
        .where((r) {
          final currentFatigue = getCurrentFatigue(r);
          return (100 - currentFatigue) >= 80;
        })
        .map((r) => r.muscleGroup)
        .toList();

    return recovered;
  }

  /// Check if user should be warned about training a specific muscle
  Future<bool> shouldWarnForMuscle(String muscleGroup, String? userId) async {
    final recovery = await getRecoveryForMuscle(muscleGroup, userId);
    if (recovery == null) return false;
    
    final currentFatigue = getCurrentFatigue(recovery);
    return (100 - currentFatigue) < 60;
  }

  /// Get recovery summary for dashboard
  Future<Map<String, dynamic>> getRecoverySummary(String? userId) async {
    final recoveries = userId != null
        ? await getRecoveryFirestore(userId)
        : await getRecoveryLocal();

    int recovered = 0;
    int recovering = 0;
    int fatigued = 0;

    for (final recovery in recoveries) {
      final currentFatigue = getCurrentFatigue(recovery);
      final readiness = 100 - currentFatigue;

      if (readiness >= 80) {
        recovered++;
      } else if (readiness >= 60) {
        recovering++;
      } else {
        fatigued++;
      }
    }

    return {
      'total': recoveries.length,
      'recovered': recovered,
      'recovering': recovering,
      'fatigued': fatigued,
      'recoveries': recoveries,
    };
  }
}
