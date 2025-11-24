import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../models/exercise_model.dart';
import '../data/exercise_data.dart';
import 'library_screen.dart';
import 'workout_summary_screen.dart';
import 'exercise_detail_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final TextEditingController _workoutNameController = TextEditingController(text: 'My Workout 1');

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final workout = notifier.currentWorkout;

    if (workout == null) {
      return const Scaffold(body: Center(child: Text('No active workout')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.x, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.black54),
              onPressed: () {},
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.play, color: Color(0xFF2BD4BD), size: 16),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(notifier.elapsedSeconds),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plus, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Workout Header
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB84D), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.barbell,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notifier.workoutName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
                            onPressed: () => _showRenameDialog(context, notifier),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Row(
                          children: [
                            Text(
                              'Set up schedule & repeat',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(PhosphorIconsRegular.caretRight, size: 14, color: Color(0xFF007AFF)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Exercise List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: workout.exercises.length + 2, // +1 for Add Button, +1 for Build For Me
              itemBuilder: (context, index) {
                // Add Exercise Button
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () async {
                        final Exercise? selected = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LibraryScreen(isPicker: true)),
                        );
                        if (selected != null) {
                          notifier.addExercise(selected);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsBold.plus, color: Color(0xFF2BD4BD), size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Add Exercise',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Build For Me Button
                if (index == workout.exercises.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: GestureDetector(
                      onTap: () {
                        // AI workout builder
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2BD4BD), Color(0xFF8EC5FC)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2BD4BD).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsBold.sparkle, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Build For Me',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final log = workout.exercises[index - 1];
                final exerciseData = EXERCISE_LIBRARY.firstWhere(
                  (e) => e['id'] == log.exerciseId,
                  orElse: () => {},
                );
                if (exerciseData.isEmpty) return const SizedBox();
                final exercise = Exercise.fromJson(exerciseData);

                return _ExerciseWorkoutCard(
                  exercise: exercise,
                  log: log,
                  exerciseIndex: index - 1,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () async {
              // Navigate to summary screen
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkoutSummaryScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Finish Workout',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WorkoutNotifier notifier) {
    final controller = TextEditingController(text: notifier.workoutName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workout name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.updateWorkoutName(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ExerciseWorkoutCard extends StatelessWidget {
  final Exercise exercise;
  final dynamic log;
  final int exerciseIndex;

  const _ExerciseWorkoutCard({
    required this.exercise,
    required this.log,
    required this.exerciseIndex,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Exercise Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(PhosphorIconsBold.barbell, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.dotsThree, color: Colors.black54),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.caretDown, color: Colors.black54),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Sets Section Header
          if (log.sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 60),
                  const Expanded(
                    child: Text(
                      'PREVIOUS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Sets List
          ...log.sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            return _SetRow(
              setNumber: index + 1,
              set: set,
              exerciseId: exercise.id,
              setIndex: index,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseDetailScreen(
                      exercise: exercise,
                      exerciseLog: log,
                      currentSetIndex: index,
                    ),
                  ),
                );
              },
            );
          }).toList(),

          // Add Set / Super Set Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => notifier.addSet(exercise.id),
                    icon: const Icon(PhosphorIconsRegular.plusCircle, size: 20),
                    label: const Text('Add Set'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.black12,
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 20),
                    label: const Text('Super Set'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsBold.check, color: Color(0xFF2BD4BD)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int setNumber;
  final dynamic set;
  final String exerciseId;
  final int setIndex;
  final VoidCallback onTap;

  const _SetRow({
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: set.isCompleted ? const Color(0xFFE8F5F3) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${setNumber}x',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: set.isCompleted ? const Color(0xFF2BD4BD) : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  const Text(
                    '--',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Text(
                    set.reps != null ? '${set.reps}' : '10',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'reps',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => notifier.toggleSetCompletion(exerciseId, setIndex),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: set.isCompleted ? const Color(0xFF2BD4BD) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: set.isCompleted ? const Color(0xFF2BD4BD) : const Color(0xFFD0D0D0),
                    width: 2,
                  ),
                ),
                child: set.isCompleted
                    ? const Icon(PhosphorIconsBold.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get exercise => '';
}
