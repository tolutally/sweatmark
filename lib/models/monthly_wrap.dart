import 'exercise_model.dart';
import 'health_activity.dart';
import 'monthly_stats.dart';
import '../services/pr_service.dart';

/// A month's highlights for the shareable wrap, built from what Stats
/// already shows. Anything not recorded is null or empty so the card can
/// leave it out instead of showing zero.
class MonthlyWrap {
  /// First day of the month.
  final DateTime month;

  /// The month isn't over yet.
  final bool soFar;
  final int workouts;
  final int activeDays;

  /// Most days trained in a row this month.
  final int longestStreak;

  /// Null when no workout has a recorded time.
  final int? totalSeconds;
  final int strengthSets;

  /// Null when no set has a known weight unit.
  final double? volumeKg;

  /// Workouts with completed cardio, and the time and distance logged in
  /// those sets. Distance is null when none had a known unit.
  final int cardioSessions;
  final int cardioSeconds;
  final double? cardioKm;

  /// Most-trained muscle groups, by completed sets, at most three.
  final List<String> topMuscles;

  /// The exercise with the most completed non-cardio sets.
  final ({String name, int sets})? topExercise;

  /// New personal records this month, newest first.
  final List<PersonalRecord> records;

  /// Workouts compared with the previous month (to the same day while
  /// [soFar]). Null when there's nothing to compare against.
  final int? workoutChange;

  /// Apple Health movement for the month, when Health is on and has data.
  final HealthSummary? health;

  /// Days covered, for Health daily averages.
  final int days;

  const MonthlyWrap({
    required this.month,
    required this.soFar,
    required this.workouts,
    required this.activeDays,
    required this.longestStreak,
    required this.totalSeconds,
    required this.strengthSets,
    required this.volumeKg,
    this.cardioSessions = 0,
    this.cardioSeconds = 0,
    this.cardioKm,
    required this.topMuscles,
    required this.topExercise,
    required this.records,
    required this.workoutChange,
    required this.health,
    required this.days,
  });

  factory MonthlyWrap.from({
    required DateTime month,
    required MonthlyStats stats,
    required MonthlyStats previous,
    required Iterable<PersonalRecord> records,
    required DateTime now,
    Map<String, Exercise> catalog = const {},
    HealthSummary? health,
  }) {
    final soFar = month.year == now.year && month.month == now.month;
    final days = soFar ? now.day : stats.dailyWorkouts.length;

    var longest = 0;
    var run = 0;
    for (final count in stats.dailyWorkouts.take(days)) {
      run = count > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    final muscles = stats.muscleSets.entries
        .where((e) => e.key != 'Unspecified' && e.value > 0)
        .toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));

    final sets = <String, ({String name, int sets})>{};
    for (final workout in stats.loggedWorkouts) {
      for (final exercise in workout.exercises) {
        if (MonthlyStats.isCardio(exercise, catalog[exercise.exerciseId])) {
          continue;
        }
        final count = exercise.sets
            .where((s) => s.isCompleted && !s.isSuperSetRest)
            .length;
        if (count == 0) continue;
        final id = exercise.exerciseId;
        sets[id] = (
          name: exercise.exerciseName ?? catalog[id]?.name ?? 'Exercise',
          sets: (sets[id]?.sets ?? 0) + count,
        );
      }
    }
    final top = sets.values.toList()
      ..sort((a, b) => b.sets != a.sets
          ? b.sets.compareTo(a.sets)
          : a.name.compareTo(b.name));

