import 'package:cloud_firestore/cloud_firestore.dart';

/// Sweat tier progression system
/// - Starter: Starting out (0 workouts)
/// - Builder: 10+ workouts
/// - Pro: 50+ workouts AND 100K+ total volume
/// - Elite: 200+ workouts AND 500K+ total volume
enum SweatTier {
  starter(0, 0, 'Sweat Starter', '🌱'),
  builder(10, 0, 'Sweat Builder', '💪'),
  pro(50, 100000, 'Sweat Pro', '🔥'),
  elite(200, 500000, 'Sweat Elite', '👑');

  final int workoutsRequired;
  final int volumeRequired;
  final String label;
  final String emoji;

  const SweatTier(
      this.workoutsRequired, this.volumeRequired, this.label, this.emoji);

  static SweatTier fromStats(int totalWorkouts, int totalVolume) {
    if (totalWorkouts >= SweatTier.elite.workoutsRequired &&
        totalVolume >= SweatTier.elite.volumeRequired) {
      return SweatTier.elite;
    }
    if (totalWorkouts >= SweatTier.pro.workoutsRequired &&
        totalVolume >= SweatTier.pro.volumeRequired) {
      return SweatTier.pro;
    }
    if (totalWorkouts >= SweatTier.builder.workoutsRequired) {
      return SweatTier.builder;
    }
    return SweatTier.starter;
  }

  SweatTier? get nextTier {
    final idx = SweatTier.values.indexOf(this);
    if (idx < SweatTier.values.length - 1) {
      return SweatTier.values[idx + 1];
    }
    return null;
  }

  /// Returns progress towards next tier (0.0 - 1.0)
  double progressToNext(int totalWorkouts, int totalVolume) {
    final next = nextTier;
    if (next == null) return 1.0;

    // Calculate workout progress
    final workoutProgress = next.workoutsRequired > workoutsRequired
        ? ((totalWorkouts - workoutsRequired) /
                (next.workoutsRequired - workoutsRequired))
            .clamp(0.0, 1.0)
        : 1.0;

    // Calculate volume progress (only if required)
    final volumeProgress = next.volumeRequired > volumeRequired
        ? ((totalVolume - volumeRequired) /
                (next.volumeRequired - volumeRequired))
            .clamp(0.0, 1.0)
        : 1.0;

    // Return the lower of the two (both requirements must be met)
    return (workoutProgress < volumeProgress) ? workoutProgress : volumeProgress;
  }

  /// Returns what's needed for next tier
  Map<String, int> remainingForNext(int totalWorkouts, int totalVolume) {
    final next = nextTier;
    if (next == null) return {};

    return {
      'workouts': (next.workoutsRequired - totalWorkouts).clamp(0, 999),
      'volume': (next.volumeRequired - totalVolume).clamp(0, 999999999),
    };
  }
}

/// Time window for analytics
enum AnalyticsWindow {
  days7(7, '7D'),
  days28(28, '28D'),
  days90(90, '90D');

  final int days;
  final String label;

  const AnalyticsWindow(this.days, this.label);
}

/// Daily stats record
class DailyStats {
  final String date; // yyyy-MM-dd
  final int workouts;
  final int volume;
  final int timeMinutes;
  final int sets;
  final int reps;
  final List<String> muscleGroups;

  DailyStats({
    required this.date,
    this.workouts = 0,
    this.volume = 0,
    this.timeMinutes = 0,
    this.sets = 0,
    this.reps = 0,
    this.muscleGroups = const [],
  });

