import 'package:provider/provider.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'logging/home_test.dart' show Workouts, Settings;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/workout_summary_screen.dart';

void main() {
  testWidgets('saved summary never asks the user to save the workout again',
      (tester) async {
    final workout = WorkoutLog(
        workoutName: 'Push day',
        timestamp: DateTime(2026),
        durationSeconds: 60,
        exercises: [
          WorkoutExerciseLog(exerciseId: 'press', exerciseName: 'Press', sets: [
            WorkoutSet(weight: 50, weightUnit: 'kg', reps: 5, isCompleted: true)
          ])
        ]);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            home: WorkoutSummaryScreen(completedWorkout: workout))));
    expect(find.text('S W E A T M A R K'), findsOneWidget);
    expect(find.text('Push day'), findsOneWidget);
    await tester.tap(find.byTooltip('Workout options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout notes'));
    await tester.pumpAndSettle();
    expect(find.text('Save notes'), findsOneWidget);
    Navigator.of(tester.element(find.text('Workout notes').last)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('50 kg × 5'), 180);
    expect(find.text('50 kg × 5'), findsOneWidget);
    expect(find.text('Finish & save'), findsNothing);
    expect(find.text('Save workout'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
