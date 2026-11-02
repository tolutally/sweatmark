import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template_model.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../state/workout_notifier.dart';
import '../state/exercise_db_notifier.dart';
import 'active_workout_screen.dart';
import 'exercise_info_screen.dart';

class RoutineDetailScreen extends StatelessWidget {
  final WorkoutTemplate routine;
  final Map<String, String> names;
  const RoutineDetailScreen(
      {super.key, required this.routine, this.names = const {}});
  String _name(TemplateExercise e) {
    final name = names[e.id] ?? e.name;
    // Some routines stored an ID in the name field.
    final idLike = RegExp(r'^(custom|exercisedb|free)_').hasMatch(name);
    return exerciseDisplayName(e.id, saved: idLike ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutNotifier>();
    final catalog =
        context.watch<ExerciseDbNotifier?>()?.exercises ?? <Exercise>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('My routine'),
        leading: Navigator.of(context).canPop()
            ? BackButton(
                style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const CircleBorder()))
            : null,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(routine.name,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text('${routine.exercises.length} saved exercises'),
        const SizedBox(height: 24),
        if (routine.exercises.isEmpty)
          const Text('This routine has no saved exercises yet.'),
        for (final exercise in routine.exercises)
          Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                title: Text(_name(exercise),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${exercise.targetSets} sets${exercise.targetReps == null ? '' : ' · ${exercise.targetReps} reps'}'),
                trailing: IconButton(
                    tooltip: 'Info for ${_name(exercise)}',
                    icon: Icon(Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      final matches = catalog.where((e) => e.id == exercise.id);
                      showExerciseInfo(
                          context,
                          matches.isNotEmpty
                              ? matches.first
                              : Exercise(
                                  id: exercise.id,
                                  name: _name(exercise),
                                  muscleGroup: '',
                                  equipment: '',
                                  icon: '💪'));
                    }),
              )),
      ]),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(workouts.isWorkoutActive
                    ? 'Resume current workout'
                    : 'Start workout'),
                onPressed: routine.exercises.isEmpty &&
                        !workouts.isWorkoutActive
                    ? null
                    : () {
                        if (!workouts.isWorkoutActive) {
                          workouts.startWorkout(workoutName: routine.name);
                          for (final exercise in routine.exercises) {
                            workouts.addExerciseFromTemplate(
                                name: _name(exercise),
                                exerciseId: exercise.id,
                                exerciseDefinition: catalog
                                    .where((e) => e.id == exercise.id)
                                    .firstOrNull,
                                targetSets: exercise.targetSets,
                                targetReps: exercise.targetReps);
                          }
                        }
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ActiveWorkoutScreen()));
                      },
              ))),
    );
  }
}