  factory DailyStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DailyStats(
      date: doc.id,
      workouts: data['workouts'] ?? 0,
      volume: data['volume'] ?? 0,
      timeMinutes: data['timeMinutes'] ?? 0,
      sets: data['sets'] ?? 0,
      reps: data['reps'] ?? 0,
      muscleGroups: List<String>.from(data['muscleGroups'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'workouts': workouts,
        'volume': volume,
        'timeMinutes': timeMinutes,
        'sets': sets,
        'reps': reps,
        'muscleGroups': muscleGroups,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  DailyStats copyWith({
    String? date,
    int? workouts,
    int? volume,
    int? timeMinutes,
    int? sets,
    int? reps,
    List<String>? muscleGroups,
  }) =>
      DailyStats(
        date: date ?? this.date,
        workouts: workouts ?? this.workouts,
        volume: volume ?? this.volume,
        timeMinutes: timeMinutes ?? this.timeMinutes,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        muscleGroups: muscleGroups ?? this.muscleGroups,
      );
}

/// Muscle group distribution
class MuscleDistribution {
  final Map<String, int> distribution; // muscleGroup -> workout count
  final String mostTrained;
  final String leastTrained;

  MuscleDistribution({
    required this.distribution,
    required this.mostTrained,
    required this.leastTrained,
  });

  factory MuscleDistribution.empty() => MuscleDistribution(
        distribution: {},
        mostTrained: '',
        leastTrained: '',
      );

  factory MuscleDistribution.fromMap(Map<String, int> dist) {
    if (dist.isEmpty) return MuscleDistribution.empty();

    final sorted = dist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MuscleDistribution(
      distribution: dist,
      mostTrained: sorted.first.key,
      leastTrained: sorted.last.key,
    );
  }

  int get total => distribution.values.fold(0, (a, b) => a + b);

  double percentageOf(String muscle) {
    if (total == 0) return 0;
    return (distribution[muscle] ?? 0) / total;
  }
}

/// Personal Record entry
class PRRecord {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final double value; // 1RM or max reps
  final String unit; // 'lb', 'kg', 'reps'
  final DateTime achievedAt;
  final bool isNew; // Achieved in current window

  PRRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.value,
    required this.unit,
    required this.achievedAt,
    this.isNew = false,
  });

  factory PRRecord.fromFirestore(Map<String, dynamic> data) {
    return PRRecord(
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      muscleGroup: data['muscleGroup'] ?? '',
      value: (data['value'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] ?? 'lb',
      achievedAt:
          (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isNew: data['isNew'] ?? false,
    );
  }
}

/// Main analytics summary model
class AnalyticsSummary {
  // Totals for selected window
  final int workouts;
  final int totalVolume;
  final int totalTimeMinutes;
  final int totalSets;
  final int totalReps;
  final double consistencyPercent; // % of days with workouts

  // All-time totals (for tier calculation)
  final int allTimeWorkouts;
  final int allTimeVolume;

  // Tier
  final SweatTier tier;

  // PRs
  final int prCountThisMonth;
  final List<PRRecord> recentPRs;

  // Muscle distribution
  final MuscleDistribution muscleDistribution;

  // Daily data for charts
  final List<DailyStats> dailyStats;

  // Most improved (exercise with biggest volume increase)
  final String? mostImprovedExercise;

  AnalyticsSummary({
    this.workouts = 0,
    this.totalVolume = 0,
    this.totalTimeMinutes = 0,
    this.totalSets = 0,
    this.totalReps = 0,
    this.consistencyPercent = 0,
    this.allTimeWorkouts = 0,
    this.allTimeVolume = 0,
    this.tier = SweatTier.starter,
    this.prCountThisMonth = 0,
    this.recentPRs = const [],
    MuscleDistribution? muscleDistribution,
    this.dailyStats = const [],
    this.mostImprovedExercise,
  }) : muscleDistribution = muscleDistribution ?? MuscleDistribution.empty();

  factory AnalyticsSummary.empty() => AnalyticsSummary();

  factory AnalyticsSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final allTimeWorkouts = data['allTimeWorkouts'] ?? 0;
    final allTimeVolume = data['allTimeVolume'] ?? 0;

    return AnalyticsSummary(
      workouts: data['workouts'] ?? 0,
      totalVolume: data['totalVolume'] ?? 0,
      totalTimeMinutes: data['totalTimeMinutes'] ?? 0,
      totalSets: data['totalSets'] ?? 0,
      totalReps: data['totalReps'] ?? 0,
      consistencyPercent: (data['consistencyPercent'] as num?)?.toDouble() ?? 0,
      allTimeWorkouts: allTimeWorkouts,
      allTimeVolume: allTimeVolume,
      tier: SweatTier.fromStats(allTimeWorkouts, allTimeVolume),
      prCountThisMonth: data['prCountThisMonth'] ?? 0,
      mostImprovedExercise: data['mostImprovedExercise'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'workouts': workouts,
        'totalVolume': totalVolume,
        'totalTimeMinutes': totalTimeMinutes,
        'totalSets': totalSets,
        'totalReps': totalReps,
        'consistencyPercent': consistencyPercent,
        'allTimeWorkouts': allTimeWorkouts,
        'allTimeVolume': allTimeVolume,
        'tier': tier.name,
        'prCountThisMonth': prCountThisMonth,
        'mostImprovedExercise': mostImprovedExercise,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AnalyticsSummary copyWith({
    int? workouts,
    int? totalVolume,
    int? totalTimeMinutes,
    int? totalSets,
    int? totalReps,
    double? consistencyPercent,
    int? allTimeWorkouts,
    int? allTimeVolume,
    SweatTier? tier,
    int? prCountThisMonth,
    List<PRRecord>? recentPRs,
    MuscleDistribution? muscleDistribution,
    List<DailyStats>? dailyStats,
    String? mostImprovedExercise,
  }) =>
      AnalyticsSummary(
        workouts: workouts ?? this.workouts,
        totalVolume: totalVolume ?? this.totalVolume,
        totalTimeMinutes: totalTimeMinutes ?? this.totalTimeMinutes,
        totalSets: totalSets ?? this.totalSets,
        totalReps: totalReps ?? this.totalReps,
        consistencyPercent: consistencyPercent ?? this.consistencyPercent,
        allTimeWorkouts: allTimeWorkouts ?? this.allTimeWorkouts,
        allTimeVolume: allTimeVolume ?? this.allTimeVolume,
        tier: tier ?? this.tier,
        prCountThisMonth: prCountThisMonth ?? this.prCountThisMonth,
        recentPRs: recentPRs ?? this.recentPRs,
        muscleDistribution: muscleDistribution ?? this.muscleDistribution,
        dailyStats: dailyStats ?? this.dailyStats,
        mostImprovedExercise: mostImprovedExercise ?? this.mostImprovedExercise,
      );

  /// Format volume for display
  static String formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(volume >= 10000 ? 0 : 1)}K';
    }
    return volume.toString();
  }

  /// Format time for display
  static String formatTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${minutes}m';
  }
}
