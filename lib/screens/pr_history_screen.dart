import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import '../services/pr_service.dart';
import '../theme/app_theme.dart';

class PRHistoryScreen extends StatefulWidget {
  const PRHistoryScreen({super.key});

  @override
  State<PRHistoryScreen> createState() => _PRHistoryScreenState();
}

class _PRHistoryScreenState extends State<PRHistoryScreen> {
  String _selectedMuscleGroup = 'All';
  String _selectedDateFilter = 'All Time';

  final List<String> _muscleGroups = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
  ];

  final List<String> _dateFilters = [
    'All Time',
    'This Week',
    'This Month',
    'This Year',
  ];

  List<PRRecord> _filterRecords(List<PRRecord> records) {
    var filtered = records;

    // Filter by muscle group
    if (_selectedMuscleGroup != 'All') {
      filtered = filtered.where((pr) => pr.muscleGroup == _selectedMuscleGroup).toList();
    }

    // Filter by date
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((pr) => pr.achievedDate.isAfter(weekAgo)).toList();
        break;
      case 'This Month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filtered = filtered.where((pr) => pr.achievedDate.isAfter(monthAgo)).toList();
        break;
      case 'This Year':
        final yearStart = DateTime(now.year, 1, 1);
        filtered = filtered.where((pr) => pr.achievedDate.isAfter(yearStart)).toList();
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final workoutNotifier = context.watch<WorkoutNotifier>();
    final prService = PRService();
    final allRecords = calculatePRHistory(workoutNotifier.workoutHistory, prService);
    final filteredRecords = _filterRecords(allRecords);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
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
        body: Column(
          children: [
            // Muscle Group Filter
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _muscleGroups.length,
                itemBuilder: (context, index) {
                  final group = _muscleGroups[index];
                  final isSelected = group == _selectedMuscleGroup;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(group),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedMuscleGroup = group),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.brandTeal.withOpacity(0.2),
                      checkmarkColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.brandTeal : Colors.black54,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.brandTeal : Colors.black12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Date Filter
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _dateFilters.length,
                itemBuilder: (context, index) {
                  final filter = _dateFilters[index];
                  final isSelected = filter == _selectedDateFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedDateFilter = filter),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black54,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // PR Count Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${filteredRecords.length} Personal Record${filteredRecords.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedMuscleGroup != 'All' || _selectedDateFilter != 'All Time')
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedMuscleGroup = 'All';
                        _selectedDateFilter = 'All Time';
                      }),
                      child: const Text(
                        'Clear Filters',
                        style: TextStyle(fontSize: 12, color: AppColors.brandTeal),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grid or Empty State
            Expanded(
              child: filteredRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIconsRegular.trophy,
                            size: 80,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            allRecords.isEmpty
                                ? 'No personal records yet'
                                : 'No PRs match your filters',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            allRecords.isEmpty
                                ? 'Complete workouts to start tracking PRs'
                                : 'Try adjusting your filters',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        return _PRGridTile(pr: filteredRecords[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<PRRecord> calculatePRHistory(
    List<WorkoutLog> history, PRService prService) {
  // Use Map to ensure only ONE record per exercise (deduplicated by exerciseId)
  // Key = exerciseId, Value = current best PRRecord for that exercise
  final Map<String, PRRecord> prMap = {};

  // Sort workouts chronologically (oldest first) so we can track progression
  final sortedHistory = List<WorkoutLog>.from(history)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  for (final workout in sortedHistory) {
    if (workout.isTestData) continue;

    for (final exerciseLog in workout.exercises) {
      final best1RM = _calculateBest1RM(exerciseLog.sets);

      if (best1RM > 0) {
        final exerciseId = exerciseLog.exerciseId;

        // Only update if: 1) First time seeing this exercise, OR 2) This beats/ties previous best
        // Using >= ensures ties update to most recent date (shows consistent performance)
        if (!prMap.containsKey(exerciseId) ||
            best1RM >= prMap[exerciseId]!.estimated1RM) {
          // Use stored name from workout log first, then fallback to EXERCISE_LIBRARY
          final exerciseName = exerciseLog.exerciseName ?? _getExerciseName(exerciseId) ?? exerciseId;
          final muscleGroup = exerciseLog.muscleGroup ?? _getMuscleGroup(exerciseId) ?? 'Unknown';

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

          // Replace (not append) - ensures only latest/best PR per exercise
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

  // Sort by date (newest first) - shows most recent PRs at top
  final records = prMap.values.toList()
    ..sort((a, b) => b.achievedDate.compareTo(a.achievedDate));

  return records;
}

double _calculateBest1RM(List<WorkoutSet> sets) {
  double best1RM = 0;

  for (final set in sets) {
    if (set.weight != null &&
        set.reps != null &&
        set.weight! > 0 &&
        set.reps! > 0) {
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
  final double weight;
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

class _PRGridTile extends StatelessWidget {
  final PRRecord pr;

  const _PRGridTile({required this.pr});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final prDate = DateTime(date.year, date.month, date.day);

    if (prDate == today) return 'Today';
    if (prDate == yesterday) return 'Yesterday';

    final diff = today.difference(prDate).inDays;
    if (diff < 7) return '${diff}d ago';
    if (diff < 30) return '${(diff / 7).floor()}w ago';

    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${monthNames[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trophy Icon & PR Badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), AppColors.warning],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.trophy,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Exercise Name
            Text(
              pr.exerciseName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              pr.muscleGroup,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black38,
              ),
            ),
            const Spacer(),
            // Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pr.estimated1RM.toStringAsFixed(0)} lb',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '${pr.weight.toStringAsFixed(0)} × ${pr.reps} reps',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Date
            Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.calendar,
                  size: 12,
                  color: Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(pr.achievedDate),
                  style: const TextStyle(
                    fontSize: 11,
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
