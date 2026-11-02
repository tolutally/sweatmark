import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/workout_detail_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/home_test.dart' show Settings, Workouts;

WorkoutSet _set(double weight, int reps) =>
    WorkoutSet(weight: weight, weightUnit: 'kg', reps: reps, isCompleted: true);

final _earlier = WorkoutLog(
  workoutName: 'Upper Body Push',
  timestamp: DateTime(2026, 10, 26, 9),
  durationSeconds: 2400,
  exercises: [
    WorkoutExerciseLog(
        exerciseId: 'exercisedb_bench',
        exerciseName: 'Barbell Bench Press',
        sets: [_set(50, 8)]),
  ],
);

final _workout = WorkoutLog(
  workoutName: 'Upper Body Push',
  timestamp: DateTime(2026, 10, 29, 18, 15),
  durationSeconds: 3720,
  notes: 'Felt strong on the last set.',
  exercises: [
    WorkoutExerciseLog(
        exerciseId: 'exercisedb_bench',
        exerciseName: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sets: [
          _set(55, 8),
          _set(55, 6),
          WorkoutSet(weight: 60, weightUnit: 'kg', reps: 5),
        ]),
    WorkoutExerciseLog(
        exerciseId: 'exercisedb_plank',
        exerciseName: 'Plank',
        exerciseType: 'timedHold',
        sets: [WorkoutSet(durationSeconds: 75, isCompleted: true)]),
    // Older TestFlight logs saved only the ID.
    WorkoutExerciseLog(
        exerciseId: 'free_Upright_Barbell_Row', sets: [_set(27, 10)]),
    WorkoutExerciseLog(
        exerciseId: 'free_Jogging_Treadmill',
        exerciseName: 'Jogging, Treadmill',
        sets: [WorkoutSet(speed: 6, incline: 7.5, isCompleted: true)]),
    WorkoutExerciseLog(
        exerciseId: 'exercisedb_dip',
        exerciseName: 'Assisted Dip',
        sets: [WorkoutSet(reps: 10)]),
  ],
);

class _History extends Workouts {
  _History({this.active = false});
  final bool active;
  int repeats = 0;
  @override
  bool get isWorkoutActive => active;
  @override
  List<WorkoutLog> get workoutHistory => [_workout, _earlier];
  @override
  Future<void> repeatWorkout(WorkoutLog workout) async => repeats++;
}

Future<void> _pump(WidgetTester tester, _History workouts,
    {ThemeData? theme,
    Size size = const Size(390, 844),
    double text = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutNotifier>.value(value: workouts),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
    ],
    child: MaterialApp(
      theme: theme ?? lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(text)),
          child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WorkoutDetailScreen(workout: _workout))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('General Sans');
    for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
    }
    await fonts.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    for (final name in ['Regular', 'Bold']) {
      final icons = FontLoader('packages/phosphor_icons/Phosphor$name')
        ..addFont(rootBundle.load(
            'packages/phosphor_icons/lib/fonts/Phosphor${name == 'Regular' ? '' : '-$name'}.ttf'));
      await icons.load();
    }
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets('${theme.brightness.name} details fit narrow large text',
        (tester) async {
      await _pump(tester, _History(),
          theme: theme, size: const Size(320, 844), text: 1.5);
      expect(find.text('Workout details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Plank'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows recorded facts with saved names', (tester) async {
    await _pump(tester, _History());

    const capture = String.fromEnvironment('CAPTURE_DETAIL');
    if (capture.isNotEmpty) {
      tester.view.physicalSize = const Size(390, 2000);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).last);
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(capture).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    // Two workouts that week; the default goal is one.
    expect(find.text('Week of Oct 26'), findsOneWidget);
    expect(find.text('1h 2m'), findsOneWidget);
    expect(find.text('1 new personal record: Barbell Bench Press.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('Plank'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('exercisedb_bench'), findsNothing);
    // Cards start collapsed.
    expect(find.text('55 kg × 8'), findsNothing);
    for (final name in ['Barbell Bench Press', 'Plank']) {
      await tester.tap(find.byTooltip('Expand $name'));
      await tester.pumpAndSettle();
    }
    expect(find.text('55 kg × 8'), findsOneWidget);
    // Unfinished sets and exercises are not listed as done.
    expect(find.text('60 kg × 5'), findsNothing);
    expect(find.text('Assisted Dip'), findsNothing);
    expect(find.text('1m 15s'), findsOneWidget);
    // Older free_ IDs show their saved name and machine settings.
    await tester.scrollUntilVisible(find.text('Jogging, Treadmill'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('free_Jogging_Treadmill'), findsNothing);
    expect(find.text('Upright Barbell Row'), findsOneWidget);
    expect(find.text('free_Upright_Barbell_Row'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Expand Jogging, Treadmill'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand Jogging, Treadmill'));
    await tester.pumpAndSettle();
    expect(find.text('speed 6 · 7.5% incline'), findsOneWidget);
    expect(find.text('Felt strong on the last set.'), findsOneWidget);
  });

  testWidgets('exercise cards collapse and expand', (tester) async {
    await _pump(tester, _History());
    await tester.scrollUntilVisible(find.text('Plank'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('55 kg × 8'), findsNothing);
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('55 kg × 8'), findsOneWidget);
    // Other exercises keep their own state.
    expect(find.text('1m 15s'), findsNothing);
    await tester.tap(find.byTooltip('Collapse Barbell Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('55 kg × 8'), findsNothing);
    expect(find.byTooltip('Expand Barbell Bench Press'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeat starts a workout only when none is active',
      (tester) async {
    for (final active in [false, true]) {
      final workouts = _History(active: active);
      await _pump(tester, workouts);
      await tester.tap(find.byTooltip('More workout options'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(active ? 'Resume Current Workout' : 'Repeat Workout'));
      await tester.pump();
      expect(workouts.repeats, active ? 0 : 1);
      // The opened workout screen needs Firebase, which tests do not start.
      await tester.pumpWidget(const SizedBox());
      tester.takeException();
    }
  });
}
