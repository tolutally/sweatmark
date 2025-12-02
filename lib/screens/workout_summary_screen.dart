import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../state/recovery_notifier.dart';
import '../state/auth_notifier.dart';
import '../data/exercise_data.dart';
import '../theme/app_theme.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _showEnergyBanner = true;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  void _showRenameDialog(BuildContext context, WorkoutNotifier notifier) {
    final controller = TextEditingController(text: notifier.workoutName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workout name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                notifier.updateWorkoutName(controller.text.trim());
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final workout = notifier.currentWorkout;

    if (workout == null) {
      return const Scaffold(body: Center(child: Text('No workout data')));
    }

    // Calculate stats
    int totalWeight = 0;
    int pointsEarned = 32;
    int caloriesBurned = 63;

    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        if (set.weight != null && set.reps != null) {
          totalWeight += (set.weight! * set.reps!);
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD666),
              Color(0xFFF5F5F5),
            ],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Hero Image/Header
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'You left your mark!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: Colors.black54,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        notifier.workoutName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => _showRenameDialog(context, notifier),
                        icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                        label: const Text('Edit name'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black54,
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.clock, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(notifier.elapsedSeconds),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Cards & Content
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Energy Banner
                        if (_showEnergyBanner)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIconsBold.fire, color: AppColors.error, size: 24),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Energy',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _showEnergyBanner = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                        if (_showEnergyBanner) const SizedBox(height: 16),

                        // Body Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Update your body info to start tracking calories',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Update'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Points earned',
                                value: pointsEarned.toString(),
                                badge: '1',
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: _StatCard(
                                label: 'Streak',
                                value: '0 days',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Energy',
                                value: '$caloriesBurned cal',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                label: 'Total Weight',
                                value: '${(totalWeight ~/ 2.205)} lb',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Add Notes
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Add notes about this workout...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.black38),
                            ),
                          ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () async {
              // Save notes
              notifier.updateWorkoutNotes(_notesController.text);
              
              // Calculate impacted muscles
              final muscles = <String>{};
              for (final log in workout.exercises) {
                final exerciseData = EXERCISE_LIBRARY.firstWhere(
                  (e) => e['id'] == log.exerciseId,
                  orElse: () => {},
                );
                if (exerciseData.isNotEmpty) {
                  muscles.add(exerciseData['muscleGroup']);
                }
              }

              context.read<RecoveryNotifier>().updateRecovery(muscles.toList());
              
              final userId = context.read<AuthNotifier>().user?.uid;
              await notifier.finishWorkout(userId);
              
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
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
              'Done',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {},
        child: const Icon(PhosphorIconsBold.shareNetwork, color: Colors.black),
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? badge;

  const _StatCard({
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (label == 'Points earned')
                const Icon(
                  PhosphorIconsBold.fire,
                  size: 20,
                  color: Color(0xFF34C759),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
