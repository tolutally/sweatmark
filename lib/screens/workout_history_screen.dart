import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import '../state/workout_notifier.dart';
import 'workout_detail_screen.dart';
import '../theme/app_theme.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // History is already loaded in WorkoutNotifier constructor
  }

  void _navigateToWorkoutDetail(BuildContext context, WorkoutLog workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(workout: workout),
      ),
    );
  }

  void _deleteWorkout(WorkoutLog workout) async {
    final notifier = context.read<WorkoutNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text('Are you sure you want to delete this workout? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      notifier.deleteWorkout(workout);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        title: const Text(
          'Workout History',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        elevation: 0,
      ),
      body: Consumer<WorkoutNotifier>(
        builder: (context, workoutNotifier, child) {
          final workouts = workoutNotifier.workoutHistory;

          if (workouts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsBold.clock, size: 64, color: Colors.black26),
                  SizedBox(height: 16),
                  Text(
                    'No workout history yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black26,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your completed workouts will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              return _WorkoutCard(
                workout: workout,
                onTap: () => _navigateToWorkoutDetail(context, workout),
                onDelete: () => _deleteWorkout(workout),
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutLog workout;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(date.year, date.month, date.day);

    if (workoutDate == today) {
      return 'Today';
    } else if (workoutDate == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${monthNames[date.month - 1]} ${date.day}';
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = workout.exercises.take(3).toList();
    
    // Calculate total weight
    int totalWeight = 0;
    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        if (set.weight != null && set.reps != null) {
          totalWeight += (set.weight! * set.reps!);
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(workout.timestamp),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${workout.exercises.length} exercises',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.clock,
                          size: 14,
                          color: AppColors.brandCoral,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(workout.durationSeconds),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandCoral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.black26,
                    size: 20,
                  ),
                ],
              ),
            ),
            // Exercise List
            ...exercises.map<Widget>((exercise) {
              final exerciseData = EXERCISE_LIBRARY.firstWhere(
                (e) => e['id'] == exercise.exerciseId,
                orElse: () => {'name': exercise.exerciseId, 'muscleGroup': 'Unknown'},
              );
              final exerciseName = exerciseData['name'] ?? exercise.exerciseId;
              final sets = exercise.sets.where((s) => s.isCompleted).length;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.barbell,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$sets sets completed',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (exercise.sets.isNotEmpty && exercise.sets.first.weight != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${exercise.sets.first.weight} lb',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            // Stats Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsBold.barbell,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(totalWeight ~/ 2.205)} lb total',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (workout.exercises.length > 3)
                    Text(
                      '+${workout.exercises.length - 3} more',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
