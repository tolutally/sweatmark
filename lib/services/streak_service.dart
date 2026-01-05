import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/streak_model.dart';

/// Service for managing workout streaks (read-only from client side)
/// Streak updates are handled server-side via Cloud Functions
class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current streak data for a user
  /// Returns null if no streak exists yet
  Future<StreakModel?> getCurrentStreak(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('streak')
          .doc('data')
          .get();

      if (!doc.exists) {
        return null;
      }

      return StreakModel.fromFirestore(doc);
    } catch (e) {
      print('Error fetching streak: $e');
      return null;
    }
  }

  /// Stream of streak data for real-time updates
  Stream<StreakModel?> streakStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('streak')
        .doc('data')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return StreakModel.fromFirestore(doc);
    });
  }

  /// Update streak settings (type, weekly goal, scheduled days)
  /// Note: Changing type may reset current streak
  Future<void> updateStreakSettings({
    required String userId,
    StreakType? type,
    int? weeklyGoal,
    List<int>? scheduledDays,
    String? timezone,
  }) async {
    try {
      final streakRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('streak')
          .doc('data');

      final doc = await streakRef.get();

      if (!doc.exists) {
        // Initialize new streak with settings
        final newStreak = StreakModel(
          current: 0,
          best: 0,
          timezone: timezone ?? 'UTC',
          type: type ?? StreakType.daily,
          weeklyGoal: weeklyGoal ?? 3,
          scheduledDays: scheduledDays ?? [],
        );

        await streakRef.set(newStreak.toFirestore());
      } else {
        // Update existing streak settings
        final updates = <String, dynamic>{
          'updatedAt': Timestamp.now(),
        };

        if (type != null) {
          updates['type'] = type.toString().split('.').last;
          // Reset streak when changing type
          updates['current'] = 0;
          updates['lastCompletedLocalDate'] = null;
          updates['graceDeadline'] = null;
        }

        if (weeklyGoal != null) {
          updates['weeklyGoal'] = weeklyGoal;
        }

        if (scheduledDays != null) {
          updates['scheduledDays'] = scheduledDays;
        }

        if (timezone != null) {
          updates['timezone'] = timezone;
        }

        await streakRef.update(updates);
      }
    } catch (e) {
      print('Error updating streak settings: $e');
      rethrow;
    }
  }

  /// Get all streak achievements for a user
  Future<List<Map<String, dynamic>>> getStreakAchievements(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .where('type', isEqualTo: 'streak')
          .orderBy('milestone', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'milestone': data['milestone'] as int,
          'achievedAt': (data['achievedAt'] as Timestamp).toDate(),
          'badge': _getBadgeForMilestone(data['milestone'] as int),
        };
      }).toList();
    } catch (e) {
      print('Error fetching achievements: $e');
      return [];
    }
  }

  /// Get badge emoji for a milestone
  String _getBadgeForMilestone(int milestone) {
    switch (milestone) {
      case 7:
        return '🥉'; // Bronze - 7 days
      case 30:
        return '🥈'; // Silver - 30 days
      case 100:
        return '🥇'; // Gold - 100 days
      case 365:
        return '💎'; // Diamond - 365 days
      default:
        return '⭐';
    }
  }

  /// Check if streak was broken and clear the flag
  /// Call this after showing "streak broken" modal
  Future<void> acknowledgeStreakBroken(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('streak')
          .doc('data')
          .update({
        'wasStreakBroken': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error acknowledging streak broken: $e');
    }
  }

  /// Initialize streak for new user
  Future<void> initializeStreak(String userId, String timezone) async {
    try {
      final streakRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('streak')
          .doc('data');

      final doc = await streakRef.get();
      if (doc.exists) {
        return; // Already initialized
      }

      final initialStreak = StreakModel(
        current: 0,
        best: 0,
        timezone: timezone,
        type: StreakType.daily,
        weeklyGoal: 3,
        scheduledDays: [],
      );

      await streakRef.set(initialStreak.toFirestore());
    } catch (e) {
      print('Error initializing streak: $e');
    }
  }

  /// Get formatted time until deadline
  String getDeadlineText(StreakModel streak) {
    final hours = streak.hoursUntilDeadline();
    if (hours == null) return 'No active streak';

    if (hours <= 0) {
      return 'Deadline passed';
    } else if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes min left';
    } else if (hours < 24) {
      return '${hours.toStringAsFixed(1)}h left';
    } else {
      final days = (hours / 24).floor();
      return '$days day${days > 1 ? 's' : ''} left';
    }
  }

  /// Get urgency level for UI styling
  /// Returns: 'critical' (0-1hr), 'warning' (1-6hr), 'normal' (6+hr)
  String getUrgencyLevel(StreakModel streak) {
    final hours = streak.hoursUntilDeadline();
    if (hours == null || hours <= 0) return 'expired';
    if (hours <= 1) return 'critical';
    if (hours <= 6) return 'warning';
    return 'normal';
  }
}
