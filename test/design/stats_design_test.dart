import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/exercise_info_screen.dart';
import 'package:sweatmark/screens/exercise_progress_screen.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/personal_records.dart';

import '../logging/home_test.dart' show Settings, Workouts;

const _exerciseId = 'inner-hip-machine';
const _exerciseName = 'Hip Adduction Machine (Inner Thigh)';

class _RecordedWorkouts extends Workouts {
  @override
  final List<WorkoutLog> workoutHistory = List.generate(2, (index) {
    final now = DateTime.now();
    return WorkoutLog(
        workoutName: 'Lower body strength and conditioning',
        timestamp: DateTime(now.year, now.month, now.day, 0, 0, index),
        durationSeconds: 3540,
        exercises: [
          WorkoutExerciseLog(
              exerciseId: _exerciseId,
              exerciseName: _exerciseName,
              exerciseType: 'weightedStrength',
              muscleGroup: 'Upper legs',
              equipment: 'Machine',
              sets: [
                WorkoutSet(
                    weight: 60 + 5.0 * index,
                    weightUnit: 'kg',
                    reps: 8,
                    isCompleted: true)
              ]),
          WorkoutExerciseLog(
              exerciseId: 'incline-walk',
              exerciseName: 'Treadmill incline walking',
              exerciseType: 'cardio',
              averageHeartRate: 146,
              intensity: 'Moderate',
              sets: [
                WorkoutSet(
                    durationSeconds: 1200,
                    distance: 1.5,
                    distanceUnit: 'km',
                    isCompleted: true)
              ])
        ]);
  });
}

Widget _app(ThemeData theme, Widget screen, {bool reducedMotion = false}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutNotifier>(
              create: (_) => _RecordedWorkouts()),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.5),
                    disableAnimations: reducedMotion),
                child: child!),
            home: screen));

void _narrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('General Sans');
    for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$weight.otf'));
    }
    await fonts.load();
  });

  for (final theme in [lightTheme, darkTheme]) {
    final mode = theme.brightness.name;
    testWidgets('$mode stats and every detail sheet fit narrow large text',
        (tester) async {
      _narrowPhone(tester);
      await tester.pumpWidget(_app(theme, const StatsScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text('Stats')).style?.fontSize, 18);
      for (final title in [
        'Workouts',
        'Time',
        'Personal Records',
        'Strength',
        'Cardio',
        'Muscles',
        'Active days'
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode $title sheet');
        final sheetList = find.descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(ListView));
        await tester.drag(sheetList, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$mode $title sheet content');
        if (title == 'Personal Records') {
          final exercise = find.descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.text(_exerciseName));
          await tester.scrollUntilVisible(exercise.first, 120,
              scrollable: find.descendant(
                  of: find.byType(DraggableScrollableSheet),
                  matching: find.byWidgetPredicate((widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down)));
          await tester.pumpAndSettle();
          await tester.tap(exercise.first);
          await tester.pumpAndSettle();
          expect(find.byType(ExerciseProgressScreen), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$mode narrow exercise progress');
          await tester.scrollUntilVisible(find.text('Previous sessions'), 180,
              scrollable: find.byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down));
          await tester.pumpAndSettle();
          expect(find.text('Previous sessions'), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$mode narrow previous sessions');
          await tester.scrollUntilVisible(find.byTooltip('Back'), -180,
              scrollable: find.byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Close details'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('Year'), -400);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.text('Year')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Active days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active days'));
      await tester.pumpAndSettle();
      expect(find.text('Workouts by month · tap a month to explore.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode exercise info tabs and chart fit narrow large text',
        (tester) async {
      _narrowPhone(tester);
      await tester.pumpWidget(_app(
          theme,
          Scaffold(
              body: ExerciseInfoScreen(
                  exercise: Exercise(
                      id: _exerciseId,
                      name: _exerciseName,
                      muscleGroup: 'Upper legs',
                      equipment: 'Machine',
                      instructions:
                          'Sit comfortably and position the pads against your inner thighs.\nBring your legs together with control.')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.isScrollable, isTrue);
      expect(tabs.labelColor, theme.colorScheme.primary);
      expect(find.text(_exerciseName), findsOneWidget);
      for (final tab in ['History', 'Chart', 'How-to']) {
        final target = find.widgetWithText(Tab, tab);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mode $tab tab');
      }
    });

    testWidgets(
        '$mode PR snackbar respects reduced motion at narrow large text',
        (tester) async {
      _narrowPhone(tester);
      for (final reduced in [true, false]) {
        await tester.pumpWidget(_app(theme, Builder(builder: (context) {
          return Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                              backgroundColor:
                                  AppDesign.of(context).recordContainer,
                              content: const RecordCelebration(
                                  'New PR! Hip Adduction Machine (Inner Thigh) · 65 kg × 8'))),
                      child: const Text('Celebrate'))));
        }), reducedMotion: reduced));
        await tester.tap(find.text('Celebrate'));
        await tester.pump();
        final animation = find.descendant(
            of: find.byType(RecordCelebration),
            matching: find.byType(TweenAnimationBuilder<double>));
        expect(animation, reduced ? findsNothing : findsOneWidget);
        expect(tester.widget<Text>(find.textContaining('New PR!')).style?.color,
            theme.extension<AppDesign>()!.onRecordContainer);
        await tester.pump(const Duration(milliseconds: 1200));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
