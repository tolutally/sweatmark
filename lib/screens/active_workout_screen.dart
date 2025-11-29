import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
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
          onPressed: () => _showExitOptions(context, notifier),
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
                            child: GestureDetector(
                              onTap: () => _showRenameDialog(context, notifier),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      notifier.workoutName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    PhosphorIconsRegular.pencilSimple,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
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
                              'Add with AI',
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _RenameWorkoutDialog(
        initialName: notifier.workoutName,
        onSave: (newName) async {
          // Close dialog first, then update after a small delay
          Navigator.of(dialogContext).pop();
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            notifier.updateWorkoutName(newName);
          }
        },
      ),
    );
  }

  void _showExitOptions(BuildContext context, WorkoutNotifier notifier) {
    // Capture the parent context so we don't try to pop the route using the
    // bottom sheet's context after it has been dismissed.
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Exit Workout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsBold.trash,
                  color: Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
              title: const Text(
                'Discard Workout',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'All progress will be lost',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              onTap: () async {
                // Delete draft and reset workout without saving
                await notifier.deleteDraftWorkout();
                notifier.resetWorkout();
                Navigator.pop(sheetContext); // Close bottom sheet
                if (!mounted) return;
                Navigator.pop(parentContext); // Close workout screen
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsBold.floppyDisk,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              title: const Text(
                'Save for Later',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Continue this workout later',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              onTap: () async {
                await notifier.saveDraftWorkout();
                Navigator.pop(sheetContext); // Close bottom sheet
                if (!mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Workout saved for later'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.pop(parentContext); // Close workout screen
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ExerciseWorkoutCard extends StatefulWidget {
  final Exercise exercise;
  final dynamic log;
  final int exerciseIndex;

  const _ExerciseWorkoutCard({
    required this.exercise,
    required this.log,
    required this.exerciseIndex,
  });

  @override
  State<_ExerciseWorkoutCard> createState() => _ExerciseWorkoutCardState();
}

class _ExerciseWorkoutCardState extends State<_ExerciseWorkoutCard> {
  bool _isCollapsed = false;

  void _showExerciseMenu(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exercise.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(PhosphorIconsBold.info, color: Colors.white),
              title: const Text('Exercise Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                _showExerciseInfo(parentContext);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.copy, color: Colors.white),
              title: const Text('Duplicate Exercise', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                notifier.addExercise(widget.exercise);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Exercise duplicated')),
                );
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.trash, color: Colors.red),
              title: const Text('Remove Exercise', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                notifier.removeExercise(widget.exerciseIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExerciseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(widget.exercise.name, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Muscle Group',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.exercise.muscleGroup,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Equipment',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.exercise.equipment,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
              if (widget.exercise.instructions != null) const SizedBox(height: 16),
              if (widget.exercise.instructions != null) const Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.exercise.instructions != null) const SizedBox(height: 4),
              if (widget.exercise.instructions != null) Text(
                widget.exercise.instructions!,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSuperSetOptions(BuildContext context, WorkoutNotifier notifier, String exerciseId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Super Set Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(PhosphorIconsBold.plus),
              title: const Text('Create New Super Set'),
              subtitle: const Text('Group exercises together'),
              onTap: () {
                Navigator.pop(context);
                _showCreateSuperSetSheet(context, notifier, exerciseId);
              },
            ),
            if (notifier.currentWorkout?.superSets.isNotEmpty == true)
              ListTile(
                leading: const Icon(PhosphorIconsBold.arrowsClockwise),
                title: const Text('Add to Existing Super Set'),
                subtitle: const Text('Join an existing super set'),
                onTap: () {
                  Navigator.pop(context);
                  _showJoinSuperSetSheet(context, notifier, exerciseId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateSuperSetSheet(BuildContext context, WorkoutNotifier notifier, String exerciseId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuperSetCreationSheet(
        currentExerciseId: exerciseId,
        availableExercises: notifier.currentWorkout?.exercises ?? [],
        onCreateSuperSet: (exerciseIds) => notifier.createSuperSet(exerciseIds),
      ),
    );
  }

  void _showJoinSuperSetSheet(BuildContext context, WorkoutNotifier notifier, String exerciseId) {
    final superSets = notifier.currentWorkout?.superSets ?? [];
    if (superSets.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuperSetManagementSheet(
        superSet: superSets.first,
        onRemoveFromSuperSet: (id) => notifier.removeFromSuperSet(id),
        onReorderExercises: (exerciseIds) => notifier.reorderSuperSetExercises(superSets.first.id, exerciseIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final superSet = widget.log.superSetId != null 
        ? notifier.getSuperSet(widget.log.superSetId!) 
        : null;
    final isInSuperSet = superSet != null;
    final superSetPosition = widget.log.orderInSuperSet;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isInSuperSet ? Border.all(
          color: const Color(0xFF2BD4BD),
          width: 2,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Super Set Badge
          if (isInSuperSet)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2BD4BD),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsBold.arrowsClockwise,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Super Set ${superSetPosition != null ? (superSetPosition + 1) : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${superSet!.exerciseIds.length} exercises',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

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
                    widget.exercise.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.dotsThree, color: Colors.black54),
                  onPressed: () => _showExerciseMenu(context),
                ),
                IconButton(
                  icon: Icon(
                    _isCollapsed ? PhosphorIconsRegular.caretRight : PhosphorIconsRegular.caretDown,
                    color: Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCollapsed = !_isCollapsed;
                    });
                  },
                ),
              ],
            ),
          ),

          // Sets Section (collapsible)
          if (!_isCollapsed)
            Column(
              children: [
                // Sets Section Header
                if (widget.log.sets.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 60),
                        Expanded(
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
                ...widget.log.sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return Dismissible(
                key: Key('${widget.exercise.id}_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(PhosphorIconsBold.trash, color: Colors.white),
                ),
                onDismissed: (direction) {
                  notifier.removeSet(widget.exercise.id, index);
                },
                child: _SetRow(
                  setNumber: index + 1,
                  set: set,
                  exerciseId: widget.exercise.id,
                  setIndex: index,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(
                          exercise: widget.exercise,
                          exerciseLog: widget.log,
                          currentSetIndex: index,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),

            // Add Set / Super Set Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => notifier.addSet(widget.exercise.id),
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
                      onPressed: () => _showSuperSetOptions(context, notifier, widget.exercise.id),
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
                    onPressed: () {
                      // Mark all sets as complete
                      for (int i = 0; i < widget.log.sets.length; i++) {
                        if (!widget.log.sets[i].isCompleted) {
                          notifier.toggleSetCompletion(widget.exercise.id, i);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
              ],
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

class _RenameWorkoutDialog extends StatefulWidget {
  final String initialName;
  final Function(String) onSave;

  const _RenameWorkoutDialog({
    required this.initialName,
    required this.onSave,
  });

  @override
  State<_RenameWorkoutDialog> createState() => _RenameWorkoutDialogState();
}

class _RenameWorkoutDialogState extends State<_RenameWorkoutDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Workout'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Workout name'),
        onSubmitted: (value) {
          final newName = value.trim();
          if (newName.isNotEmpty) {
            widget.onSave(newName);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty) {
              widget.onSave(newName);
            } else {
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _showSuperSetOptions(BuildContext context, WorkoutNotifier notifier, String exerciseId) {
    final exercise = notifier.currentWorkout?.exercises.firstWhere((e) => e.exerciseId == exerciseId);
    if (exercise?.superSetId != null) {
      _showSuperSetManagement(context, notifier, exercise!.superSetId!);
    } else {
      _showSuperSetCreation(context, notifier, exerciseId);
    }
  }

  void _showSuperSetCreation(BuildContext context, WorkoutNotifier notifier, String currentExerciseId) {
    final availableExercises = notifier.getAvailableExercisesForSuperSet()
        .where((e) => e.exerciseId != currentExerciseId)
        .toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SuperSetCreationSheet(
        availableExercises: availableExercises,
        currentExerciseId: currentExerciseId,
        onCreateSuperSet: (exerciseIds) {
          notifier.createSuperSet([currentExerciseId, ...exerciseIds]);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Super set created!')),
          );
        },
      ),
    );
  }

  void _showSuperSetManagement(BuildContext context, WorkoutNotifier notifier, String superSetId) {
    final superSet = notifier.getSuperSet(superSetId);
    if (superSet == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SuperSetManagementSheet(
        superSet: superSet,
        onRemoveFromSuperSet: (exerciseId) {
          notifier.removeFromSuperSet(exerciseId);
          Navigator.pop(context);
        },
        onReorderExercises: (newOrder) {
          notifier.reorderSuperSetExercises(superSetId, newOrder);
        },
      ),
    );
  }
}

class _SuperSetCreationSheet extends StatefulWidget {
  final List<WorkoutExerciseLog> availableExercises;
  final String currentExerciseId;
  final Function(List<String>) onCreateSuperSet;

  const _SuperSetCreationSheet({
    required this.availableExercises,
    required this.currentExerciseId,
    required this.onCreateSuperSet,
  });

  @override
  State<_SuperSetCreationSheet> createState() => _SuperSetCreationSheetState();
}

class _SuperSetCreationSheetState extends State<_SuperSetCreationSheet> {
  final Set<String> _selectedExerciseIds = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Create Super Set',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select exercises to group together',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          if (widget.availableExercises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No available exercises to add to super set',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableExercises.length,
                itemBuilder: (context, index) {
                  final exercise = widget.availableExercises[index];
                  final isSelected = _selectedExerciseIds.contains(exercise.exerciseId);
                  
                  return ListTile(
                    title: Text(
                      exercise.exerciseId,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedExerciseIds.add(exercise.exerciseId);
                          } else {
                            _selectedExerciseIds.remove(exercise.exerciseId);
                          }
                        });
                      },
                      activeColor: const Color(0xFF2BD4BD),
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedExerciseIds.remove(exercise.exerciseId);
                        } else {
                          _selectedExerciseIds.add(exercise.exerciseId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedExerciseIds.isEmpty
                      ? null
                      : () => widget.onCreateSuperSet(_selectedExerciseIds.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2BD4BD),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Create Super Set (${_selectedExerciseIds.length + 1})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuperSetManagementSheet extends StatefulWidget {
  final SuperSet superSet;
  final Function(String) onRemoveFromSuperSet;
  final Function(List<String>) onReorderExercises;

  const _SuperSetManagementSheet({
    required this.superSet,
    required this.onRemoveFromSuperSet,
    required this.onReorderExercises,
  });

  @override
  State<_SuperSetManagementSheet> createState() => _SuperSetManagementSheetState();
}

class _SuperSetManagementSheetState extends State<_SuperSetManagementSheet> {
  late List<String> _exerciseOrder;

  @override
  void initState() {
    super.initState();
    _exerciseOrder = List.from(widget.superSet.exerciseIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Manage Super Set',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: _exerciseOrder.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _exerciseOrder.removeAt(oldIndex);
                  _exerciseOrder.insert(newIndex, item);
                });
                widget.onReorderExercises(_exerciseOrder);
              },
              itemBuilder: (context, index) {
                final exerciseId = _exerciseOrder[index];
                return ListTile(
                  key: ValueKey(exerciseId),
                  leading: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF2BD4BD),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    exerciseId,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, color: Colors.red),
                    onPressed: () => widget.onRemoveFromSuperSet(exerciseId),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
