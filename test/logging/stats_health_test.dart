import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/health_activity.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'home_test.dart' show Workouts, Settings;

final today = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}();

class _OneWorkout extends Workouts {
  @override
  List<WorkoutLog> get workoutHistory => [
        WorkoutLog(
            workoutName: 'Push day',
            timestamp: today,
            durationSeconds: 20 * 60,
            exercises: [
              WorkoutExerciseLog(
                  exerciseId: 'press',
                  exerciseType: 'weightedStrength',
                  sets: [
                    WorkoutSet(
                        weight: 50,
                        weightUnit: 'kg',
                        reps: 5,
                        isCompleted: true)
                  ])
            ])
      ];
}

void main() {
  testWidgets('Stats uses same-day Apple Watch time and shows Health movement',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutNotifier>(create: (_) => _OneWorkout()),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            theme: lightTheme,
            home: StatsScreen(
                healthAvailable: true,
                healthReader: (_, __, ___) async => HealthSummary(
                        steps: 9120,
                        distanceMeters: 4200,
                        activeKcal: 380,
                        sessions: [
                          HealthActivity(
                              id: 'watch',
                              start: today,
                              end: today.add(const Duration(minutes: 45)),
                              sourceName: 'Apple Watch')
                        ])))));
    await tester.pumpAndSettle();
    expect(find.text('45 min'), findsWidgets,
        reason: 'Watch time replaces the 20 min timer');
    expect(find.text('20 min'), findsNothing);
    expect(find.text('9,120'), findsOneWidget);
    expect(find.text('380 kcal'), findsOneWidget);
    expect(find.textContaining('uses Apple Watch time'), findsOneWidget);
    final now = DateTime.now();
    final month = DateFormat('MMM').format(now);
    expect(
        find.textContaining(
            now.day == 1 ? '$month 1 · 1 day' : '$month 1–${now.day} · '),
        findsOneWidget,
        reason: 'Health totals say what period they cover');
    expect(find.text('Logged workouts'), findsNothing,
        reason: 'Stats no longer lists logged workouts');
    expect(tester.takeException(), isNull);
  });
}
