import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'home_test.dart' show Workouts, Settings;

Finder _sheetScroll() => find.descendant(
    of: find.byType(DraggableScrollableSheet),
    matching: find.byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down));

class LoggedWorkouts extends Workouts {
  @override
  List<WorkoutLog> get workoutHistory => [
        WorkoutLog(
            workoutName: 'Morning run',
            timestamp: DateTime(DateTime.now().year - 1, 1, 2, 10, 30),
            durationSeconds: 1800,
            exercises: [
              WorkoutExerciseLog(
                  exerciseId: 'run',
                  exerciseName: 'Running',
                  exerciseType: 'cardio',
                  averageHeartRate: 140,
                  intensity: 'Moderate',
                  sets: [
                    WorkoutSet(
                        isCompleted: true,
                        durationSeconds: 1200,
                        distance: 3,
                        distanceUnit: 'km')
                  ])
            ])
      ];
}

void main() {
  testWidgets(
      'year chart opens month and details show logged timestamps and cardio observations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => LoggedWorkouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
    ], child: const MaterialApp(home: StatsScreen())));
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('January: 1 workouts'), 200,
        scrollable: _sheetScroll());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('January: 1 workouts'));
    await tester.pumpAndSettle();
    expect(find.text('January ${DateTime.now().year - 1}'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining(
            'Logged Jan 2, ${DateTime.now().year - 1} · 10:30 AM'),
        200,
        scrollable: _sheetScroll());
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Logged Jan 2, ${DateTime.now().year - 1} · 10:30 AM'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cardio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardio'));
    await tester.pumpAndSettle();
    expect(find.text('140 bpm'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('Average HR: 140 bpm · Effort: Moderate'), 200,
        scrollable: _sheetScroll());
    expect(tester.takeException(), isNull);
  });
}
