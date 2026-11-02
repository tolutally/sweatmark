import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/active_workout_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/personal_records.dart';
import 'design_preview_test.dart' show DesignWorkouts, DesignSettings;

const _longExerciseName =
    'Alternating Incline Dumbbell Bench Press with Neutral Grip';

class _NarrowWorkouts extends DesignWorkouts {
  bool collapsed;
  _NarrowWorkouts({this.collapsed = false, bool longName = false})
      : super(active: true) {
    if (longName) {
      final exercise = workout.exercises.single;
      workout.exercises[0] = WorkoutExerciseLog(
        exerciseId: exercise.exerciseId,
        exerciseName: _longExerciseName,
        muscleGroup: exercise.muscleGroup,
        equipment: exercise.equipment,
        exerciseType: exercise.exerciseType,
        sets: exercise.sets,
      );
    }
  }
  @override
  bool isExerciseCollapsed(String id) => collapsed;
  @override
  void toggleExerciseCollapsed(String id) {
    collapsed = !collapsed;
    notifyListeners();
  }
}

class _RestSettings extends DesignSettings {
  bool resting = true;
  bool paused = false;
  int seconds = 90;
  @override
  bool get isResting => resting;
  @override
  bool get isPaused => paused;
  @override
  int get currentRestSeconds => seconds;
  @override
  String formatRestTime(int value) =>
      '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  @override
  void adjustRestTime(int delta) {
    seconds += delta;
    notifyListeners();
  }

  @override
  void pauseRestTimer() {
    paused = true;
    notifyListeners();
  }

  @override
  void resumeRestTimer() {
    paused = false;
    notifyListeners();
  }

  @override
  void stopRestTimer() {
    resting = false;
    notifyListeners();
  }
}

Future<void> _pumpWorkout(WidgetTester tester,
    {required bool dark,
    _NarrowWorkouts? workouts,
    DesignSettings? settings}) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutNotifier>(
          create: (_) => workouts ?? _NarrowWorkouts()),
      ChangeNotifierProvider<SettingsNotifier>(
          create: (_) => settings ?? DesignSettings()),
    ],
    child: MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: const ActiveWorkoutScreen(),
    ),
  ));
  await tester.pumpAndSettle();
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
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('active logging fits 320px at 1.5 text scale in $mode',
        (tester) async {
      await _pumpWorkout(tester, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Finish & save'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
      for (final check in tester.widgetList<IconButton>(find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.tooltip == 'Complete set' ||
                  w.tooltip == 'Mark set incomplete')))) {
        expect(check.onPressed, isNotNull);
      }
    });

    testWidgets('logging remains usable above the keyboard in $mode',
        (tester) async {
      await _pumpWorkout(tester, dark: dark);
      await tester.tap(find.byType(TextField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getBottomRight(find.byType(TextField).first).dy,
          lessThanOrEqualTo(460));
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('collapsed long exercise retains its PR badge in $mode',
        (tester) async {
      final workouts = _NarrowWorkouts(collapsed: true, longName: true);
      await _pumpWorkout(tester, dark: dark, workouts: workouts);
      expect(tester.takeException(), isNull);
      expect(find.text(_longExerciseName), findsOneWidget);
      expect(find.byType(BestRecordBadge), findsOneWidget);
      expect(find.text('🏆 Best: 60 kg × 8'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byIcon(PhosphorIconsRegular.caretDown).last);
      await tester.pumpAndSettle();
      expect(workouts.collapsed, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('🏆 Best: 60 kg × 8'), findsOneWidget);
    });

    testWidgets('rest controls fit and work on a narrow phone in $mode',
        (tester) async {
      final settings = _RestSettings();
      await _pumpWorkout(tester,
          dark: dark,
          settings: settings,
          workouts: _NarrowWorkouts(collapsed: true));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('+15'));
      await tester.pumpAndSettle();
      expect(settings.seconds, 105);
      await tester.tap(find.byTooltip('Pause rest timer'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume rest timer'));
      await tester.pumpAndSettle();
      expect(settings.paused, isFalse);
      await tester.tap(find.byTooltip('Stop rest timer'));
      await tester.pumpAndSettle();
      expect(find.text('Rest timer'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
