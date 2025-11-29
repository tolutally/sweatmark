import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import '../services/pr_service.dart';

class PRHistoryScreen extends StatelessWidget {
  const PRHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutNotifier = context.watch<WorkoutNotifier>();
    final prService = PRService();
    
    // Calculate all PRs from workout history
    final prRecords = calculatePRHistory(workoutNotifier.workoutHistory, prService);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Records',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: prRecords.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.trophy,
                    size: 80,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No personal records yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete workouts to start tracking PRs',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black26,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: prRecords.length,
              itemBuilder: (context, index) {
                final pr = prRecords[index];
                return _PRCard(pr: pr);
              },
            ),
    );
  }
}

List<PRRecord> calculatePRHistory(List<WorkoutLog> history, PRService prService) {
    final Map<String, PRRecord> prMap = {};

    // Sort workouts by date (oldest first)
    final sortedHistory = List<WorkoutLog>.from(history)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final workout in sortedHistory) {
      if (workout.isTestData) continue;

      for (final exerciseLog in workout.exercises) {
        final best1RM = _calculateBest1RM(exerciseLog.sets);
        
        if (best1RM > 0) {
          final exerciseId = exerciseLog.exerciseId;
          
          // If no record exists or this is better, update it
          if (!prMap.containsKey(exerciseId) || best1RM > prMap[exerciseId]!.estimated1RM) {
            final exerciseName = _getExerciseName(exerciseId) ?? exerciseId;
            final muscleGroup = _getMuscleGroup(exerciseId) ?? 'Unknown';
            
            // Find the actual set that achieved this PR
            final prSet = exerciseLog.sets.firstWhere(
              (set) {
                if (set.weight != null && set.reps != null) {
                  final set1RM = set.weight! * (1 + set.reps! / 30.0);
                  return (set1RM - best1RM).abs() < 0.01;
                }
                return false;
              },
              orElse: () => exerciseLog.sets.first,
            );
            
            prMap[exerciseId] = PRRecord(
              exerciseId: exerciseId,
              exerciseName: exerciseName,
              muscleGroup: muscleGroup,
              weight: prSet.weight ?? 0,
              reps: prSet.reps ?? 0,
              estimated1RM: best1RM,
              achievedDate: workout.timestamp,
            );
          }
        }
      }
    }

    // Sort by date (newest first)
    final records = prMap.values.toList()
      ..sort((a, b) => b.achievedDate.compareTo(a.achievedDate));
    
  return records;
}

double _calculateBest1RM(List<WorkoutSet> sets) {
  double best1RM = 0;
  
  for (final set in sets) {
    if (set.weight != null && set.reps != null && set.weight! > 0 && set.reps! > 0) {
      final estimated1RM = set.weight! * (1 + set.reps! / 30.0);
      if (estimated1RM > best1RM) {
        best1RM = estimated1RM;
      }
    }
  }
  
  return best1RM;
}

String? _getExerciseName(String exerciseId) {
  try {
    final exercise = EXERCISE_LIBRARY.firstWhere((e) => e['id'] == exerciseId);
    return exercise['name'] as String?;
  } catch (e) {
    return null;
  }
}

String? _getMuscleGroup(String exerciseId) {
  try {
    final exercise = EXERCISE_LIBRARY.firstWhere((e) => e['id'] == exerciseId);
    return exercise['muscleGroup'] as String?;
  } catch (e) {
    return null;
  }
}

class PRRecord {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final int weight;
  final int reps;
  final double estimated1RM;
  final DateTime achievedDate;

  PRRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.weight,
    required this.reps,
    required this.estimated1RM,
    required this.achievedDate,
  });
}

class _PRCard extends StatelessWidget {
  final PRRecord pr;

  const _PRCard({required this.pr});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final prDate = DateTime(date.year, date.month, date.day);

    if (prDate == today) {
      return 'Today';
    } else if (prDate == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFB800)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.trophy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.exerciseName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pr.muscleGroup,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BEST SET',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${pr.weight} lb × ${pr.reps} reps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.black12,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EST. 1RM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black38,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${pr.estimated1RM.toStringAsFixed(1)} lb',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.calendar,
                  size: 14,
                  color: Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(pr.achievedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
