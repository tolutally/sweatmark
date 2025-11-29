import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutNotifier = context.watch<WorkoutNotifier>();
    
    // Calculate stats from workout history
    final history = workoutNotifier.workoutHistory;
    int totalTime = 0;
    double totalWeight = 0;
    int streak = 0;

    for (var workout in history) {
      // Calculate total time in minutes
      totalTime += (workout.durationSeconds / 60).round();
      
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
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
                            label: 'Total Time',
                            value: '$totalTime min',
                            icon: PhosphorIconsBold.clock,
                            iconColor: const Color(0xFFFFB84D),
                            iconBgColor: const Color(0xFFFFF3E0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Muscle Breakdown Section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _MuscleBreakdownSection(workoutHistory: history),
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
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                PhosphorIconsRegular.barbell,
                                size: 64,
                                color: Colors.black26,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No workouts yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black38,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
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
  final bool hasWarning;
  final String warningText;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
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
            const Row(
              children: [
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
  final WorkoutLog workout;

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
        children: exercises.map<Widget>((exercise) {
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
                      const Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.globe,
                            size: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          SizedBox(width: 4),
                          Text(
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

class _MuscleBreakdownSection extends StatelessWidget {
  final List<WorkoutLog> workoutHistory;

  const _MuscleBreakdownSection({required this.workoutHistory});

  Map<String, int> _getWeeklyMuscleFrequency() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weeklyWorkouts = workoutHistory.where((w) => w.timestamp.isAfter(weekAgo)).toList();
    
    final muscleCount = <String, int>{};
    
    for (final workout in weeklyWorkouts) {
      for (final exercise in workout.exercises) {
        final exerciseData = EXERCISE_LIBRARY.firstWhere(
          (e) => e['id'] == exercise.exerciseId,
          orElse: () => {},
        );
        if (exerciseData.isNotEmpty) {
          final muscleGroup = exerciseData['muscleGroup'] as String;
          muscleCount[muscleGroup] = (muscleCount[muscleGroup] ?? 0) + 1;
        }
      }
    }
    
    return muscleCount;
  }

  IconData _getMuscleIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return PhosphorIconsBold.heart;
      case 'back':
      case 'lats':
      case 'lower back':
        return PhosphorIconsBold.arrowBendUpLeft;
      case 'shoulders':
        return PhosphorIconsBold.mountains;
      case 'arms':
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return PhosphorIconsBold.hand;
      case 'legs':
      case 'quads':
      case 'hamstrings':
      case 'calves':
        return PhosphorIconsBold.footprints;
      case 'abs':
      case 'core':
        return PhosphorIconsBold.diamond;
      default:
        return PhosphorIconsBold.barbell;
    }
  }

  Color _getMuscleColor(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'chest':
        return const Color(0xFFFF6B6B);
      case 'back':
      case 'lats':
      case 'lower back':
        return const Color(0xFF007AFF);
      case 'shoulders':
        return const Color(0xFFFFB84D);
      case 'arms':
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return const Color(0xFF34C759);
      case 'legs':
      case 'quads':
      case 'hamstrings':
      case 'calves':
        return const Color(0xFF9F44D3);
      case 'abs':
      case 'core':
        return const Color(0xFF2BD4BD);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleFrequency = _getWeeklyMuscleFrequency();
    
    if (muscleFrequency.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'Weekly Muscle Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'None',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final sortedMuscles = muscleFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final maxCount = sortedMuscles.first.value;
    final totalCount = muscleFrequency.values.reduce((a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Muscle Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedMuscles.map((entry) {
            final muscleGroup = entry.key;
            final count = entry.value;
            final percentage = ((count / totalCount) * 100).round();
            final barWidth = count / maxCount;
            final color = _getMuscleColor(muscleGroup);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getMuscleIcon(muscleGroup),
                      color: color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              muscleGroup,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: barWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
