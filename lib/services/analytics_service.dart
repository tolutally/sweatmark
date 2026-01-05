import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_model.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';

/// Service for computing and storing analytics aggregates
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get analytics summary for a time window
  Future<AnalyticsSummary> getAnalyticsSummary(
    String userId,
    AnalyticsWindow window,
  ) async {
    final dailyStats = await _getDailyStats(userId, window.days);

    // Calculate totals from daily stats
    int workouts = 0;
    int totalVolume = 0;
    int totalTimeMinutes = 0;
    int totalSets = 0;
    int totalReps = 0;
    final muscleCount = <String, int>{};
    int daysWithWorkouts = 0;

    for (final day in dailyStats) {
      workouts += day.workouts;
      totalVolume += day.volume;
      totalTimeMinutes += day.timeMinutes;
      totalSets += day.sets;
      totalReps += day.reps;

      if (day.workouts > 0) daysWithWorkouts++;

      for (final muscle in day.muscleGroups) {
        muscleCount[muscle] = (muscleCount[muscle] ?? 0) + 1;
      }
    }

    // Consistency = % of days with workouts
    final consistencyPercent =
        window.days > 0 ? (daysWithWorkouts / window.days) * 100 : 0.0;

    // Get all-time totals
    final allTimeTotals = await _getAllTimeTotals(userId);

    // Get PR data
    final prData = await _getPRData(userId);

    // Get muscle distribution
    final muscleDistribution = MuscleDistribution.fromMap(muscleCount);

    return AnalyticsSummary(
      workouts: workouts,
      totalVolume: totalVolume,
      totalTimeMinutes: totalTimeMinutes,
      totalSets: totalSets,
      totalReps: totalReps,
      consistencyPercent: consistencyPercent,
      allTimeWorkouts: allTimeTotals['workouts'] ?? 0,
      allTimeVolume: allTimeTotals['volume'] ?? 0,
      tier: SweatTier.fromStats(
        allTimeTotals['workouts'] ?? 0,
        allTimeTotals['volume'] ?? 0,
      ),
      prCountThisMonth: prData['count'] ?? 0,
      recentPRs: prData['recent'] ?? [],
      muscleDistribution: muscleDistribution,
      dailyStats: dailyStats,
    );
  }

  /// Get daily stats for past N days
  Future<List<DailyStats>> _getDailyStats(String userId, int days) async {
    final now = DateTime.now();
    final stats = <DailyStats>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('daily')
          .collection('stats')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        stats.add(DailyStats.fromFirestore(doc));
      } else {
        // Check if there's volume data from FlameService
        final volumeDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('analytics')
            .doc('daily')
            .collection('volume')
            .doc(dateStr)
            .get();

        if (volumeDoc.exists) {
          stats.add(DailyStats(
            date: dateStr,
            volume: volumeDoc.data()?['volume'] ?? 0,
            workouts: 1, // Assume at least 1 workout if volume exists
          ));
        } else {
          stats.add(DailyStats(date: dateStr));
        }
      }
    }

    return stats;
  }

  /// Get all-time totals from summary doc
  Future<Map<String, int>> _getAllTimeTotals(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('summary')
        .get();

    if (!doc.exists) {
      // Compute from workout history
      return await _computeAllTimeTotals(userId);
    }

    final data = doc.data() ?? {};
    return {
      'workouts': data['allTimeWorkouts'] ?? 0,
      'volume': data['allTimeVolume'] ?? 0,
    };
  }

  /// Compute all-time totals from workout history
  Future<Map<String, int>> _computeAllTimeTotals(String userId) async {
    final workoutsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .get();

    int totalWorkouts = workoutsSnap.docs.length;
    int totalVolume = 0;

    for (final doc in workoutsSnap.docs) {
      final data = doc.data();
      // Try to get pre-computed volume, or calculate
      if (data['totalVolume'] != null) {
        totalVolume += (data['totalVolume'] as num).toInt();
      } else {
        // Calculate from exercises
        final exercises = data['exercises'] as List<dynamic>? ?? [];
        for (final ex in exercises) {
          final sets = ex['sets'] as List<dynamic>? ?? [];
          for (final set in sets) {
            if (set['isCompleted'] == true) {
              final weight = (set['weight'] as num?)?.toDouble() ?? 0;
              final reps = (set['reps'] as num?)?.toInt() ?? 0;
              if (weight > 0) {
                totalVolume += (weight * reps).round();
              } else if (reps > 0) {
                totalVolume += reps;
              }
            }
          }
        }
      }
    }

    // Save to summary
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('summary')
        .set({
      'allTimeWorkouts': totalWorkouts,
      'allTimeVolume': totalVolume,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return {
      'workouts': totalWorkouts,
      'volume': totalVolume,
    };
  }

  /// Get PR data for current month
  Future<Map<String, dynamic>> _getPRData(String userId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final prsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personalRecords')
        .orderBy('achievedAt', descending: true)
        .limit(10)
        .get();

    final recentPRs = <PRRecord>[];
    int countThisMonth = 0;

    for (final doc in prsSnap.docs) {
      final data = doc.data();
      final achievedAt =
          (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      if (achievedAt.isAfter(monthStart)) {
        countThisMonth++;
      }

      recentPRs.add(PRRecord(
        exerciseId: data['exerciseId'] ?? doc.id,
        exerciseName: data['exerciseName'] ?? '',
        muscleGroup: data['muscleGroup'] ?? '',
        value: (data['value'] as num?)?.toDouble() ?? 0,
        unit: data['unit'] ?? 'lb',
        achievedAt: achievedAt,
        isNew: achievedAt.isAfter(monthStart),
      ));
    }

    return {
      'count': countThisMonth,
      'recent': recentPRs.take(5).toList(),
    };
  }

  /// Record workout stats (called after workout completion)
  Future<void> recordWorkoutStats(
    String userId,
    WorkoutLog workout,
  ) async {
    final dateStr = _formatDate(workout.timestamp);

    // Calculate workout metrics
    int volume = 0;
    int sets = 0;
    int reps = 0;
    final muscleGroups = <String>{};

    for (final exercise in workout.exercises) {
      // Get muscle group from exercise library
      final exerciseData = EXERCISE_LIBRARY.firstWhere(
        (e) => e['id'] == exercise.exerciseId,
        orElse: () => {'muscleGroup': 'Other'},
      );
      muscleGroups.add(exerciseData['muscleGroup'] ?? 'Other');

      for (final set in exercise.sets) {
        if (!set.isCompleted) continue;
        sets++;

        final setReps = set.reps ?? 0;
        final weight = set.weight ?? 0;
        reps += setReps;

        if (weight > 0) {
          volume += (weight * setReps).round();
        } else if (setReps > 0) {
          volume += setReps;
        }
      }
    }

    final timeMinutes = workout.durationSeconds ~/ 60;

    // Get existing daily stats
    final dailyRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('daily')
        .collection('stats')
        .doc(dateStr);

    final existingDoc = await dailyRef.get();
    final existing =
        existingDoc.exists ? DailyStats.fromFirestore(existingDoc) : null;

    // Merge with existing
    final newStats = DailyStats(
      date: dateStr,
      workouts: (existing?.workouts ?? 0) + 1,
      volume: (existing?.volume ?? 0) + volume,
      timeMinutes: (existing?.timeMinutes ?? 0) + timeMinutes,
      sets: (existing?.sets ?? 0) + sets,
      reps: (existing?.reps ?? 0) + reps,
      muscleGroups: {...(existing?.muscleGroups ?? []), ...muscleGroups}.toList(),
    );

    // Write daily stats
    await dailyRef.set(newStats.toFirestore());

    // Update all-time totals
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('summary')
        .set({
      'allTimeWorkouts': FieldValue.increment(1),
      'allTimeVolume': FieldValue.increment(volume),
      'lastWorkoutDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get muscle group for an exercise
  String getMuscleGroup(String exerciseId, String? exerciseName) {
    // First try by ID
    final byId = EXERCISE_LIBRARY.firstWhere(
      (e) => e['id'] == exerciseId,
      orElse: () => <String, dynamic>{},
    );
    if (byId.isNotEmpty) return byId['muscleGroup'] ?? 'Other';

    // Then try by name
    if (exerciseName != null) {
      final byName = EXERCISE_LIBRARY.firstWhere(
        (e) =>
            (e['name'] as String).toLowerCase() == exerciseName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (byName.isNotEmpty) return byName['muscleGroup'] ?? 'Other';
    }

    return 'Other';
  }

  /// Stream analytics summary (for real-time updates)
  Stream<AnalyticsSummary?> watchAnalyticsSummary(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('summary')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return AnalyticsSummary.fromFirestore(doc);
    });
  }

  /// Migrate historical workouts to analytics
  Future<void> migrateHistoricalData(String userId) async {
    // Check if already migrated
    final summaryDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('summary')
        .get();

    if (summaryDoc.exists && summaryDoc.data()?['migrated'] == true) {
      return; // Already migrated
    }

    // Get all workouts
    final workoutsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .orderBy('timestamp')
        .get();

    if (workoutsSnap.docs.isEmpty) return;

    int allTimeWorkouts = 0;
    int allTimeVolume = 0;
    final dailyStatsMap = <String, DailyStats>{};

    for (final doc in workoutsSnap.docs) {
      final data = doc.data();
      final timestamp =
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final dateStr = _formatDate(timestamp);

      int volume = 0;
      int sets = 0;
      int reps = 0;
      final muscleGroups = <String>{};
      final timeMinutes = ((data['durationSeconds'] as num?) ?? 0) ~/ 60;

      final exercises = data['exercises'] as List<dynamic>? ?? [];
      for (final ex in exercises) {
        final exerciseId = ex['exerciseId'] ?? '';
        final exerciseName = ex['exerciseName'];
        muscleGroups.add(getMuscleGroup(exerciseId, exerciseName));

        final exSets = ex['sets'] as List<dynamic>? ?? [];
        for (final set in exSets) {
          if (set['isCompleted'] == true) {
            sets++;
            final setReps = (set['reps'] as num?)?.toInt() ?? 0;
            final weight = (set['weight'] as num?)?.toDouble() ?? 0;
            reps += setReps;

            if (weight > 0) {
              volume += (weight * setReps).round();
            } else if (setReps > 0) {
              volume += setReps;
            }
          }
        }
      }

      allTimeWorkouts++;
      allTimeVolume += volume;

      // Aggregate into daily stats
      final existing = dailyStatsMap[dateStr];
      dailyStatsMap[dateStr] = DailyStats(
        date: dateStr,
        workouts: (existing?.workouts ?? 0) + 1,
        volume: (existing?.volume ?? 0) + volume,
        timeMinutes: (existing?.timeMinutes ?? 0) + timeMinutes,
        sets: (existing?.sets ?? 0) + sets,
        reps: (existing?.reps ?? 0) + reps,
        muscleGroups:
            {...(existing?.muscleGroups ?? []), ...muscleGroups}.toList(),
      );
    }

    // Write daily stats in batches
    final batch = _firestore.batch();
    int batchCount = 0;

    for (final entry in dailyStatsMap.entries) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('daily')
          .collection('stats')
          .doc(entry.key);

      batch.set(ref, entry.value.toFirestore());
      batchCount++;

      // Firestore batch limit is 500
      if (batchCount >= 450) {
        await batch.commit();
        batchCount = 0;
      }
    }

    // Write summary
    batch.set(
      _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('summary'),
      {
        'allTimeWorkouts': allTimeWorkouts,
        'allTimeVolume': allTimeVolume,
        'tier': SweatTier.fromStats(allTimeWorkouts, allTimeVolume).name,
        'migrated': true,
        'migratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    print(
        'Analytics: Migrated $allTimeWorkouts workouts, ${dailyStatsMap.length} days');
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
