// Native UI harness. All workout, routine, preference, and auth state is in
// memory; this entry point never initializes Firebase or production services.
// Run with: flutter run -t test/manual/workout_result_preview.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/template_model.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/workout_summary_screen.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/state/auth_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkoutResultPreview());
}

class PreviewAuth extends ChangeNotifier implements AuthNotifier {
  @override
  User? get user => null;
  @override
  bool get isAuthenticated => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewSettings extends ChangeNotifier implements SettingsNotifier {
  @override
  UserSettings get userSettings => const UserSettings(
      weightUnit: WeightUnit.kg, distanceUnit: DistanceUnit.kilometers);
  @override
  bool get userSettingsLoaded => true;
  @override
  String get weightSuffix => 'kg';
  @override
  String get distanceSuffix => 'km';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewWorkouts extends ChangeNotifier implements WorkoutNotifier {
  final List<WorkoutLog> _history;
  PreviewWorkouts() : _history = _fixtureHistory();
  WorkoutLog get completed => _history.last;
  @override
  List<WorkoutLog> get workoutHistory => List.unmodifiable(_history);
  @override
  List<PersonalRecord> get personalRecords => PRService.records(_history);

  @override
  Future<void> updateWorkoutHistoryNotes(
      WorkoutLog workout, String notes) async {
    final index = _history.indexWhere((entry) => entry.id == workout.id);
    if (index < 0) return;
    _history[index] = WorkoutLog(
      workoutName: workout.workoutName,
      timestamp: workout.timestamp,
      durationSeconds: workout.durationSeconds,
      exercises: workout.exercises,
      superSets: workout.superSets,
      notes: notes.trim().isEmpty ? null : notes.trim(),
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewTemplates extends ChangeNotifier implements TemplateNotifier {
  final List<WorkoutTemplate> _templates = [];
  @override
  List<WorkoutTemplate> get templates => List.unmodifiable(_templates);

  @override
  Future<WorkoutTemplate?> createTemplate({
    required String name,
    required List<TemplateExercise> exercises,
    String? description,
    TemplateIcon icon = TemplateIcon.dumbbell,
    WorkoutSchedule? schedule,
    String? collectionId,
  }) async {
    final template = WorkoutTemplate(
      id: 'preview-routine-${_templates.length}',
      userId: 'preview-only',
      name: name,
      exercises: exercises,
      description: description,
      icon: icon,
      schedule: schedule,
      collectionId: collectionId,
    );
    _templates.add(template);
    notifyListeners();
    return template;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<WorkoutLog> _fixtureHistory() {
  final today = DateTime.now().subtract(const Duration(minutes: 5));
  WorkoutExerciseLog bench(double weight) => WorkoutExerciseLog(
        exerciseId: 'preview-bench',
        exerciseName: 'Bench Press',
        exerciseType: 'weightedStrength',
        muscleGroup: 'chest',
        equipment: 'barbell',
        sets: List.generate(
            3,
            (_) => WorkoutSet(
                weight: weight, weightUnit: 'kg', reps: 8, isCompleted: true)),
      );
  WorkoutExerciseLog pushUps(int reps) => WorkoutExerciseLog(
        exerciseId: 'preview-push-ups',
        exerciseName: 'Push Ups',
        exerciseType: 'bodyweightReps',
        muscleGroup: 'chest',
        equipment: 'body weight',
        sets:
            List.generate(2, (_) => WorkoutSet(reps: reps, isCompleted: true)),
      );
  return [
    WorkoutLog(
      workoutName: 'Upper body · preview',
      timestamp: today.subtract(const Duration(days: 14)),
      durationSeconds: 2400,
      exercises: [bench(60), pushUps(15)],
    ),
    WorkoutLog(
      workoutName: 'Upper body · preview',
      timestamp: today.subtract(const Duration(days: 7)),
      durationSeconds: 2520,
      exercises: [bench(60), pushUps(15)],
    ),
    WorkoutLog(
      workoutName: 'Full body strength',
      timestamp: today,
      durationSeconds: 3060,
      notes: 'Felt strong today. Kept the final set controlled.',
      // Null artwork deliberately exercises the actual local icon placeholders.
      exercises: [
        bench(65),
        WorkoutExerciseLog(
          exerciseId: 'preview-row',
          exerciseName: 'Seated Cable Row',
          exerciseType: 'weightedStrength',
          muscleGroup: 'back',
          equipment: 'cable',
          sets: List.generate(
              3,
              (_) => WorkoutSet(
                  weight: 45, weightUnit: 'kg', reps: 10, isCompleted: true)),
        ),
        pushUps(20),
        WorkoutExerciseLog(
          exerciseId: 'preview-bike',
          exerciseName: 'Stationary Bike',
          exerciseType: 'cardio',
          muscleGroup: 'cardio',
          equipment: 'bike',
          averageHeartRate: 138,
          intensity: 'Moderate',
          sets: [
            WorkoutSet(
                durationSeconds: 900,
                distance: 5,
                distanceUnit: 'km',
                isCompleted: true),
          ],
        ),
        WorkoutExerciseLog(
          exerciseId: 'preview-plank',
          exerciseName: 'Plank',
          exerciseType: 'timedHold',
          muscleGroup: 'core',
          equipment: 'body weight',
          sets: [
            WorkoutSet(durationSeconds: 60, isCompleted: true),
            WorkoutSet(durationSeconds: 75, isCompleted: true),
          ],
        ),
      ],
    ),
  ];
}

class WorkoutResultPreview extends StatefulWidget {
  const WorkoutResultPreview({super.key});
  @override
  State<WorkoutResultPreview> createState() => _WorkoutResultPreviewState();
}

class _WorkoutResultPreviewState extends State<WorkoutResultPreview> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>(create: (_) => PreviewAuth()),
          ChangeNotifierProvider<SettingsNotifier>(
              create: (_) => PreviewSettings()),
          ChangeNotifierProvider<WorkoutNotifier>(
              create: (_) => PreviewWorkouts()),
          ChangeNotifierProvider<TemplateNotifier>(
              create: (_) => PreviewTemplates()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Workout result preview')),
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Preview only · No workout is saved',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkoutSummaryScreen(
                                completedWorkout:
                                    (context.read<WorkoutNotifier>()
                                            as PreviewWorkouts)
                                        .completed),
                          ),
                        ),
                        child: const Text('Open workout result'),
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text('Dark preview'),
                        value: dark,
                        onChanged: (value) => setState(() => dark = value),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
