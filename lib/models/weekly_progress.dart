import 'workout_model.dart';

DateTime weekStart(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day - local.weekday + 1);
}

String weekKey(DateTime date) =>
    weekStart(date).toIso8601String().split('T').first;

int goalForWeek(Map<String, int> goals, DateTime date) {
  final key = weekKey(date);
  final eligible =
      goals.keys.where((entry) => entry.compareTo(key) <= 0).toList()..sort();
  return eligible.isEmpty ? 1 : goals[eligible.last]!;
}

class WeeklyProgress {
  final int streak;
  final int count;
  final int goal;
  const WeeklyProgress(this.streak, this.count, this.goal);

  factory WeeklyProgress.calculate(
      List<WorkoutLog> workouts, Map<String, int> goals, DateTime now) {
    final counts = <String, int>{};
    final seen = <String>{};
    for (final workout in workouts) {
      if (workout.isTestData ||
          workout.timestamp.isAfter(now) ||
          !seen.add(workout.id) ||
          !workout.exercises.any((e) => e.sets.any((s) => s.isCompleted)))
        continue;
      final key = weekKey(workout.timestamp);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    var week = weekStart(now);
    final count = counts[weekKey(week)] ?? 0;
    final goal = goalForWeek(goals, week);
    var streak = 0;
    if (count >= goal) streak++;
    week = DateTime(week.year, week.month, week.day - 7);
    while ((counts[weekKey(week)] ?? 0) >= goalForWeek(goals, week)) {
      streak++;
      week = DateTime(week.year, week.month, week.day - 7);
    }
    return WeeklyProgress(streak, count, goal);
  }
}
