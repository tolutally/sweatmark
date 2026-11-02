import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/exercise_progress_screen.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/app_shell.dart';

import '../logging/home_test.dart' show Settings, Workouts;

class _ReferenceSettings extends Settings {
  @override
  UserSettings get userSettings => const UserSettings(
      weightUnit: WeightUnit.kg, distanceUnit: DistanceUnit.kilometers);
}

class _ReferenceWorkouts extends Workouts {
  _ReferenceWorkouts() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final recent = now.subtract(const Duration(minutes: 1));
    final first = recent.subtract(const Duration(days: 2));
    final firstDate = first.isBefore(monthStart) ? monthStart : first;
    history = [
      _workout(
          'Upper body baseline', monthStart.subtract(const Duration(days: 2)),
          weight: 55, minutes: 30),
      _workout('Upper body & easy run', firstDate,
          weight: 60,
          minutes: 30,
          cardioMinutes: 20,
          distance: 2,
          intensity: 'Low'),
      _workout('Strength & conditioning', recent,
          weight: 65,
          minutes: 40,
          cardioMinutes: 30,
          distance: 3,
          intensity: 'High'),
    ];
  }

  late final List<WorkoutLog> history;

  @override
  List<WorkoutLog> get workoutHistory => history;

  WorkoutLog _workout(String name, DateTime date,
          {required double weight,
          required int minutes,
          int cardioMinutes = 0,
          double distance = 0,
          String? intensity}) =>
      WorkoutLog(
          workoutName: name,
          timestamp: date,
          durationSeconds: minutes * 60,
          exercises: [
            WorkoutExerciseLog(
                exerciseId: 'reference-bench-press',
                exerciseName: 'Bench Press',
                exerciseType: 'weightedStrength',
                muscleGroup: 'Chest',
                equipment: 'Barbell',
                sets: [
                  WorkoutSet(
                      weight: weight,
                      weightUnit: 'kg',
                      reps: 8,
                      isCompleted: true),
                  WorkoutSet(
                      weight: weight,
                      weightUnit: 'kg',
                      reps: 6,
                      isCompleted: true),
                ]),
            if (cardioMinutes > 0)
              WorkoutExerciseLog(
                  exerciseId: 'reference-run',
                  exerciseName: 'Treadmill Run',
                  exerciseType: 'cardio',
                  averageHeartRate: 146,
                  intensity: intensity,
                  sets: [
                    WorkoutSet(
                        durationSeconds: cardioMinutes * 60,
                        distance: distance,
                        distanceUnit: 'km',
                        isCompleted: true)
                  ]),
          ]);
}

Future<void> _capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DESIGN')) return;
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/sweatmark-stats-reference-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
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
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    for (final name in ['Regular', 'Bold', 'Fill']) {
      final icons = FontLoader('packages/phosphor_icons/Phosphor$name')
        ..addFont(rootBundle.load(
            'packages/phosphor_icons/lib/fonts/Phosphor${name == 'Regular' ? '' : '-$name'}.ttf'));
      await icons.load();
    }
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('recorded $mode stats and detail sheets render with real fonts',
        (tester) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<WorkoutNotifier>(
                create: (_) => _ReferenceWorkouts()),
            ChangeNotifierProvider<SettingsNotifier>(
                create: (_) => _ReferenceSettings()),
          ],
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                  home: Scaffold(
                      body: const StatsScreen(),
                      bottomNavigationBar: AppNavigationDock(
                          selectedIndex: 3,
                          onSelected: (_) {},
                          onWorkoutPressed: () {}))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'overview-$mode');
      await tester.tap(find.byTooltip('Choose period'));
      await tester.pumpAndSettle();
      await _capture(tester, boundary, 'calendar-$mode');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      for (final entry in {
        'Workouts': 'workouts',
        'Time': 'time',
        'Strength': 'strength',
        'Cardio': 'cardio',
        'Muscles': 'muscles',
        'Active days': 'active-days',
        'Personal Records': 'personal-records',
      }.entries) {
        await tester.ensureVisible(find.text(entry.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode ${entry.key}');
        await _capture(tester, boundary, '${entry.value}-$mode');
        final expectedValues = switch (entry.key) {
          'Time' => ['1h 10m', '35 min'],
          'Strength' => ['1,750 kg'],
          'Cardio' => ['50 min', '5.0 km', '146 bpm'],
          _ => <String>[],
        };
        for (final value in expectedValues) {
          final target = find.descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.text(value));
          await tester.scrollUntilVisible(target.first, 140,
              scrollable: find.descendant(
                  of: find.byType(DraggableScrollableSheet),
                  matching: find.byWidgetPredicate((widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down)));
          await tester.pumpAndSettle();
          expect(target, findsWidgets,
              reason: '${entry.key} reflects completed workout values');
        }
        if (entry.key == 'Personal Records') {
          await tester.scrollUntilVisible(find.text('Bench Press').first, 160,
              scrollable: find.byType(Scrollable).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bench Press').first);
          await tester.pumpAndSettle();
          expect(find.byType(ExerciseProgressScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(tester, boundary, 'exercise-progress-$mode');
        } else {
          await tester.tap(find.byTooltip('Close details'));
          await tester.pumpAndSettle();
        }
      }
      debugDisableShadows = true;
    });
  }
}
