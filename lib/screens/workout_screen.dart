import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutNotifier = context.watch<WorkoutNotifier>();
    
    // Calculate stats from workout history
    final history = workoutNotifier.workoutHistory;
    int totalCalories = 0;
    double totalWeight = 0;
    int streak = 0;

    for (var workout in history) {
      // Calculate calories (placeholder calculation)
      totalCalories += 63;
      
      // Calculate total weight
      for (var exercise in workout.exercises) {
        for (var set in exercise.sets) {
          if (set.weight != null && set.reps != null) {
            totalWeight += (set.weight! * set.reps!);
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: const Color(0xFFF5F5F5),
              elevation: 0,
              pinned: true,
              title: const Text(
                'Stats',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsBold.fire,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            // Stats Cards Grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Streak',
                            value: '$streak days',
                            icon: PhosphorIconsBold.fire,
                            iconColor: const Color(0xFFFF6B6B),
                            iconBgColor: const Color(0xFFFFE5E5),
                            hasWarning: streak == 0,
                            warningText: 'Below Average',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Most Trained',
                            value: history.isEmpty ? 'None' : 'Chest',
                            icon: PhosphorIconsBold.heartbeat,
                            iconColor: const Color(0xFF34C759),
                            iconBgColor: const Color(0xFFD4F5E0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Calories',
                            value: '$totalCalories cal',
                            icon: PhosphorIconsBold.flame,
                            iconColor: const Color(0xFFFFB84D),
                            iconBgColor: const Color(0xFFFFF3E0),
                            showProgress: true,
                            progressValue: totalCalories / 100,
                            hasWarning: true,
                            warningText: 'Tap to improve accuracy...',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Weight',
                            value: '${(totalWeight ~/ 2.205).toStringAsFixed(0)} lb',
                            icon: PhosphorIconsBold.barbell,
                            iconColor: const Color(0xFF007AFF),
                            iconBgColor: const Color(0xFFE0F2FF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Workout This Week Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(workoutNotifier.elapsedSeconds / 3600).toStringAsFixed(0)} hr',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          'Workout This Week',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Workout History List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: history.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                PhosphorIconsRegular.barbell,
                                size: 64,
                                color: Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No workouts yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black38,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to start your first workout',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final workout = history[index];
                          return _WorkoutHistoryCard(workout: workout);
                        },
                        childCount: history.length,
                      ),
                    ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () {
          workoutNotifier.startWorkout();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
          );
        },
        child: const Icon(
          PhosphorIconsBold.plus,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool showProgress;
  final double progressValue;
  final bool hasWarning;
  final String warningText;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.showProgress = false,
    this.progressValue = 0.0,
    this.hasWarning = false,
    this.warningText = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          if (hasWarning && warningText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  PhosphorIconsBold.warning,
                  size: 14,
                  color: Color(0xFFFFB84D),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    warningText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFFB84D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFF5F5F5),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB84D)),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (hasWarning && warningText == 'Below Average') ...[
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(
                  PhosphorIconsRegular.globe,
                  size: 12,
                  color: Colors.black26,
                ),
                SizedBox(width: 4),
                Text(
                  'Below Average',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black26,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  final dynamic workout;

  const _WorkoutHistoryCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    // Get first two exercises to display
    final exercises = workout.exercises.take(2).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: exercises.map((exercise) {
          // Get exercise details from the log
          final set = exercise.sets.isNotEmpty ? exercise.sets.first : null;
          final reps = set?.reps ?? 10;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Exercise Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.barbell,
                    size: 24,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                // Exercise Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseId,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.globe,
                            size: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Top 12%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Reps Count
                Text(
                  '$reps reps',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
