import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/flame_model.dart';
import '../models/workout_model.dart';

/// Service for managing Flame (7-day peak volume tracker)
class FlameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate total volume for a workout (strength exercises only)
  /// Volume = reps × weight (bodyweight exercises: volume = reps)
  int calculateWorkoutVolume(WorkoutLog workout) {
    int totalVolume = 0;

    for (final exercise in workout.exercises) {
      // Skip cardio exercises (those with time/distance/speed but no weight)
      final isCardio = _isCardioExercise(exercise);
      if (isCardio) continue;

      for (final set in exercise.sets) {
        if (!set.isCompleted) continue;

        final reps = set.reps ?? 0;
        final weight = set.weight ?? 0;

        if (weight > 0) {
          // Weighted exercise: reps × weight
          totalVolume += (reps * weight).round();
        } else if (reps > 0) {
          // Bodyweight exercise: just reps
          totalVolume += reps.toInt();
        }
      }
    }

    return totalVolume;
  }

  /// Check if exercise is cardio (time-based without meaningful weight)
  bool _isCardioExercise(WorkoutExerciseLog exercise) {
    final name = (exercise.exerciseName ?? '').toLowerCase();
    final cardioKeywords = [
      'treadmill',
      'run',
      'jog',
      'walk',
      'cycling',
      'bike',
      'elliptical',
      'stairmaster',
      'rowing',
      'cardio',
      'hiit',
    ];
    return cardioKeywords.any((k) => name.contains(k));
  }

  /// Record workout volume and update flame stats
  /// Returns updated FlameStats with isNewPeak and leveledUp flags
  Future<FlameStats> recordWorkoutVolume(
    String userId,
    WorkoutLog workout,
  ) async {
    final volume = calculateWorkoutVolume(workout);
    if (volume == 0) {
      // No strength volume, just return current stats
      final current = await getFlameStats(userId);
      return current ?? FlameStats.empty();
    }

    final today = _formatDate(DateTime.now());
    final flameRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('flame');
    final dailyRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc('daily')
        .collection('volume')
        .doc(today);

    // Get current flame stats first (outside transaction for reading)
    final flameDoc = await flameRef.get();
    final previousStats =
        flameDoc.exists ? FlameStats.fromFirestore(flameDoc) : FlameStats.empty();
    final previousLevel = previousStats.level;

    // Get today's current volume
    final dailyDoc = await dailyRef.get();
    final previousDailyVolume =
        dailyDoc.exists ? (dailyDoc.data()?['volume'] ?? 0) : 0;
    final newDailyVolume = previousDailyVolume + volume;

    // Calculate 7-day rolling volume
    final rolling7d = await _calculate7DayVolume(userId, today, newDailyVolume);

    // Check for new peak (flame never decreases)
    final isNewPeak = rolling7d > previousStats.peak7d;
    final newPeak = isNewPeak ? rolling7d : previousStats.peak7d;
    final newLevel = FlameLevel.fromVolume(newPeak);

    // Write updates
    await dailyRef.set({
      'volume': newDailyVolume,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updates = <String, dynamic>{
      'current7d': rolling7d,
      'todayVolume': newDailyVolume,
      'lastWorkoutDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isNewPeak) {
      updates['peak7d'] = newPeak;
      updates['lastPeakDate'] = FieldValue.serverTimestamp();
      updates['level'] = newLevel.name;
    }

    await flameRef.set(updates, SetOptions(merge: true));

    return FlameStats(
      peak7d: newPeak,
      current7d: rolling7d,
      todayVolume: newDailyVolume,
      level: newLevel,
      lastPeakDate: isNewPeak ? DateTime.now() : previousStats.lastPeakDate,
      lastWorkoutDate: DateTime.now(),
      isNewPeak: isNewPeak,
      previousLevel: previousLevel,
    );
  }

  /// Calculate 7-day rolling volume
  Future<int> _calculate7DayVolume(
    String userId,
    String todayDate,
    int todayVolume,
  ) async {
    final now = DateTime.now();
    int total = todayVolume;

    // Get past 6 days (today is already counted)
    for (int i = 1; i < 7; i++) {
      final date = _formatDate(now.subtract(Duration(days: i)));
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('daily')
          .collection('volume')
          .doc(date)
          .get();

      if (doc.exists) {
        total += (doc.data()?['volume'] ?? 0) as int;
      }
    }

    return total;
  }

  /// Get current flame stats
  Future<FlameStats?> getFlameStats(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('flame')
          .get();

      if (!doc.exists) return null;
      return FlameStats.fromFirestore(doc);
    } catch (e) {
      print('Error fetching flame stats: $e');
      return null;
    }
  }

  /// Stream of flame stats for real-time updates
  Stream<FlameStats?> watchFlameStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('flame')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return FlameStats.fromFirestore(doc);
    });
  }

  /// Get daily volumes for the past 7 days (for chart)
  Future<List<DailyVolume>> getLast7DaysVolume(String userId) async {
    final now = DateTime.now();
    final volumes = <DailyVolume>[];

    for (int i = 6; i >= 0; i--) {
      final date = _formatDate(now.subtract(Duration(days: i)));
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('daily')
          .collection('volume')
          .doc(date)
          .get();

      volumes.add(DailyVolume(
        date: date,
        volume: doc.exists ? (doc.data()?['volume'] ?? 0) : 0,
        updatedAt: doc.exists
            ? ((doc.data()?['updatedAt'] as Timestamp?)?.toDate() ??
                DateTime.now())
            : DateTime.now(),
      ));
    }

    return volumes;
  }

  /// Migrate historical workouts to flame stats (one-time)
  Future<void> migrateHistoricalData(
    String userId,
    List<WorkoutLog> workouts,
  ) async {
    if (workouts.isEmpty) return;

    // Check if already migrated
    final flameDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('flame')
        .get();

    if (flameDoc.exists && (flameDoc.data()?['migrated'] == true)) {
      return; // Already migrated
    }

    // Group workouts by date and calculate daily volumes
    final dailyVolumes = <String, int>{};
    for (final workout in workouts) {
      final date = _formatDate(workout.timestamp);
      final volume = calculateWorkoutVolume(workout);
      dailyVolumes[date] = (dailyVolumes[date] ?? 0) + volume;
    }

    // Write daily volumes to Firestore
    final batch = _firestore.batch();
    for (final entry in dailyVolumes.entries) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('analytics')
          .doc('daily')
          .collection('volume')
          .doc(entry.key);
      batch.set(ref, {
        'volume': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'migrated': true,
      });
    }

    // Calculate peak 7-day rolling volume from historical data
    int peak7d = 0;
    final sortedDates = dailyVolumes.keys.toList()..sort();

    for (int i = 0; i < sortedDates.length; i++) {
      int rolling = 0;
      for (int j = i; j >= 0 && j > i - 7; j--) {
        rolling += dailyVolumes[sortedDates[j]] ?? 0;
      }
      if (rolling > peak7d) peak7d = rolling;
    }

    // Calculate current 7-day volume
    final now = DateTime.now();
    int current7d = 0;
    for (int i = 0; i < 7; i++) {
      final date = _formatDate(now.subtract(Duration(days: i)));
      current7d += dailyVolumes[date] ?? 0;
    }

    // Write flame stats
    final level = FlameLevel.fromVolume(peak7d);
    batch.set(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('stats')
            .doc('flame'),
        {
          'peak7d': peak7d,
          'current7d': current7d,
          'todayVolume': dailyVolumes[_formatDate(now)] ?? 0,
          'level': level.name,
          'migrated': true,
          'migratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await batch.commit();
    print('Flame: Migrated ${workouts.length} workouts, peak7d=$peak7d');
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
