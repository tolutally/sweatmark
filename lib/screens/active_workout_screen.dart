import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../data/exercise_data.dart';
import '../widgets/schedule_bottom_sheet.dart';
import '../services/notification_service.dart';
import 'library_screen.dart';
import 'workout_summary_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = context.read<SettingsNotifier>();

    if (state == AppLifecycleState.paused) {
      // App going to background
      if (settings.isResting && !settings.isPaused) {
        // Schedule notification for when timer completes (iOS)
        if (Platform.isIOS) {
          _notificationService.scheduleRestTimerCompleteNotification(
              settings.currentRestSeconds);
        }
        // For Android, update the notification with current time
        if (Platform.isAndroid) {
          _notificationService
              .showRestTimerNotification(settings.currentRestSeconds);
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground
      if (settings.isResting) {
        // Sync timer from wall-clock time
        settings.syncTimerFromBackground();
        // Cancel scheduled notification
        _notificationService.cancelScheduledRestTimerNotification();
        // Cancel ongoing timer notification
        _notificationService.cancelRestTimerNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final settings = context.watch<SettingsNotifier>();
    final workout = notifier.currentWorkout;

    if (workout == null) {
      return const Scaffold(body: Center(child: Text('No active workout')));
    }

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
            icon: const Icon(PhosphorIconsRegular.caretLeft,
                color: Colors.black87, size: 28),
            onPressed: () {
              // Save draft and go back without cancelling
              notifier.saveDraftWorkout();
              Navigator.pop(context);
            },
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
                  const Icon(PhosphorIconsBold.play,
                      color: Color(0xFF2BD4BD), size: 16),
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
                              Icon(PhosphorIconsRegular.caretRight,
                                  size: 12, color: Color(0xFF007AFF)),
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
                itemCount: workout.exercises.length +
                    2, // +1 for Add Button, +1 for Build For Me
                itemBuilder: (context, index) {
                  // Add Exercise Button - Compact
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: GestureDetector(
                        onTap: () async {
                          final Exercise? selected = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const LibraryScreen(isPicker: true)),
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
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsBold.plus,
                                  color: Color(0xFF2BD4BD), size: 18),
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
                                color: const Color(0xFF2BD4BD)
                                    .withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(PhosphorIconsBold.sparkle,
                                  color: Colors.white, size: 18),
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
                  final exercise = Exercise.fromJson(
                    exerciseData.isNotEmpty
                        ? exerciseData
                        : {
                            'id': log.exerciseId,
                            'name': log.exerciseName ?? 'Custom Exercise',
                            'muscleGroup': log.muscleGroup ?? 'Custom',
                            'equipment': log.equipment ?? 'Custom',
                          },
                  );

                  return _ExerciseWorkoutCard(
                    key: ValueKey(log.exerciseId),
                    exercise: exercise,
                    log: log,
                    exerciseIndex: index - 1,
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Global Rest Timer Overlay
            if (settings.isResting)
              _GlobalRestTimerOverlay(
                settings: settings,
                onDismiss: () => settings.stopRestTimer(),
              ),
            // Finish Workout Button - Clean design without white box
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    // More options button (discard/save)
                    GestureDetector(
                      onTap: () => _showExitOptions(context, notifier),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          PhosphorIconsBold.dotsThreeOutline,
                          color: Colors.black54,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Finish Workout Button - Full width
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showFinishWorkoutConfirmation(
                            context, notifier, workout),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Finish Workout',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              'Workout Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
                  color: Colors.black87,
                ),
              ),
              subtitle: const Text(
                'Delete this workout permanently',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              onTap: () async {
                // Delete draft and reset workout without saving
                await notifier.deleteDraftWorkout();
                notifier.resetWorkout();
                if (!context.mounted) return;
                Navigator.pop(sheetContext); // Close bottom sheet
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
                      color: Colors.black87,
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

  void _showFinishWorkoutConfirmation(
      BuildContext context, WorkoutNotifier notifier, dynamic workout) {
    // Calculate workout stats
    int totalSets = 0;
    int completedSets = 0;

    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        totalSets++;
        if (set.isCompleted) {
          completedSets++;
        }
      }
    }

    final hasIncompleteSets = completedSets < totalSets;
    final exerciseCount = workout.exercises.length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Finish Workout?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              // Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: PhosphorIconsBold.barbell,
                      value: exerciseCount.toString(),
                      label: 'Exercises',
                      color: const Color(0xFF2BD4BD),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    _StatItem(
                      icon: PhosphorIconsBold.checkCircle,
                      value: '$completedSets/$totalSets',
                      label: 'Sets Done',
                      color: hasIncompleteSets
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF34C759),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey[300]),
                    _StatItem(
                      icon: PhosphorIconsBold.timer,
                      value: _formatDuration(notifier.elapsedSeconds),
                      label: 'Duration',
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                ),
              ),

              // Warning if incomplete sets
              if (hasIncompleteSets) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsBold.warning,
                        color: Color(0xFFFF9500),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have ${totalSets - completedSets} incomplete ${(totalSets - completedSets) == 1 ? 'set' : 'sets'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext); // Close bottom sheet
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Finish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
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
    super.key,
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
              title: const Text('Exercise Info',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                _showExerciseInfo(parentContext);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.copy, color: Colors.white),
              title: const Text('Duplicate Exercise',
                  style: TextStyle(color: Colors.white)),
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
              title: const Text('Remove Exercise',
                  style: TextStyle(color: Colors.red)),
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
        title: Text(widget.exercise.name,
            style: const TextStyle(color: Colors.white)),
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
              if (widget.exercise.instructions != null)
                const SizedBox(height: 16),
              if (widget.exercise.instructions != null)
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (widget.exercise.instructions != null)
                const SizedBox(height: 4),
              if (widget.exercise.instructions != null)
                Text(
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
        border: isInSuperSet
            ? Border.all(
                color: const Color(0xFF2BD4BD),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  child: const Icon(PhosphorIconsBold.barbell,
                      size: 22, color: Colors.black54),
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
                  icon: const Icon(PhosphorIconsRegular.dotsThree,
                      color: Colors.black38, size: 22),
                  onPressed: () => _showExerciseMenu(context),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Collapse button
                IconButton(
                  icon: Icon(
                    _isCollapsed
                        ? PhosphorIconsRegular.caretDown
                        : PhosphorIconsRegular.check,
                    color:
                        _isCollapsed ? Colors.black38 : const Color(0xFF007AFF),
                    size: 22,
                  ),
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
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
                      dismissThresholds: const {
                        DismissDirection.endToStart: 0.4
                      },
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
                                  style: const TextStyle(
                                      fontSize: 15, color: Colors.black54),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          Colors.red.withValues(alpha: 0.1),
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
                            ) ??
                            false;
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
                            Icon(PhosphorIconsBold.trash,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                      child: _SetRow(
                        setNumber: index + 1,
                        set: set,
                        exerciseId: widget.exercise.id,
                        setIndex: index,
                        totalSets: widget.log.sets.length,
                        isWarmup: index == 0 &&
                            set.weight != null &&
                            set.weight! < 50,
                        superSetId: widget.log.superSetId,
                      ),
                    );
                  }).toList(),

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
                              _showSuperSetOptions(
                                  context, notifier, widget.exercise.id);
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
                                notifier.toggleSetCompletion(
                                    widget.exercise.id, i);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
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

class _SetRow extends StatefulWidget {
  final int setNumber;
  final dynamic set;
  final String exerciseId;
  final int setIndex;
  final int totalSets;
  final bool isWarmup;
  final String? superSetId;

  const _SetRow({
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    required this.totalSets,
    this.isWarmup = false,
    this.superSetId,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController =
        TextEditingController(text: widget.set.weight?.toString() ?? '');
    _repsController =
        TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when set data changes externally
    final newWeight = widget.set.weight?.toString() ?? '';
    final newReps = widget.set.reps?.toString() ?? '';
    if (_weightController.text != newWeight &&
        !_weightController.text.endsWith('.')) {
      _weightController.text = newWeight;
    }
    if (_repsController.text != newReps) {
      _repsController.text = newReps;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  /// Check if this is the last set that should skip the timer
  /// For supersets: only skip on last set of last exercise in the superset
  /// For standalone exercises: skip on last set
  bool _isLastSetOfBlock(BuildContext context) {
    final isLastSetOfExercise = widget.setIndex == widget.totalSets - 1;

    if (widget.superSetId == null) {
      // Standalone exercise - skip timer on last set
      return isLastSetOfExercise;
    }

    // For supersets, check if this is the last exercise in the superset
    final workout = context.read<WorkoutNotifier>().currentWorkout;
    if (workout == null) return isLastSetOfExercise;

    final superSet =
        workout.superSets.where((s) => s.id == widget.superSetId).firstOrNull;
    if (superSet == null) return isLastSetOfExercise;

    // Check if this exercise is the last in the superset
    final isLastExerciseInSuperSet = superSet.exerciseIds.isNotEmpty &&
        superSet.exerciseIds.last == widget.exerciseId;

    // Only skip timer on last set of last exercise in superset
    return isLastSetOfExercise && isLastExerciseInSuperSet;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final settings = context.read<SettingsNotifier>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Set type badge (W for warmup, or set number with x)
          _SetTypeBadge(
            setNumber: widget.setNumber,
            isWarmup: widget.isWarmup,
            isCompleted: widget.set.isCompleted,
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
          // Weight input - inline TextField
          Container(
            width: 80,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    onChanged: (val) {
                      final weight = double.tryParse(val);
                      context.read<WorkoutNotifier>().updateSet(
                          widget.exerciseId,
                          widget.setIndex,
                          weight,
                          widget.set.reps);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    'lb',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Reps input - inline TextField
          Container(
            width: 50,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              onChanged: (val) {
                final reps = int.tryParse(val);
                context.read<WorkoutNotifier>().updateSet(widget.exerciseId,
                    widget.setIndex, widget.set.weight, reps);
              },
            ),
          ),
          const Spacer(),
          // Completion checkmark
          GestureDetector(
            onTap: () {
              final wasCompleted = widget.set.isCompleted;
              notifier.toggleSetCompletion(widget.exerciseId, widget.setIndex);
              // Only start timer when marking as complete (not when unchecking)
              // and not on the last set of the block
              if (!wasCompleted && !_isLastSetOfBlock(context)) {
                settings.startRestTimer();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.set.isCompleted
                    ? const Color(0xFF2BD4BD)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.set.isCompleted
                      ? const Color(0xFF2BD4BD)
                      : const Color(0xFFD8D8D8),
                  width: 2,
                ),
              ),
              child: widget.set.isCompleted
                  ? const Icon(PhosphorIconsBold.check,
                      color: Colors.white, size: 18)
                  : Icon(PhosphorIconsRegular.check,
                      color: Colors.grey[300], size: 18),
            ),
          ),
        ],
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
          color:
              isCompleted ? const Color(0xFF2BD4BD) : const Color(0xFFE8F5E9),
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

void _showSuperSetOptions(
    BuildContext context, WorkoutNotifier notifier, String exerciseId) {
  final exercise = notifier.currentWorkout?.exercises
      .firstWhere((e) => e.exerciseId == exerciseId);
  if (exercise?.superSetId != null) {
    _showSuperSetManagement(context, notifier, exercise!.superSetId!);
  } else {
    _showSuperSetCreation(context, notifier, exerciseId);
  }
}

void _showSuperSetCreation(
    BuildContext context, WorkoutNotifier notifier, String currentExerciseId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _SuperSetExercisePickerScreen(
        currentExerciseId: currentExerciseId,
        onExercisesSelected: (exercises) {
          // Add selected exercises to workout first
          for (final exercise in exercises) {
            notifier.addExercise(exercise);
          }
          // Create the super set with current exercise + new exercises
          final exerciseIds = [
            currentExerciseId,
            ...exercises.map((e) => e.id)
          ];
          notifier.createSuperSet(exerciseIds);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Super set created!')),
          );
        },
      ),
    ),
  );
}

void _showSuperSetManagement(
    BuildContext context, WorkoutNotifier notifier, String superSetId) {
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

/// Full-screen exercise picker for creating super sets
class _SuperSetExercisePickerScreen extends StatefulWidget {
  final String currentExerciseId;
  final Function(List<Exercise>) onExercisesSelected;

  const _SuperSetExercisePickerScreen({
    required this.currentExerciseId,
    required this.onExercisesSelected,
  });

  @override
  State<_SuperSetExercisePickerScreen> createState() =>
      _SuperSetExercisePickerScreenState();
}

class _SuperSetExercisePickerScreenState
    extends State<_SuperSetExercisePickerScreen> {
  final List<Exercise> _selectedExercises = [];
  String _searchQuery = '';
  String _selectedMuscleGroup = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _showAllExercises = false;

  // Muscle group mappings for antagonist pairs
  static const Map<String, List<String>> _antagonistPairs = {
    'Chest': ['Back', 'Lats'],
    'Back': ['Chest'],
    'Lats': ['Chest'],
    'Biceps': ['Triceps'],
    'Triceps': ['Biceps'],
    'Quads': ['Hamstrings', 'Glutes'],
    'Hamstrings': ['Quads'],
    'Shoulders': ['Back', 'Lats'],
    'Abs': ['Lower Back'],
    'Lower Back': ['Abs'],
  };

  Exercise? get _currentExercise {
    final exerciseData = EXERCISE_LIBRARY.firstWhere(
      (e) => e['id'] == widget.currentExerciseId,
      orElse: () => <String, dynamic>{},
    );
    if (exerciseData.isEmpty) return null;
    return Exercise.fromJson(exerciseData);
  }

  String? get _currentMuscleGroup => _currentExercise?.muscleGroup;

  List<String> get _muscleGroups {
    final groups = EXERCISE_LIBRARY
        .map((e) => e['muscleGroup'] as String)
        .toSet()
        .toList();
    groups.sort();
    return ['All', ...groups];
  }

  /// Get suggested exercises based on antagonist muscle pairs
  List<Exercise> get _suggestedExercises {
    if (_currentMuscleGroup == null) return [];

    final antagonistGroups = _antagonistPairs[_currentMuscleGroup] ?? [];

    return EXERCISE_LIBRARY
        .where((e) {
          if (e['id'] == widget.currentExerciseId) return false;
          final muscleGroup = e['muscleGroup'] as String;
          return antagonistGroups.contains(muscleGroup);
        })
        .take(6)
        .map((e) => Exercise.fromJson(e))
        .toList();
  }

  /// Get exercises from the same muscle group (compound sets)
  List<Exercise> get _sameMuscleExercises {
    if (_currentMuscleGroup == null) return [];

    return EXERCISE_LIBRARY
        .where((e) {
          if (e['id'] == widget.currentExerciseId) return false;
          final muscleGroup = e['muscleGroup'] as String;
          return muscleGroup == _currentMuscleGroup;
        })
        .take(6)
        .map((e) => Exercise.fromJson(e))
        .toList();
  }

  List<Exercise> get _filteredExercises {
    return EXERCISE_LIBRARY
        .where((e) {
          if (e['id'] == widget.currentExerciseId) return false;

          final name = (e['name'] as String).toLowerCase();
          final muscleGroup = e['muscleGroup'] as String;

          final matchesSearch =
              _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
          final matchesMuscle = _selectedMuscleGroup == 'All' ||
              muscleGroup == _selectedMuscleGroup;

          return matchesSearch && matchesMuscle;
        })
        .map((e) => Exercise.fromJson(e))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildExerciseChip(Exercise exercise, {bool isCompact = false}) {
    final isSelected = _selectedExercises.any((e) => e.id == exercise.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedExercises.removeWhere((e) => e.id == exercise.id);
          } else {
            _selectedExercises.add(exercise);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2BD4BD) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF2BD4BD) : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(PhosphorIconsBold.check,
                  size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                exercise.name,
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseRow(Exercise exercise) {
    final isSelected = _selectedExercises.any((e) => e.id == exercise.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedExercises.removeWhere((e) => e.id == exercise.id);
          } else {
            _selectedExercises.add(exercise);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5F3) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2BD4BD) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2BD4BD).withValues(alpha: 0.15)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIconsBold.barbell,
                size: 20,
                color: isSelected ? const Color(0xFF2BD4BD) : Colors.black54,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? const Color(0xFF2BD4BD) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.equipment}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF2BD4BD) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF2BD4BD) : Colors.black26,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(PhosphorIconsBold.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSuggestions =
        _suggestedExercises.isNotEmpty || _sameMuscleExercises.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.x,
              color: Colors.black87, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Super Set',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedExercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  widget.onExercisesSelected(_selectedExercises);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2BD4BD),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Done (${_selectedExercises.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected exercises preview (compact)
          if (_selectedExercises.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsBold.arrowsClockwise,
                      color: Color(0xFF2BD4BD), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Current exercise
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2BD4BD)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentExercise?.name ?? 'Current',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2BD4BD),
                              ),
                            ),
                          ),
                          ..._selectedExercises.map((exercise) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selectedExercises.remove(exercise)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(PhosphorIconsBold.x,
                                          size: 12, color: Colors.black45),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: _showAllExercises || !hasSuggestions
                ? _buildAllExercisesView()
                : _buildSuggestionsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Antagonist pair suggestions
          if (_suggestedExercises.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(PhosphorIconsBold.lightningA,
                      size: 16, color: Color(0xFF1976D2)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Antagonist Pairs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Opposite muscle groups for balanced training',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedExercises
                  .map((e) => _buildExerciseChip(e))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Same muscle group suggestions
          if (_sameMuscleExercises.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(PhosphorIconsBold.fire,
                      size: 16, color: Color(0xFFE65100)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compound Set',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Same muscle (${_currentMuscleGroup}) for intensity',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sameMuscleExercises
                  .map((e) => _buildExerciseChip(e))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Browse all button
          GestureDetector(
            onTap: () => setState(() => _showAllExercises = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsRegular.magnifyingGlass,
                      size: 18, color: Colors.black54),
                  SizedBox(width: 8),
                  Text(
                    'Browse All Exercises',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAllExercisesView() {
    return Column(
      children: [
        // Back to suggestions button (if we have suggestions)
        if (_suggestedExercises.isNotEmpty || _sameMuscleExercises.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GestureDetector(
              onTap: () => setState(() => _showAllExercises = false),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.arrowLeft,
                      size: 16, color: Color(0xFF2BD4BD)),
                  const SizedBox(width: 6),
                  const Text(
                    'Back to Suggestions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2BD4BD),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 15),
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass,
                    color: Colors.black38, size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        // Muscle group filter chips
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _muscleGroups.length,
            itemBuilder: (context, index) {
              final group = _muscleGroups[index];
              final isSelected = _selectedMuscleGroup == group;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMuscleGroup = group),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFF2BD4BD) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2BD4BD)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      group,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Exercise list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredExercises.length,
            itemBuilder: (context, index) {
              final exercise = _filteredExercises[index];
              return _buildExerciseRow(exercise);
            },
          ),
        ),
      ],
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
  State<_SuperSetManagementSheet> createState() =>
      _SuperSetManagementSheetState();
}

class _SuperSetManagementSheetState extends State<_SuperSetManagementSheet> {
  late List<String> _exerciseOrder;

  @override
  void initState() {
    super.initState();
    _exerciseOrder = List.from(widget.superSet.exerciseIds);
  }

  String _getExerciseNameById(BuildContext context, String exerciseId) {
    final notifier = context.read<WorkoutNotifier>();
    final exercise = notifier.currentWorkout?.exercises.firstWhere(
      (e) => e.exerciseId == exerciseId,
      orElse: () => WorkoutExerciseLog(exerciseId: exerciseId, sets: []),
    );
    return exercise?.exerciseName ?? exerciseId;
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
                    _getExerciseNameById(context, exerciseId),
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

/// Global rest timer overlay that appears at the bottom of the screen
/// Visible regardless of scroll position
class _GlobalRestTimerOverlay extends StatelessWidget {
  final SettingsNotifier settings;
  final VoidCallback onDismiss;

  const _GlobalRestTimerOverlay({
    required this.settings,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2BD4BD).withValues(alpha: 0.95),
            const Color(0xFF1FA89A).withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2BD4BD).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            // Timer icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                PhosphorIconsBold.timer,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Timer display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.isPaused ? 'PAUSED' : 'REST TIMER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settings.formatRestTime(settings.currentRestSeconds),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            // -15s button
            GestureDetector(
              onTap: () => settings.adjustRestTime(-15),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    '-15',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // +15s button
            GestureDetector(
              onTap: () => settings.adjustRestTime(15),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    '+15',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Pause/Resume button
            GestureDetector(
              onTap: () {
                if (settings.isPaused) {
                  settings.resumeRestTimer();
                } else {
                  settings.pauseRestTimer();
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  settings.isPaused
                      ? PhosphorIconsBold.play
                      : PhosphorIconsBold.pause,
                  color: const Color(0xFF2BD4BD),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Stop/Dismiss button
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  PhosphorIconsBold.x,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
