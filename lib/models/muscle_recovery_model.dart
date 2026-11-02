import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_model.dart';

class MuscleRecovery {
  final String muscleGroup;
  final double fatigue; // 0-100 (0 = fully recovered, 100 = maximum fatigue)
  final int lastUpdatedAt; // Unix timestamp in milliseconds

  // Legacy field for migration (will be null for new data)
  final DateTime? lastTrainedDate;

  MuscleRecovery({
    required this.muscleGroup,
    required this.fatigue,
    required this.lastUpdatedAt,
    this.lastTrainedDate,
  });

  /// Get current readiness score (0-100, higher is better)
  double get readiness => 100 - fatigue;

  /// Check if muscle is fully recovered (readiness >= 80)
  bool get isFullyRecovered => readiness >= 80;

  /// Check if warning should be shown (readiness < 60)
  bool get shouldWarn => readiness < 60;

  /// Calculate current status based on readiness
  MuscleStatus get status {
    if (readiness >= 80) return MuscleStatus.recovered;
    if (readiness >= 60) return MuscleStatus.recovering;
    return MuscleStatus.fatigued;
  }

  /// Calculate hours since last update
  int get hoursSinceLastUpdate {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((now - lastUpdatedAt) / (1000 * 60 * 60)).floor();
  }

  /// Get human-readable time since last trained
  String get timeSinceLastTrained {
    final hours = hoursSinceLastUpdate;
    if (hours < 1) return 'Just now';
    if (hours < 24) return '$hours hours ago';
    final days = (hours / 24).floor();
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  /// Get color for recovery status
  String get statusColor {
    if (readiness >= 80) return '#10B981'; // Green
    if (readiness >= 60) return '#F59E0B'; // Amber
    return '#EF4444'; // Red
  }

  /// Get emoji for status
  String get statusEmoji {
    if (readiness >= 80) return '💪';
    if (readiness >= 60) return '⏳';
    return '😓';
  }

  /// Get display name for status
  String get statusName {
    if (readiness >= 80) return 'Recovered';
    if (readiness >= 60) return 'Recovering';
    return 'Fatigued';
  }

  Map<String, dynamic> toJson() => {
        'muscleGroup': muscleGroup,
        'fatigue': fatigue,
        'lastUpdatedAt': lastUpdatedAt,
      };

  factory MuscleRecovery.fromJson(Map<String, dynamic> json) {
    // Check for old schema (migration needed)
    if (json.containsKey('lastTrainedDate') && !json.containsKey('fatigue')) {
      // Old schema - will be migrated by recovery service
      final lastTrained = DateTime.parse(json['lastTrainedDate'] as String);
      return MuscleRecovery(
        muscleGroup: json['muscleGroup'] as String,
        fatigue: 35.0, // Default medium strain
        lastUpdatedAt: lastTrained.millisecondsSinceEpoch,
        lastTrainedDate: lastTrained,
      );
    }

    // New schema
    return MuscleRecovery(
      muscleGroup: json['muscleGroup'] as String,
      fatigue: (json['fatigue'] as num?)?.toDouble() ?? 0.0,
      lastUpdatedAt: json['lastUpdatedAt'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'muscleGroup': muscleGroup,
        'fatigue': fatigue,
        'lastUpdatedAt': lastUpdatedAt,
      };

  static MuscleRecovery fromFirestore(Map<String, dynamic> data) {
    // Check for old schema (migration needed)
    if (data.containsKey('lastTrainedDate') && !data.containsKey('fatigue')) {
      final timestamp = data['lastTrainedDate'];
      final lastTrained = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(data['lastTrainedDate'] as String);

      return MuscleRecovery(
        muscleGroup: data['muscleGroup'] as String,
        fatigue: 35.0, // Default medium strain
        lastUpdatedAt: lastTrained.millisecondsSinceEpoch,
        lastTrainedDate: lastTrained,
      );
    }

    // New schema
    return MuscleRecovery(
      muscleGroup: data['muscleGroup'] as String,
      fatigue: (data['fatigue'] as num?)?.toDouble() ?? 0.0,
      lastUpdatedAt: data['lastUpdatedAt'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  MuscleRecovery copyWith({
    String? muscleGroup,
    double? fatigue,
    int? lastUpdatedAt,
  }) {
    return MuscleRecovery(
      muscleGroup: muscleGroup ?? this.muscleGroup,
      fatigue: fatigue ?? this.fatigue,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
