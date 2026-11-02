import 'package:sweatmark/services/pr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/screens/home_screen.dart';
import 'package:sweatmark/screens/routine_detail_screen.dart';
import 'package:sweatmark/screens/exercise_info_screen.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/template_model.dart';

class Workouts extends ChangeNotifier implements WorkoutNotifier {
  int starts = 0;
  @override
  void startWorkout({String? workoutName}) {
    starts++;
  }

  @override
  List<WorkoutLog> get workoutHistory => [];
  @override
  List<PersonalRecord> get personalRecords => PRService.records(workoutHistory);
  @override
  bool get isWorkoutActive => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Settings extends ChangeNotifier implements SettingsNotifier {
  @override
  String get weightSuffix => 'kg';
  @override
  String get distanceSuffix => 'km';
  @override
  UserSettings get userSettings => const UserSettings();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Templates extends ChangeNotifier implements TemplateNotifier {
  @override
  List<WorkoutTemplate> get templates => saved;
  final List<WorkoutTemplate> saved;
  Templates([this.saved = const []]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('home prioritizes logging and two simple weekly numbers',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
      ChangeNotifierProvider<TemplateNotifier>(create: (_) => Templates()),
    ], child: const MaterialApp(home: HomeScreen())));
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.text('streak'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('My routines'), findsOneWidget);
    expect(find.text('Recovery'), findsNothing);
    expect(find.text('Streak Broken'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('New routine'));
    await tester.pumpAndSettle();
    expect(find.text('Routine name'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save routine'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Upper body');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save routine'))
            .onPressed,
        isNull);
  });
  testWidgets('home fits a narrow phone in dark mode', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
      ChangeNotifierProvider<TemplateNotifier>(create: (_) => Templates()),
    ], child: MaterialApp(theme: ThemeData.dark(), home: const HomeScreen())));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('My routines'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('routine tap opens preview without starting a workout',
      (tester) async {
    final workouts = Workouts();
    final routine = WorkoutTemplate(
        id: 'r',
        userId: 'u',
        name: 'Upper body',
        exercises: [TemplateExercise(id: 'press', name: 'Bench press')]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WorkoutNotifier>.value(value: workouts),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
      ChangeNotifierProvider<TemplateNotifier>(
          create: (_) => Templates([routine])),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.scrollUntilVisible(find.text('Upper body'), 200,
        scrollable: find.byType(Scrollable).first);
    // The name sits at the bottom of a tall collection card.
    await tester.ensureVisible(find.text('Upper body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper body'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineDetailScreen), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    expect(workouts.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise info opens how-to with chart and history tabs',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ExerciseInfoScreen(
                    exercise: Exercise(
                        id: 'press',
                        name: 'Bench press',
                        muscleGroup: 'Chest',
                        equipment: 'Barbell',
                        icon: '',
                        instructions: 'First step.\nSecond step.'))))));
    expect(find.text('First step.'), findsOneWidget);
    expect(find.text('Second step.'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'No completed sets yet. Log this exercise to start tracking your progress.'),
        findsOneWidget);
    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Complete two sessions with recorded weights and units to see your chart.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
