import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../state/workout_notifier.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final WorkoutExerciseLog log;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(exercise.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.dotsThree),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Column Headers
            const Row(
              children: [
                Expanded(flex: 1, child: Text('Set', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                Expanded(flex: 2, child: Text('Previous', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                Expanded(flex: 2, child: Text('kg', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                Expanded(flex: 2, child: Text('Reps', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                Expanded(flex: 1, child: SizedBox()),
              ],
            ),
            const SizedBox(height: 8),

            // Sets
            ...List.generate(log.sets.length, (index) {
              final set = log.sets[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text('${index + 1}', textAlign: TextAlign.center)),
                    const Expanded(flex: 2, child: Text('-', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))), // Ghost text
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            context.read<WorkoutNotifier>().updateSet(log.exerciseId, index, int.tryParse(val), set.reps);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            context.read<WorkoutNotifier>().updateSet(log.exerciseId, index, set.weight, int.tryParse(val));
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        icon: Icon(
                          set.isCompleted ? PhosphorIconsRegular.checkSquare : PhosphorIconsRegular.square,
                          color: set.isCompleted ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        onPressed: () {
                          context.read<WorkoutNotifier>().toggleSetCompletion(log.exerciseId, index);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Add Set Button
            Center(
              child: TextButton.icon(
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Add Set'),
                onPressed: () {
                  context.read<WorkoutNotifier>().addSet(log.exerciseId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
