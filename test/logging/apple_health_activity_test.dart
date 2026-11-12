import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/health_activity.dart';
import 'package:sweatmark/models/monthly_stats.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/widgets/apple_health_activity.dart';

WorkoutLog logged(String name, DateTime at, int seconds) => WorkoutLog(
        workoutName: name,
        timestamp: at,
        durationSeconds: seconds,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'press',
              exerciseType: 'weightedStrength',
              sets: [
                WorkoutSet(
                    weight: 50, weightUnit: 'kg', reps: 5, isCompleted: true)
              ])
        ]);

HealthActivity watch(String id, DateTime start, int minutes) => HealthActivity(
    id: id,
    start: start,
    end: start.add(Duration(minutes: minutes)),
    sourceName: 'Apple Watch');

void main() {
  test('Watch time replaces a logged workout on the same day only', () {
    final day = DateTime(2026, 11, 3);
    final summary = HealthSummary(sessions: [
      watch('w1', day.add(const Duration(hours: 7)), 52),
      watch('w2', day.add(const Duration(hours: 18)), 30),
      watch('other-day', day.add(const Duration(days: 1, hours: 7)), 40),
    ]);
    final morning = logged(
        'morning', day.add(const Duration(hours: 7, minutes: 5)), 40 * 60);
    final evening = logged('evening', day.add(const Duration(hours: 17)), 0);
    final nextWeek = logged('later', day.add(const Duration(days: 7)), 1800);
    final times = summary.watchTimes([evening, morning, nextWeek]);
    expect(times[morning.id]?.id, 'w1', reason: 'overlapping session wins');
    expect(times[evening.id]?.id, 'w2', reason: 'same day, nearest start');
    expect(times.containsKey(nextWeek.id), isFalse);

    final stats = MonthlyStats.calculate([morning, evening], DateTime(2026, 11),
        now: DateTime(2026, 11, 30),
        durations: {for (final e in times.entries) e.key: e.value.seconds});
    expect(stats.totalSeconds, (52 + 30) * 60);
    expect(stats.timedWorkouts, 2);
    expect(stats.watchTimedWorkouts, 2);
  });

  test('each Watch workout replaces at most one logged workout', () {
    final day = DateTime(2026, 11, 3, 7);
    final summary = HealthSummary(sessions: [watch('w1', day, 60)]);
    final times = summary.watchTimes([
      logged('a', day, 1800),
      logged('b', day.add(const Duration(minutes: 30)), 1800),
    ]);
    expect(times.length, 1);
  });

  test('cardio source setting is saved and defaults to both', () {
    expect(const UserSettings().cardioSource, CardioSource.both);
    final saved = UserSettings.fromJson(
        const UserSettings(cardioSource: CardioSource.health).toJson());
    expect(saved.cardioSource, CardioSource.health);
    expect(CardioSource.logs.usesHealth, isFalse);
    expect(CardioSource.health.usesLogs, isFalse);
  });

  Future<void> pump(WidgetTester tester, AppleHealthActivity card) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card))));
    await tester.pump();
  }

  testWidgets('asks to connect when Health is off', (tester) async {
    var taps = 0;
    await pump(
        tester, AppleHealthActivity(summary: null, onConnect: () => taps++));
    await tester.tap(find.text('Connect Apple Health'));
    expect(taps, 1);
  });

  testWidgets('shows steps, distance and energy, not workouts', (tester) async {
    await pump(
        tester,
        AppleHealthActivity(
            summary: HealthSummary(
                steps: 8421,
                distanceMeters: 5000,
                activeKcal: 412.4,
                sessions: [watch('w', DateTime(2026, 11, 2, 7), 30)]),
            miles: true,
            watchTimed: 1));
    expect(find.text('8,421'), findsOneWidget);
    expect(find.text('3.1 mi'), findsOneWidget);
    expect(find.text('412 kcal'), findsOneWidget);
    expect(find.textContaining('Apple Watch time'), findsOneWidget);
    expect(find.text('Run'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('daily averages use the days that have Health data', () {
    final summary = HealthSummary(steps: 9000, daysWithData: 9);
    expect(summary.perDay(9000, 11), 1000, reason: '9 days with data');
    expect(HealthSummary(steps: 9000).perDay(9000, 10), 900,
        reason: 'unknown days fall back to the whole period');
    expect(HealthSummary(daysWithData: 40).perDay(3000, 30), 100,
        reason: 'never more days than the period has');
    expect(summary.perDay(null, 11), isNull);
    expect(summary.perDay(0, 11), isNull);
  });

  testWidgets('shows the period, daily averages and missing days',
      (tester) async {
    await pump(
        tester,
        AppleHealthActivity(
            summary: HealthSummary(
                steps: 44000,
                distanceMeters: 22000,
                activeKcal: 3300,
                daysWithData: 10),
            period: 'Nov 1–11',
            periodDays: 11));
    expect(find.text('Nov 1–11 · 11 days'), findsOneWidget);
    expect(find.text('44,000'), findsOneWidget);
    expect(find.text('avg 4,400 a day'), findsOneWidget);
    expect(find.text('avg 2.2 km a day'), findsOneWidget);
    expect(find.text('avg 330 kcal a day'), findsOneWidget);
    expect(find.textContaining('Health has data on 10 of 11 days'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a one-day period shows totals without averages', (tester) async {
    await pump(
        tester,
        AppleHealthActivity(
            summary: HealthSummary(steps: 5000, daysWithData: 1),
            period: 'Nov 1',
            periodDays: 1));
    expect(find.text('Nov 1 · 1 day'), findsOneWidget);
    expect(find.textContaining('avg'), findsNothing);
    expect(find.textContaining('Health has data on'), findsNothing);
  });

  testWidgets('says when Health has nothing for the period', (tester) async {
    await pump(tester, AppleHealthActivity(summary: HealthSummary()));
    expect(find.textContaining('No steps, distance or active energy'),
        findsOneWidget);
  });
}
