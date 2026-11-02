import 'package:cloud_firestore/cloud_firestore.dart';

/// Flame levels with volume thresholds (7-day rolling)
enum FlameLevel {
  spark(0, '🔥', 'Spark'),
  ember(5000, '🔥', 'Ember'),
  blaze(15000, '🔥', 'Blaze'),
  inferno(35000, '🔥', 'Inferno'),
  furnace(70000, '🔥', 'Furnace'),
  nova(120000, '🔥', 'Nova'),
  supernova(200000, '🔥', 'Supernova');

  final int threshold;
  final String emoji;
  final String label;

  const FlameLevel(this.threshold, this.emoji, this.label);

  static FlameLevel fromVolume(int volume) {
    for (int i = FlameLevel.values.length - 1; i >= 0; i--) {
      if (volume >= FlameLevel.values[i].threshold) {
        return FlameLevel.values[i];
      }
    }
    return FlameLevel.spark;
  }

  FlameLevel? get nextLevel {
    final idx = FlameLevel.values.indexOf(this);
    if (idx < FlameLevel.values.length - 1) {
      return FlameLevel.values[idx + 1];
    }
    return null;
  }

  double progressToNext(int currentVolume) {
    final next = nextLevel;
    if (next == null) return 1.0;
    final range = next.threshold - threshold;
    final progress = currentVolume - threshold;
    return (progress / range).clamp(0.0, 1.0);
  }
}

/// Daily volume record for a single day
class DailyVolume {
  final String date; // yyyy-MM-dd
  final int volume;
  final DateTime updatedAt;

  DailyVolume({
    required this.date,
    required this.volume,
    required this.updatedAt,
  });

  factory DailyVolume.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyVolume(
      date: doc.id,
      volume: data['volume'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'volume': volume,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

/// Main flame stats model
class FlameStats {
  final int peak7d; // All-time peak 7-day rolling volume (never decreases)
  final int current7d; // Current 7-day rolling volume
  final int todayVolume; // Today's volume
  final FlameLevel level; // Current flame level based on peak7d
  final DateTime? lastPeakDate; // When peak was last updated
  final DateTime? lastWorkoutDate;
  final bool isNewPeak; // Flag for animation trigger
  final FlameLevel? previousLevel; // For level-up detection

  FlameStats({
    required this.peak7d,
    required this.current7d,
    required this.todayVolume,
    required this.level,
    this.lastPeakDate,
    this.lastWorkoutDate,
    this.isNewPeak = false,
    this.previousLevel,
  });

  factory FlameStats.empty() => FlameStats(
        peak7d: 0,
        current7d: 0,
        todayVolume: 0,
        level: FlameLevel.spark,
      );

  factory FlameStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final peak = data['peak7d'] ?? 0;
    return FlameStats(
      peak7d: peak,
      current7d: data['current7d'] ?? 0,
      todayVolume: data['todayVolume'] ?? 0,
      level: FlameLevel.fromVolume(peak),
      lastPeakDate: (data['lastPeakDate'] as Timestamp?)?.toDate(),
      lastWorkoutDate: (data['lastWorkoutDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'peak7d': peak7d,
        'current7d': current7d,
        'todayVolume': todayVolume,
        'level': level.name,
        if (lastPeakDate != null)
          'lastPeakDate': Timestamp.fromDate(lastPeakDate!),
        if (lastWorkoutDate != null)
          'lastWorkoutDate': Timestamp.fromDate(lastWorkoutDate!),
      };

  FlameStats copyWith({
    int? peak7d,
    int? current7d,
    int? todayVolume,
    FlameLevel? level,
    DateTime? lastPeakDate,
    DateTime? lastWorkoutDate,
    bool? isNewPeak,
    FlameLevel? previousLevel,
  }) =>
      FlameStats(
        peak7d: peak7d ?? this.peak7d,
        current7d: current7d ?? this.current7d,
        todayVolume: todayVolume ?? this.todayVolume,
        level: level ?? this.level,
        lastPeakDate: lastPeakDate ?? this.lastPeakDate,
        lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
        isNewPeak: isNewPeak ?? this.isNewPeak,
        previousLevel: previousLevel ?? this.previousLevel,
      );

  bool get leveledUp => previousLevel != null && previousLevel != level;
}
