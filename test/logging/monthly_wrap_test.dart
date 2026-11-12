import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/health_activity.dart';
import 'package:sweatmark/models/monthly_stats.dart';
import 'package:sweatmark/models/monthly_wrap.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/monthly_wrap_screen.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/muscle_icon.dart';
import 'package:sweatmark/widgets/share_image_sheet.dart';
import 'home_test.dart' show Workouts, Settings;

WorkoutLog lift(String name, DateTime at,
        {String id = 'bench',
        String exercise = 'Bench Press',
        String? muscle = 'Chest',
        double? weight = 60,
        int sets = 3,
        int seconds = 3600}) =>
    WorkoutLog(
        workoutName: name,
        timestamp: at,
        durationSeconds: seconds,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: id,
              exerciseName: exercise,
              exerciseType: 'weightedStrength',
              muscleGroup: muscle,
              sets: [
                for (var i = 0; i < sets; i++)
                  WorkoutSet(
                      weight: weight,
                      weightUnit: weight == null ? null : 'kg',
                      reps: 5,
                      isCompleted: true)
              ])
        ]);

MonthlyWrap wrapFor(List<WorkoutLog> history, DateTime month, DateTime now,
    {HealthSummary? health}) {
  final previous = DateTime(month.year, month.month - 1);
  return MonthlyWrap.from(
      month: month,
      stats: MonthlyStats.calculate(history, month, now: now),
      previous: MonthlyStats.calculate(history, previous, now: now),
      records: PRService.records(history),
      now: now,
      health: health);
}

