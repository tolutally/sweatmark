import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import '../widgets/schedule_bottom_sheet.dart';
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
        ],
      ),
      body: Column(
        children: [
          // Workout Header - Compact
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB84D), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    PhosphorIconsBold.barbell,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showRenameDialog(context, notifier),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                notifier.workoutName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              PhosphorIconsRegular.pencilSimple,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          ScheduleBottomSheet.show(
                            context,
                            workoutName: notifier.workoutName,
                            exercises: workout.exercises,
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'Set up schedule & repeat',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(PhosphorIconsRegular.caretRight, size: 12, color: Color(0xFF007AFF)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: workout.exercises.length + 2, // +1 for Add Button, +1 for Build For Me
              itemBuilder: (context, index) {
                // Add Exercise Button - Compact
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsBold.plus, color: Color(0xFF2BD4BD), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add Exercise',
                              style: TextStyle(
                                fontSize: 15,
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

                // Build For Me Button - Compact
                if (index == workout.exercises.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 16),
                    child: GestureDetector(
                      onTap: () {
                        // AI workout builder
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2BD4BD), Color(0xFF8EC5FC)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2BD4BD).withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsBold.sparkle, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add with AI',
                              style: TextStyle(
                                fontSize: 15,
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
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isRestTimerActive = false;
  bool _isRestTimerPaused = false;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer(int duration) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = duration;
      _isRestTimerActive = true;
      _isRestTimerPaused = false;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        _stopRestTimer();
      }
    });
  }

  void _pauseRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestTimerPaused = true;
    });
  }

  void _resumeRestTimer() {
    setState(() {
      _isRestTimerPaused = false;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        _stopRestTimer();
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestTimerActive = false;
      _isRestTimerPaused = false;
      _restSecondsRemaining = 0;
    });
  }

  String _formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

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

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final superSet = widget.log.superSetId != null 
        ? notifier.getSuperSet(widget.log.superSetId!) 
        : null;
    final isInSuperSet = superSet != null;
    final superSetPosition = widget.log.orderInSuperSet;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isInSuperSet ? Border.all(
          color: const Color(0xFF2BD4BD),
          width: 2,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
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
              decoration: const BoxDecoration(
                color: Color(0xFF2BD4BD),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
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
                    '${superSet.exerciseIds.length} exercises',
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
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                // Exercise icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(PhosphorIconsBold.barbell, size: 22, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                // Exercise name
                Expanded(
                  child: Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Menu button
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.dotsThree, color: Colors.black38, size: 22),
                  onPressed: () => _showExerciseMenu(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Collapse button
                IconButton(
                  icon: Icon(
                    _isCollapsed ? PhosphorIconsRegular.caretDown : PhosphorIconsRegular.check,
                    color: _isCollapsed ? Colors.black38 : const Color(0xFF007AFF),
                    size: 22,
                  ),
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          // Sets Section (collapsible)
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  // Column Headers
                  const Padding(
                    padding: EdgeInsets.only(left: 48, bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            'PREVIOUS',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'WEIGHT',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        SizedBox(
                          width: 50,
                          child: Text(
                            'REP',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sets List
                  ...widget.log.sets.asMap().entries.map((entry) {
                    final index = entry.key;
                    final set = entry.value;
                    return Dismissible(
                      key: Key('${widget.exercise.id}_set_$index'),
                      direction: DismissDirection.endToStart,
                      dismissThresholds: const {DismissDirection.endToStart: 0.4},
                      confirmDismiss: (direction) async {
                        // Show confirmation dialog instead of auto-dismissing
                        return await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              'Delete Set?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              'Remove set ${index + 1} from ${widget.exercise.name}?',
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (direction) {
                        notifier.removeSet(widget.exercise.id, index);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(PhosphorIconsBold.trash, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                      child: _SetRow(
                        setNumber: index + 1,
                        set: set,
                        exerciseId: widget.exercise.id,
                        setIndex: index,
                        isWarmup: index == 0 && set.weight != null && set.weight! < 50,
                        onSetCompleted: () {
                          final restDuration = context.read<SettingsNotifier>().restTimerDuration;
                          _startRestTimer(restDuration);
                        },
                      ),
                    );
                  }).toList(),

                  // Rest Timer Display
                  if (_isRestTimerActive)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2BD4BD).withOpacity(0.15),
                            const Color(0xFF8EC5FC).withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2BD4BD).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2BD4BD),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              PhosphorIconsBold.timer,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isRestTimerPaused ? 'Paused' : 'Rest Timer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isRestTimerPaused ? Colors.orange : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatRestTime(_restSecondsRemaining),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _isRestTimerPaused ? Colors.orange : const Color(0xFF2BD4BD),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Pause/Resume button
                          GestureDetector(
                            onTap: _isRestTimerPaused ? _resumeRestTimer : _pauseRestTimer,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isRestTimerPaused 
                                    ? const Color(0xFF2BD4BD) 
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _isRestTimerPaused 
                                    ? PhosphorIconsBold.play 
                                    : PhosphorIconsBold.pause,
                                size: 18,
                                color: _isRestTimerPaused ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Stop button
                          GestureDetector(
                            onTap: _stopRestTimer,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                PhosphorIconsBold.stop,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Compact Action Buttons Row
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Add Set button
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => notifier.addSet(widget.exercise.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIconsRegular.plusCircle, 
                                    color: Color(0xFF2BD4BD), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Set',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Divider
                        Container(width: 1, height: 24, color: Colors.black12),
                        // Super Set button
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Show super set options
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIconsRegular.arrowsClockwise, 
                                    color: Color(0xFF007AFF), size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Super Set',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Divider
                        Container(width: 1, height: 24, color: Colors.black12),
                        // Mark all complete button
                        GestureDetector(
                          onTap: () {
                            for (int i = 0; i < widget.log.sets.length; i++) {
                              if (!widget.log.sets[i].isCompleted) {
                                notifier.toggleSetCompletion(widget.exercise.id, i);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: const Icon(
                              PhosphorIconsBold.checks,
                              color: Color(0xFFB0B0B0),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
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
  final bool isWarmup;
  final VoidCallback? onSetCompleted;

  const _SetRow({
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    this.isWarmup = false,
    this.onSetCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Set type badge (W for warmup, or set number with x)
          _SetTypeBadge(
            setNumber: setNumber,
            isWarmup: isWarmup,
            isCompleted: set.isCompleted,
          ),
          const SizedBox(width: 8),
          // Previous value
          SizedBox(
            width: 70,
            child: Text(
              '--',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Weight input
          GestureDetector(
            onTap: () => _showWeightInput(context, set, exerciseId, setIndex),
            child: Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    set.weight?.toString() ?? '10',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'lb',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Reps input
          GestureDetector(
            onTap: () => _showRepsInput(context, set, exerciseId, setIndex),
            child: Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  set.reps?.toString() ?? '10',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Completion checkmark
          GestureDetector(
            onTap: () {
              final wasCompleted = set.isCompleted;
              notifier.toggleSetCompletion(exerciseId, setIndex);
              // Only start timer when marking as complete (not when unchecking)
              if (!wasCompleted && onSetCompleted != null) {
                onSetCompleted!();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: set.isCompleted ? const Color(0xFF2BD4BD) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: set.isCompleted ? const Color(0xFF2BD4BD) : const Color(0xFFD8D8D8),
                  width: 2,
                ),
              ),
              child: set.isCompleted
                  ? const Icon(PhosphorIconsBold.check, color: Colors.white, size: 18)
                  : Icon(PhosphorIconsRegular.check, color: Colors.grey[300], size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeightInput(BuildContext context, dynamic set, String exerciseId, int setIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NumberInputSheet(
        title: 'Weight',
        currentValue: set.weight?.toString() ?? '10',
        unit: 'lb',
        onValueChanged: (value) {
          final weight = int.tryParse(value) ?? 10;
          context.read<WorkoutNotifier>().updateSet(exerciseId, setIndex, weight, set.reps);
        },
      ),
    );
  }

  void _showRepsInput(BuildContext context, dynamic set, String exerciseId, int setIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NumberInputSheet(
        title: 'Reps',
        currentValue: set.reps?.toString() ?? '10',
        unit: '',
        onValueChanged: (value) {
          final reps = int.tryParse(value) ?? 10;
          context.read<WorkoutNotifier>().updateSet(exerciseId, setIndex, set.weight, reps);
        },
      ),
    );
  }
}

class _SetTypeBadge extends StatelessWidget {
  final int setNumber;
  final bool isWarmup;
  final bool isCompleted;

  const _SetTypeBadge({
    required this.setNumber,
    required this.isWarmup,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (isWarmup) {
      return Container(
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF2BD4BD) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'W',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isCompleted ? Colors.white : const Color(0xFF2BD4BD),
              ),
            ),
            // Green dots for warmup indicator
            Positioned(
              left: 2,
              top: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2BD4BD),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 2,
              bottom: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2BD4BD),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 40,
      height: 36,
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF2BD4BD) : const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          '${setNumber}x',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCompleted ? Colors.white : const Color(0xFF6B7B8C),
          ),
        ),
      ),
    );
  }
}

class _NumberInputSheet extends StatefulWidget {
  final String title;
  final String currentValue;
  final String unit;
  final Function(String) onValueChanged;

  const _NumberInputSheet({
    required this.title,
    required this.currentValue,
    required this.unit,
    required this.onValueChanged,
  });

  @override
  State<_NumberInputSheet> createState() => _NumberInputSheetState();
}

class _NumberInputSheetState extends State<_NumberInputSheet> {
  String _currentValue = '';
  bool _hasStartedTyping = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title and value display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currentValue.isEmpty ? '0' : _currentValue,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (widget.unit.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.unit,
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Number keypad
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  // Numbers 1-3
                  Row(
                    children: [
                      Expanded(child: _buildNumberKey('1')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('2')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('3')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Numbers 4-6
                  Row(
                    children: [
                      Expanded(child: _buildNumberKey('4')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('5')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('6')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Numbers 7-9
                  Row(
                    children: [
                      Expanded(child: _buildNumberKey('7')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('8')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('9')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Clear, 0, backspace
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _clear,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'C',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE57373),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNumberKey('0')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _backspace,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                PhosphorIconsRegular.backspace, 
                                size: 24,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2BD4BD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildNumberKey(String number) {
    return GestureDetector(
      onTap: () => _addNumber(number),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _addNumber(String number) {
    setState(() {
      if (!_hasStartedTyping) {
        _currentValue = number;
        _hasStartedTyping = true;
      } else if (_currentValue.length < 4) {
        _currentValue += number;
      }
    });
  }

  void _backspace() {
    if (_currentValue.isNotEmpty) {
      setState(() {
        _currentValue = _currentValue.substring(0, _currentValue.length - 1);
        if (_currentValue.isEmpty) {
          _currentValue = '0';
          _hasStartedTyping = false;
        }
      });
    }
  }

  void _clear() {
    setState(() {
      _currentValue = '0';
      _hasStartedTyping = false;
    });
  }

  void _submit() {
    widget.onValueChanged(_currentValue);
    Navigator.pop(context);
  }
}

class _SetTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SetTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.grey[400]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
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
