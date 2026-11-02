import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/app_shell.dart';
import 'package:sweatmark/screens/home_screen.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/screens/settings_screen.dart';
import 'package:sweatmark/screens/active_workout_screen.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/template_model.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import '../logging/home_test.dart' show Workouts, Templates;
import '../logging/settings_screen_test.dart' show Preferences;

class DesignWorkouts extends Workouts {
  final bool active;
  DesignWorkouts({this.active = false});
  final workout = WorkoutLog(
    workoutName: 'Upper body',
    timestamp: DateTime(2026, 11, 1, 9, 30),
    durationSeconds: 1980,
    exercises: [
      WorkoutExerciseLog(
          exerciseId: 'preview-press',
          exerciseName: 'Bench Press',
          muscleGroup: 'chest',
          equipment: 'barbell',
          exerciseType: 'weightedStrength',
          sets: [
            WorkoutSet(
                weight: 60, weightUnit: 'kg', reps: 8, isCompleted: true),
            WorkoutSet(weight: 60, weightUnit: 'kg', reps: 8),
            WorkoutSet(weight: 60, weightUnit: 'kg', reps: 8)
          ])
    ],
  );
  @override
  List<WorkoutLog> get workoutHistory => [workout];
  @override
  bool get isWorkoutActive => active;
  @override
  WorkoutLog? get currentWorkout => active ? workout : null;
  @override
  int get elapsedSeconds => 483;
  @override
  String get workoutName => 'Upper body';
  @override
  List<PersonalRecord> bestForExercise(String id) =>
      PRService.bests(workoutHistory)
          .values
          .where((r) => r.exerciseId == id)
          .toList();
  @override
  List<PersonalRecord> get activeRecords => [];
  @override
  bool isExerciseCollapsed(String id) => false;
  @override
  List<SetFieldType>? exerciseFields(String id) => null;
}

class DesignSettings extends Preferences {
  @override
  UserSettings get userSettings =>
      const UserSettings(weightUnit: WeightUnit.kg);
  @override
  String get weightSuffix => 'kg';
  @override
  bool get isResting => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
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
    for (final entry in <String, Widget>{
      'home': const HomeScreen(),
      'stats': const StatsScreen(),
      'settings': const SettingsScreen(),
      'workout': const ActiveWorkoutScreen()
    }.entries) {
      testWidgets('${entry.key} renders in ${dark ? 'dark' : 'light'} theme',
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
                  create: (_) =>
                      DesignWorkouts(active: entry.key == 'workout')),
              ChangeNotifierProvider<SettingsNotifier>(
                  create: (_) => DesignSettings()),
              ChangeNotifierProvider<TemplateNotifier>(
                  create: (_) => Templates([
                        WorkoutTemplate(
                            id: 'upper',
                            userId: 'preview',
                            name: 'Upper body',
                            exercises: []),
                        WorkoutTemplate(
                            id: 'lower',
                            userId: 'preview',
                            name: 'Lower body',
                            exercises: []),
                      ])),
            ],
            child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                  home: entry.key == 'home'
                      ? Scaffold(
                          body: entry.value,
                          bottomNavigationBar: AppNavigationDock(
                              selectedIndex: 0,
                              onSelected: (_) {},
                              onWorkoutPressed: () {}))
                      : entry.value,
                ))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
            Theme.of(tester.element(find.byType(Scaffold).first))
                .textTheme
                .bodyMedium
                ?.fontFamily,
            'General Sans');
        if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    '/tmp/sweatmark-${entry.key}-${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (entry.key == 'settings') {
            await tester.tap(find.byTooltip('Weekly workout goal'));
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final image = await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '/tmp/sweatmark-settings-goal-${dark ? 'dark' : 'light'}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        debugDisableShadows = true;
      });
    }
  }
}