void main() {
  final october = DateTime(2026, 10);
  final later = DateTime(2026, 11, 11);
  final history = [
    lift('September', DateTime(2026, 9, 20, 7), weight: 50),
    lift('Private push name', DateTime(2026, 10, 3, 7), weight: 55),
    lift('Legs', DateTime(2026, 10, 4, 7),
        id: 'squat', exercise: 'Back Squat', muscle: 'Legs', sets: 5),
    lift('Push', DateTime(2026, 10, 5, 7), weight: 70),
    lift('Mystery', DateTime(2026, 10, 12, 7),
        id: 'odd', exercise: 'Odd lift', muscle: null, weight: null),
  ];

  test('wrap sums the month, its best streak and its leaders', () {
    final wrap = wrapFor(history, october, later);
    expect(wrap.soFar, isFalse);
    expect(wrap.workouts, 4);
    expect(wrap.activeDays, 4);
    expect(wrap.longestStreak, 3, reason: 'Oct 3, 4 and 5');
    expect(wrap.totalSeconds, 4 * 3600);
    expect(wrap.strengthSets, 14);
    expect(wrap.topExercise?.name, 'Bench Press', reason: '6 sets vs 5');
    expect(wrap.topExercise?.sets, 6);
    expect(wrap.topMuscles.first, 'Chest');
    expect(wrap.topMuscles, isNot(contains('Unspecified')));
    expect(wrap.workoutChange, 3, reason: '4 in October, 1 in September');
    expect(wrap.records, isNotEmpty);
    expect(
        wrap.records.every((r) =>
            r.timestamp.month == 10 &&
            r.timestamp.year == 2026 &&
            !r.isBaseline),
        isTrue);
    expect(wrap.days, 31);
    expect(wrap.health, isNull);
  });

  test('a first month has nothing to compare and no made-up totals', () {
    final wrap = wrapFor([
      lift('Only', DateTime(2026, 9, 2, 7), weight: null, seconds: 0),
    ], DateTime(2026, 9), later, health: HealthSummary());
    expect(wrap.workoutChange, isNull);
    expect(wrap.totalSeconds, isNull);
    expect(wrap.volumeKg, isNull);
    expect(wrap.longestStreak, 1);
    expect(wrap.health, isNull, reason: 'empty Health is left out');
    expect(wrapFor(const [], DateTime(2026, 8), later).isEmpty, isTrue);
  });

  test('the current month is "so far" and counts days up to today', () {
    final wrap =
        wrapFor(history, DateTime(2026, 10), DateTime(2026, 10, 12, 20));
    expect(wrap.soFar, isTrue);
    expect(wrap.days, 12);
  });

  Future<void> pumpCard(WidgetTester tester, MonthlyWrap wrap) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: MonthlyWrapCard(wrap: wrap, displayName: 'Tolu')))));
    await tester.pump();
  }

  WorkoutLog run(DateTime at, {int minutes = 30, double km = 5}) => WorkoutLog(
          workoutName: 'Run',
          timestamp: at,
          durationSeconds: minutes * 60,
          exercises: [
            WorkoutExerciseLog(
                exerciseId: 'run',
                exerciseName: 'Running',
                exerciseType: 'cardio',
                sets: [
                  WorkoutSet(
                      isCompleted: true,
                      durationSeconds: minutes * 60,
                      distance: km,
                      distanceUnit: 'km')
                ])
          ]);

  test('cardio, rings and the headline come from logged data', () {
    final wrap = wrapFor([
      ...history,
      run(DateTime(2026, 10, 20, 7), minutes: 40),
      run(DateTime(2026, 10, 22, 7), minutes: 20),
    ], october, later, health: HealthSummary(steps: 155000, daysWithData: 31));
    expect(wrap.cardioSessions, 2);
    expect(wrap.cardioSeconds, 3600);
    expect(wrap.cardioKm, 10);
    expect(wrap.cardioShare, closeTo(60 / (150 * 31 / 7), 1e-9));
    expect(wrap.activeShare, 6 / 31);
    expect(wrap.stepsPerDay, 5000);
    expect(wrap.cheer.title, isNotEmpty);

    // Headlines follow the month's best result.
    final up = wrapFor(history, october, later);
    expect(up.records.length == 1 ? 'New PR unlocked.' : up.cheer.title,
        anyOf('New PR unlocked.', 'New PRs unlocked.', 'Leveling up.'));
    final first = wrapFor(
        [lift('Only', DateTime(2026, 9, 2, 7))], DateTime(2026, 9), later);
    expect(first.cheer.title, 'You showed up.');
    final soFar = wrapFor([lift('Only', DateTime(2026, 11, 2, 7))],
        DateTime(2026, 11), DateTime(2026, 11, 5));
    expect(soFar.cheer.title, 'November is just getting started.');
  });

  testWidgets('card is 9:16, motivates, and leaves private details out',
      (tester) async {
    await pumpCard(
        tester,
        wrapFor([
          ...history,
          run(DateTime(2026, 10, 20, 7)),
        ], october, later,
            health: HealthSummary(
                steps: 155000, distanceMeters: 62000, daysWithData: 31)));
    expect(tester.getSize(find.byType(MonthlyWrapCard)), const Size(360, 640));
    expect(find.text('October 2026 · Tolu'), findsOneWidget);
    expect(find.text('Monthly wrap'), findsOneWidget);
    expect(find.text('5'), findsOneWidget, reason: 'workouts in the rings');
    expect(find.text('5 of 31'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget, reason: 'cardio ring');
    expect(find.textContaining('cardio · goal'), findsOneWidget);
    expect(find.text('5,000'), findsOneWidget, reason: 'steps ring');
    expect(find.text('steps a day'), findsOneWidget);
    expect(find.text('Most trained'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.byType(MuscleIcon), findsWidgets);
    expect(find.textContaining('Private push name'), findsNothing,
        reason: 'workout names stay private');
    expect(tester.takeException(), isNull, reason: 'a full month fits');
  });

  testWidgets('a quiet month hides empty sections', (tester) async {
    await pumpCard(
        tester,
        wrapFor([
          lift('Only', DateTime(2026, 9, 2, 7),
              muscle: null, weight: null, seconds: 0),
        ], DateTime(2026, 9), later));
    expect(find.text('You showed up.'), findsOneWidget);
    expect(find.text('1 of 30'), findsOneWidget);
    expect(find.text('day active'), findsOneWidget);
    expect(find.textContaining('cardio'), findsNothing);
    expect(find.textContaining('steps'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    expect(find.textContaining('PR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('every catalog muscle group has an icon file', () {
    for (final muscle in [
      'Abs', 'Chest', 'Biceps', 'Glutes', 'Shoulders', 'Triceps', //
      'Upper back', 'Lats', 'Calves', 'Quadriceps', 'Forearms', 'Cardio',
      'Hamstrings', 'Lower back', 'Traps', 'Adductors', 'Serratus',
      'Abductors', 'Neck', 'Core', 'Back', 'Something new'
    ]) {
      expect(File(MuscleIcon.assetFor(muscle)).existsSync(), isTrue,
          reason: muscle);
    }
  });

  test('a wrap opens when its month ends and is featured for 3 days', () {
    final oct = DateTime(2026, 10);
    expect(MonthlyWrap.isReady(oct, DateTime(2026, 10, 31, 23, 59)), isFalse);
    expect(MonthlyWrap.isReady(oct, DateTime(2026, 11, 1)), isTrue);
    expect(MonthlyWrap.isReady(oct, DateTime(2027, 3, 9)), isTrue);
    expect(MonthlyWrap.featuredMonth(DateTime(2026, 11, 1)), oct);
    expect(MonthlyWrap.featuredMonth(DateTime(2026, 11, 3, 23)), oct);
    expect(MonthlyWrap.featuredMonth(DateTime(2026, 11, 4)), isNull);
    expect(MonthlyWrap.featuredMonth(DateTime(2027, 1, 2)), DateTime(2026, 12));
  });

  Future<void> pumpStats(
      WidgetTester tester, DateTime now, List<WorkoutLog> history) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutNotifier>(
              create: (_) => _History(history)),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            theme: lightTheme,
            home: StatsScreen(healthAvailable: false, clock: () => now))));
    await tester.pumpAndSettle();
  }

  testWidgets('on the 1st to 3rd, Stats features last month\'s wrap',
      (tester) async {
    await pumpStats(tester, DateTime(2026, 11, 2, 9), [
      lift('October', DateTime(2026, 10, 10, 7)),
      lift('November', DateTime(2026, 11, 1, 7)),
    ]);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Your October wrap is ready'), findsOneWidget);
    expect(find.text('Your November wrap'), findsNothing,
        reason: 'November is not over');
    await tester.tap(find.text('Your October wrap is ready'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('monthly-wrap-card')), findsOneWidget);
    expect(find.text('October 2026'), findsWidgets);
    expect(find.text('Monthly wrap'), findsOneWidget);
    // The capture is laid out at 360 × 640 and exported at 3x: 1080 × 1920.
    final capture = find.descendant(
        of: find.byKey(const ValueKey('monthly-wrap-card')),
        matching: find.byType(RepaintBoundary));
    expect(tester.getSize(capture.first), const Size(360, 640));
    expect(ShareCanvas.reel.pixels, const Size(1080, 1920));
    expect(tester.takeException(), isNull);
  });

  testWidgets('after the 3rd it stays available from its own month',
      (tester) async {
    await pumpStats(tester, DateTime(2026, 11, 20, 9), [
      lift('October', DateTime(2026, 10, 10, 7)),
      lift('November', DateTime(2026, 11, 12, 7)),
    ]);
    expect(find.textContaining(' wrap'), findsNothing,
        reason: 'no wrap during a month, and the feature has ended');
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Your October wrap'), findsOneWidget);
    await tester.tap(find.text('Your October wrap'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('monthly-wrap-card')), findsOneWidget);
    await tester.tap(find.byTooltip('Close share preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.textContaining(' wrap'), findsNothing,
        reason: 'the wrap is monthly');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stats has no wrap for a month without workouts', (tester) async {
    await pumpStats(tester, DateTime(2026, 11, 2, 9), const []);
    expect(find.textContaining(' wrap'), findsNothing);
  });
}

class _History extends Workouts {
  final List<WorkoutLog> history;
  _History(this.history);
  @override
  List<WorkoutLog> get workoutHistory => history;
}
