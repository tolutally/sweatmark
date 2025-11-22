import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../state/recovery_notifier.dart';
import '../widgets/exercise_card.dart';
import '../models/exercise_model.dart';
import '../data/exercise_data.dart';
import 'library_screen.dart';

class ActiveWorkoutScreen extends StatelessWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final workout = notifier.currentWorkout;

    if (workout == null) {
      return const Scaffold(body: Center(child: Text('No active workout')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Workout'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              // Calculate impacted muscles
              final muscles = <String>{};
              for (final log in workout.exercises) {
                 final exerciseData = EXERCISE_LIBRARY.firstWhere((e) => e['id'] == log.exerciseId, orElse: () => {});
                 if (exerciseData.isNotEmpty) {
                   muscles.add(exerciseData['muscleGroup']);
                 }
              }
              
              context.read<RecoveryNotifier>().updateRecovery(muscles.toList());
              await notifier.finishWorkout();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Finish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timer Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.clock, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(notifier.elapsedSeconds),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Exercise List
          Expanded(
            child: ListView.builder(
              itemCount: workout.exercises.length + 1, // +1 for Add Button
              itemBuilder: (context, index) {
                if (index == workout.exercises.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Add Exercise'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final Exercise? selected = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LibraryScreen(isPicker: true)),
                        );
                        if (selected != null) {
                          notifier.addExercise(selected);
                        }
                      },
                    ),
                  );
                }

                final log = workout.exercises[index];
                // Find exercise details
                final exerciseData = EXERCISE_LIBRARY.firstWhere((e) => e['id'] == log.exerciseId, orElse: () => {});
                if (exerciseData.isEmpty) return const SizedBox();
                final exercise = Exercise.fromJson(exerciseData);

                return ExerciseCard(exercise: exercise, log: log);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
