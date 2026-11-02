import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/weekly_progress.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/user_settings.dart';

WorkoutLog log(DateTime date, {bool completed = true, bool test = false}) =>
    WorkoutLog(
        workoutName: 'Workout',
        timestamp: date,
        durationSeconds: 60,
        isTestData: test,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'press',
              sets: [WorkoutSet(reps: 5, isCompleted: completed)])
        ]);
void main() {
  test('default is one, active incomplete week preserves last week streak', () {
    final result = WeeklyProgress.calculate(
        [log(DateTime(2026, 10, 12)), log(DateTime(2026, 10, 5))],
        {},
        DateTime(2026, 10, 21));
    expect(result.goal, 1);
    expect(result.count, 0);
    expect(result.streak, 2);
  });
  test('meeting current goal extends streak once and deduplicates workouts',
      () {
    final logs = [
      log(DateTime(2026, 10, 12)),
      log(DateTime(2026, 10, 19)),
      log(DateTime(2026, 10, 20))
    ];
    final result = WeeklyProgress.calculate(
        [...logs, logs.last], {'2026-10-19': 2}, DateTime(2026, 10, 21));
    expect(result.count, 2);
    expect(result.streak, 2);
  });
  test('future goals leave past weeks and this week unchanged', () {
    final goals = {'2026-10-26': 3};
    expect(goalForWeek(goals, DateTime(2026, 10, 25, 23, 59)), 1);
    expect(goalForWeek(goals, DateTime(2026, 10, 26)), 3);
    expect(
        WeeklyProgress.calculate(
                [log(DateTime(2026, 10, 19))], goals, DateTime(2026, 10, 26))
            .streak,
        1);
  });
  test('missed closed week resets streak, ignoring test and incomplete records',
      () {
    final result = WeeklyProgress.calculate([
      log(DateTime(2026, 10, 5)),
      log(DateTime(2026, 10, 13), completed: false),
      log(DateTime(2026, 10, 14), test: true),
      log(DateTime(2026, 10, 28))
    ], {}, DateTime(2026, 10, 21));
    expect(result.streak, 0);
    expect(result.count, 0);
  });
  test('Sunday and Monday belong to different calendar weeks', () {
    expect(weekKey(DateTime(2026, 10, 25, 23, 59)), '2026-10-19');
    expect(weekKey(DateTime(2026, 10, 26)), '2026-10-26');
  });
  test('goal schedule survives preference roundtrip', () {
    final settings = UserSettings(weeklyGoals: {'2026-10-26': 3});
    expect(UserSettings.fromJson(settings.toJson()).weeklyGoals,
        settings.weeklyGoals);
    expect(settings.copyWith(weightUnit: WeightUnit.kg).weeklyGoals,
        settings.weeklyGoals);
  });
}