    final monthRecords = records
        .where((r) =>
            !r.isBaseline &&
            r.timestamp.toLocal().year == month.year &&
            r.timestamp.toLocal().month == month.month)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return MonthlyWrap(
      month: DateTime(month.year, month.month),
      soFar: soFar,
      workouts: stats.workouts,
      activeDays: stats.activeDays,
      longestStreak: longest,
      totalSeconds: stats.timedWorkouts == 0 ? null : stats.totalSeconds,
      strengthSets: stats.strengthSets,
      volumeKg: stats.weightedSets == 0 ? null : stats.volumeKg,
      cardioSessions: stats.cardioSessions,
      cardioSeconds: stats.cardioSeconds,
      cardioKm: stats.distanceSets == 0 ? null : stats.distanceKm,
      topMuscles: [for (final e in muscles.take(3)) e.key],
      topExercise: top.isEmpty ? null : top.first,
      records: monthRecords,
      workoutChange:
          previous.workouts == 0 ? null : stats.workouts - previous.workouts,
      health: health == null || health.isEmpty ? null : health,
      days: days,
    );
  }

  /// Whether there's anything to wrap up.
  bool get isEmpty => workouts == 0;

  /// Days at the start of each month when last month's wrap is featured.
  static const featuredDays = 3;

  /// A month's wrap opens once the month is over, on the 1st of the next.
  static bool isReady(DateTime month, DateTime now) =>
      !DateTime(month.year, month.month + 1).isAfter(now);

  /// Last month, during the first [featuredDays] days of a month; otherwise
  /// null. Past wraps stay available from their month in Stats.
  static DateTime? featuredMonth(DateTime now) =>
      now.day <= featuredDays ? DateTime(now.year, now.month - 1) : null;

  /// Recommended weekly cardio, in minutes (WHO guideline for adults).
  static const weeklyCardioMinutes = 150;

  /// A daily step target for the steps ring.
  static const dailySteps = 10000;

  /// Share of the month's days so far with a workout.
  double get activeShare => days == 0 ? 0 : activeDays / days;

  /// Logged cardio against [weeklyCardioMinutes], over the days covered.
  double get cardioShare {
    final goal = weeklyCardioMinutes * days / 7;
    return goal <= 0 ? 0 : cardioSeconds / 60 / goal;
  }

  /// Average daily steps from Apple Health, or null without step data.
  double? get stepsPerDay => health?.perDay(health?.steps, days);

  /// A short, upbeat headline and a line of detail, chosen from the
  /// month's best result. Never invents anything that wasn't logged.
  ({String title, String detail}) get cheer {
    final month = _monthName(month: this.month);
    final change = workoutChange;
    if (records.length > 1) {
      return (
        title: 'New PRs unlocked.',
        detail:
            '${records.length} personal records in $month. You’re getting stronger.'
      );
    }
    if (change != null && change > 0) {
      return (
        title: 'Leveling up.',
        detail:
            '$change more ${change == 1 ? 'workout' : 'workouts'} than last month. Keep climbing.'
      );
    }
    if (records.length == 1) {
      return (
        title: 'New PR unlocked.',
        detail: 'You beat a personal best in $month. Stronger than last time.'
      );
    }
    if (longestStreak >= 3) {
      return (
        title: '$longestStreak days straight.',
        detail: 'That’s what consistency looks like.'
      );
    }
    if (activeDays >= 12) {
      return (
        title: 'You kept showing up.',
        detail: '$activeDays active days in $month. That’s the habit.'
      );
    }
    if ((stepsPerDay ?? 0) >= dailySteps) {
      return (
        title: 'On the move.',
        detail: 'Over ${_thousands(dailySteps)} steps a day on average.'
      );
    }
    if (soFar) {
      return (
        title: '$month is just getting started.',
        detail: 'Every session counts. Keep it rolling.'
      );
    }
    return (
      title: workouts == 1 ? 'You showed up.' : 'Work put in.',
      detail: 'Every rep counts. Next month, go again.'
    );
  }

  static String _thousands(int value) => value >= 1000
      ? '${value ~/ 1000},${(value % 1000).toString().padLeft(3, '0')}'
      : '$value';

  static String _monthName({required DateTime month}) => const [
        'January', 'February', 'March', 'April', 'May', 'June', 'July', //
        'August', 'September', 'October', 'November', 'December'
      ][month.month - 1];
}
