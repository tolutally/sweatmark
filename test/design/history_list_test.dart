import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/workout_history_screen.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/home_test.dart' show Workouts;

WorkoutLog _log(String name, DateTime when, int seconds, List<String> moves) =>
    WorkoutLog(
      workoutName: name,
      timestamp: when,
      durationSeconds: seconds,
      exercises: [
        for (final move in moves)
          WorkoutExerciseLog(
              exerciseId: move.toLowerCase(),
              exerciseName: move,
              sets: [WorkoutSet(weight: 20, reps: 10, isCompleted: true)]),
      ],
    );

class _History extends Workouts {
  @override
  List<WorkoutLog> get workoutHistory => [
        _log('Upper Body Push', DateTime(2026, 10, 30, 9), 3720,
            ['Barbell Bench Press', 'Assisted Dip']),
        _log('Leg Day', DateTime(2026, 10, 20, 18), 2400,
            ['Dumbbell Split Squat', 'Hip Adduction']),
        _log('Morning Run', DateTime(2026, 9, 12, 7), 0, ['Outdoor Run']),
        _log('Full Body Strength and Conditioning Circuit',
            DateTime(2025, 12, 1, 12), 5400, ['Barbell Clean and Press']),
      ];
}

Future<void> _pump(WidgetTester tester,
    {ThemeData? theme,
    Size size = const Size(390, 844),
    double text = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<WorkoutNotifier>(
    create: (_) => _History(),
    child: MaterialApp(
      theme: theme ?? lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(text)),
          child: child!),
      home: const RepaintBoundary(child: WorkoutHistoryScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> _order(WidgetTester tester) => [
      for (final name in [
        'Upper Body Push',
        'Leg Day',
        'Morning Run',
        'Full Body Strength and Conditioning Circuit'
      ])
        if (find.text(name).evaluate().isNotEmpty) name
    ]..sort((a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy));

void main() {
  setUpAll(() async {
    final fonts = FontLoader('General Sans');
    for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
    }
    await fonts.load();
    for (final name in ['Regular', 'Bold']) {
      final icons = FontLoader('packages/phosphor_icons/Phosphor$name')
        ..addFont(rootBundle.load(
            'packages/phosphor_icons/lib/fonts/Phosphor${name == 'Regular' ? '' : '-$name'}.ttf'));
      await icons.load();
    }
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets('${theme.brightness.name} history fits narrow large text',
        (tester) async {
      await _pump(tester, theme: theme, size: const Size(320, 844), text: 1.5);
      expect(find.text('Workout History'), findsOneWidget);
      expect(find.byTooltip('Sort workouts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search matches workout and exercise names', (tester) async {
    await _pump(tester);
    expect(_order(tester), hasLength(4));
    // Missing duration is omitted rather than shown as zero.
    expect(find.text('Sep 12 · 1 exercise'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'split squat');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Leg Day']);

    await tester.enterText(find.byType(TextField), 'push');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Upper Body Push']);

    await tester.enterText(find.byType(TextField), 'yoga');
    await tester.pumpAndSettle();
    expect(find.text('No workouts match “yoga”'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(_order(tester), hasLength(4));
  });

  testWidgets('sort reorders the list', (tester) async {
    await _pump(tester);
    expect(_order(tester).first, 'Upper Body Push');

    const capture = String.fromEnvironment('CAPTURE_HISTORY');
    if (capture.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(capture).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> choose(String label) async {
      await tester.tap(find.byTooltip('Sort workouts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose('Oldest first');
    expect(_order(tester).first, 'Full Body Strength and Conditioning Circuit');
    await choose('Longest duration');
    expect(_order(tester), [
      'Full Body Strength and Conditioning Circuit',
      'Upper Body Push',
      'Leg Day',
      'Morning Run',
    ]);
    await choose('Name (A–Z)');
    expect(_order(tester).first, 'Full Body Strength and Conditioning Circuit');
    expect(_order(tester).last, 'Upper Body Push');
  });
}
