import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/template_model.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/weekly_progress.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/home_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/home_test.dart' show Settings, Templates, Workouts;

class DashboardWorkouts extends Workouts {
  DashboardWorkouts(this.history, {this.active = false});
  List<WorkoutLog> history;
  final bool active;

  @override
  List<WorkoutLog> get workoutHistory => history;

  @override
  bool get isWorkoutActive => active;

  void replaceHistory(List<WorkoutLog> value) {
    history = value;
    notifyListeners();
  }
}

class DashboardSettings extends Settings {
  @override
  UserSettings get userSettings => UserSettings(
      weightUnit: WeightUnit.kg, weeklyGoals: {weekKey(DateTime.now()): 3});
}

WorkoutLog _workout(String name, DateTime timestamp,
        {double weight = 65,
        int seconds = 1800,
        bool completed = true,
        bool test = false,
        bool rest = false}) =>
    WorkoutLog(
        workoutName: name,
        timestamp: timestamp,
        durationSeconds: seconds,
        isTestData: test,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: 'bench-press',
              exerciseName: 'Bench press',
              muscleGroup: 'Chest',
              equipment: 'Barbell',
              exerciseType: 'weightedStrength',
              sets: [
                WorkoutSet(
                    weight: weight,
                    weightUnit: 'kg',
                    reps: 8,
                    isCompleted: completed,
                    isSuperSetRest: rest)
              ])
        ]);

List<WorkoutLog> _mixedHistory() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    // Establish the existing best outside both this month and this week.
    _workout('Previous month baseline', DateTime(now.year, now.month, -7),
        weight: 60),
    _workout('Upper body strength', today, seconds: 2700),
    _workout('Upper body and accessory strength session',
        today.add(const Duration(milliseconds: 1))),
    _workout('Unfinished workout', today.add(const Duration(milliseconds: 2)),
        completed: false, weight: 100),
    _workout('Test workout', today.add(const Duration(milliseconds: 3)),
        test: true, weight: 200),
    _workout('Rest rows only', today.add(const Duration(milliseconds: 4)),
        rest: true),
    _workout('Future workout', now.add(const Duration(days: 1)), weight: 300),
  ];
}

Future<void> _pumpDashboard(WidgetTester tester, DashboardWorkouts workouts,
    {ThemeData? theme,
    Size size = const Size(390, 844),
    double textScale = 1,
    List<WorkoutTemplate> routines = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutNotifier>.value(value: workouts),
        ChangeNotifierProvider<SettingsNotifier>(
            create: (_) => DashboardSettings()),
        ChangeNotifierProvider<TemplateNotifier>(
            create: (_) => Templates(routines)),
      ],
      child: MaterialApp(
          theme: theme ?? lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true),
              child: child!),
          home: const HomeScreen())));
  await tester.pumpAndSettle();
}

void _expectMetric(String metric, String value) {
  expect(
      find.descendant(
          of: find.byKey(ValueKey('home-monthly-$metric')),
          matching: find.text(value)),
      findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('General Sans');
    for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
    }
    await fonts.load();
  });

  testWidgets(
      'dashboard shows completed activity and responds to history changes',
      (tester) async {
    final workouts = DashboardWorkouts(_mixedHistory());
    await _pumpDashboard(tester, workouts, size: const Size(390, 1500));
    expect(find.text('2/3'), findsOneWidget);
    _expectMetric('workouts', '2');
    _expectMetric('time', '75');
    _expectMetric('prs', '1');
    expect(
        find.text('Upper body and accessory strength session'), findsWidgets);
    expect(find.text('Test workout'), findsNothing);
    expect(find.text('Future workout'), findsNothing);
    expect(find.text('Unfinished workout'), findsNothing);
    expect(find.text('Rest rows only'), findsNothing);
    expect(tester.takeException(), isNull);

    workouts.replaceHistory([]);
    await tester.pumpAndSettle();
    expect(find.text('0/3'), findsOneWidget);
    _expectMetric('workouts', '0');
    _expectMetric('time', '—');
    _expectMetric('prs', '0');
    expect(
        find.text('Upper body and accessory strength session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty dashboard keeps logging and routines available without fake health data',
      (tester) async {
    await _pumpDashboard(tester, DashboardWorkouts([]));
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(find.byTooltip('Search exercises'), findsOneWidget);
    _expectMetric('workouts', '0');
    _expectMetric('time', '—');
    _expectMetric('prs', '0');
    for (final unavailableFeature in [
      'Heart Pts',
      'Steps',
      'Cal',
      'Last sleep'
    ]) {
      expect(find.text(unavailableFeature), findsNothing);
    }
    await tester.scrollUntilVisible(find.text('My routines'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('New routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active workout offers resume without silently creating another session',
      (tester) async {
    final workouts = DashboardWorkouts([], active: true);
    await _pumpDashboard(tester, workouts);
    expect(find.text('Resume workout'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
    expect(workouts.starts, 0);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets(
        'populated ${theme.brightness.name} dashboard fits 320px and larger text',
        (tester) async {
      await _pumpDashboard(tester, DashboardWorkouts(_mixedHistory()),
          theme: theme,
          size: const Size(320, 740),
          textScale: 1.5,
          routines: [
            WorkoutTemplate(
                id: 'upper',
                userId: 'user',
                name: 'Upper body and accessory strength routine',
                exercises: [
                  TemplateExercise(
                      id: 'press', name: 'Alternating dumbbell bench press')
                ])
          ]);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('home-monthly-prs')), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      _expectMetric('workouts', '2');
      _expectMetric('time', '75');
      _expectMetric('prs', '1');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.text('Upper body and accessory strength routine'), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
