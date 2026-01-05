import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines the type of streak tracking
enum StreakType {
  daily,    // Must complete 1 workout per day
  weekly,   // Must complete X workouts per week (Mon-Sun)
  custom,   // Must complete workouts on specific days of week
}

/// Model for tracking workout streaks with grace period support
class StreakModel {
  final int current;            // Current active streak count
  final int best;               // All-time best streak
  final String? lastCompletedLocalDate;  // Last workout date in YYYY-MM-DD format (local timezone)
  final String timezone;        // User's timezone (e.g., 'America/Los_Angeles')
  final StreakType type;        // Type of streak tracking
  final int weeklyGoal;         // Number of workouts per week (for weekly type)
  final int currentWeekWorkouts; // Workouts completed this week
  final String? weekStartDate;  // Start of current week (YYYY-MM-DD, Monday)
  final List<int> scheduledDays; // Days of week for custom type (1=Mon, 7=Sun)
  final DateTime? graceDeadline; // Extended deadline with 6-hour grace period
  final bool wasStreakBroken;   // Flag to show "streak broken" modal
  final DateTime createdAt;
  final DateTime updatedAt;

  StreakModel({
    required this.current,
    required this.best,
    this.lastCompletedLocalDate,
    required this.timezone,
    this.type = StreakType.daily,
    this.weeklyGoal = 3,
    this.currentWeekWorkouts = 0,
    this.weekStartDate,
    this.scheduledDays = const [],
    this.graceDeadline,
    this.wasStreakBroken = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calculate hours remaining until grace deadline
  /// Returns null if no deadline exists
  double? hoursUntilDeadline() {
    if (graceDeadline == null) return null;
    
    final now = DateTime.now();
    final difference = graceDeadline!.difference(now);
    
    return difference.inMinutes / 60.0;
  }

  /// Check if streak is in danger (less than 6 hours until deadline)
  bool get isInDanger {
    final hours = hoursUntilDeadline();
    return hours != null && hours > 0 && hours <= 6;
  }

  /// Check if grace period has expired
  bool get isExpired {
    final hours = hoursUntilDeadline();
    return hours != null && hours <= 0;
  }

  /// Factory constructor from Firestore document
  factory StreakModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return StreakModel(
      current: data['current'] ?? 0,
      best: data['best'] ?? 0,
      lastCompletedLocalDate: data['lastCompletedLocalDate'],
      timezone: data['timezone'] ?? 'UTC',
      type: StreakType.values.firstWhere(
        (e) => e.toString() == 'StreakType.${data['type']}',
        orElse: () => StreakType.daily,
      ),
      weeklyGoal: data['weeklyGoal'] ?? 3,
      currentWeekWorkouts: data['currentWeekWorkouts'] ?? 0,
      weekStartDate: data['weekStartDate'],
      scheduledDays: (data['scheduledDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      graceDeadline: data['graceDeadline'] != null
          ? (data['graceDeadline'] as Timestamp).toDate()
          : null,
      wasStreakBroken: data['wasStreakBroken'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'current': current,
      'best': best,
      'lastCompletedLocalDate': lastCompletedLocalDate,
      'timezone': timezone,
      'type': type.toString().split('.').last,
      'weeklyGoal': weeklyGoal,
      'currentWeekWorkouts': currentWeekWorkouts,
      'weekStartDate': weekStartDate,
      'scheduledDays': scheduledDays,
      'graceDeadline': graceDeadline != null 
          ? Timestamp.fromDate(graceDeadline!)
          : null,
      'wasStreakBroken': wasStreakBroken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  StreakModel copyWith({
    int? current,
    int? best,
    String? lastCompletedLocalDate,
    String? timezone,
    StreakType? type,
    int? weeklyGoal,
    int? currentWeekWorkouts,
    String? weekStartDate,
    List<int>? scheduledDays,
    DateTime? graceDeadline,
    bool? wasStreakBroken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StreakModel(
      current: current ?? this.current,
      best: best ?? this.best,
      lastCompletedLocalDate: lastCompletedLocalDate ?? this.lastCompletedLocalDate,
      timezone: timezone ?? this.timezone,
      type: type ?? this.type,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      currentWeekWorkouts: currentWeekWorkouts ?? this.currentWeekWorkouts,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      graceDeadline: graceDeadline ?? this.graceDeadline,
      wasStreakBroken: wasStreakBroken ?? this.wasStreakBroken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get user-friendly streak type name
  String get typeName {
    switch (type) {
      case StreakType.daily:
        return 'Daily';
      case StreakType.weekly:
        return 'Weekly';
      case StreakType.custom:
        return 'Custom';
    }
  }

  /// Get description of current streak goal
  String get goalDescription {
    switch (type) {
      case StreakType.daily:
        return 'Complete 1 workout per day';
      case StreakType.weekly:
        return 'Complete $weeklyGoal workouts per week';
      case StreakType.custom:
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = scheduledDays.map((d) => dayNames[d - 1]).join(', ');
        return 'Workout on $days';
    }
  }
}
