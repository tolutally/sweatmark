import '../widgets/personal_records.dart';
import '../widgets/exercise_media.dart';
import '../widgets/cardio_details_button.dart';
import 'exercise_info_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../state/workout_notifier.dart';
import '../state/auth_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/exercise_db_notifier.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../models/user_settings.dart';
import '../data/exercise_data.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'library_screen.dart';
import 'exercise_progress_screen.dart';
import 'workout_summary_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  bool _saving = false;
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
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const CircleBorder(),
            ),
            icon: Icon(PhosphorIconsRegular.caretLeft,
                color: Theme.of(context).colorScheme.onSurface, size: 28),
            onPressed: () {
              // Save draft and go back without cancelling
              notifier.saveDraftWorkout();
              Navigator.pop(context);
            },
          ),
          actions: [
            Semantics(
              button: notifier.isTimerPaused,
              label: notifier.isTimerPaused
                  ? 'Workout timer paused. Resume timer'
                  : 'Workout timer',
              child: GestureDetector(
                onTap: notifier.isTimerPaused ? notifier.resumeTimer : null,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: notifier.isTimerPaused
                        ? AppColors.lime
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          notifier.isTimerPaused
                              ? PhosphorIconsBold.pause
                              : PhosphorIconsBold.play,
                          color: notifier.isTimerPaused
                              ? AppColors.ink
                              : Theme.of(context).colorScheme.primary,
                          size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(notifier.elapsedSeconds),
                        style: TextStyle(
                          color: notifier.isTimerPaused
                              ? AppColors.ink
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              // Workout Header - Compact
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PhosphorIconsBold.barbell,
                        color: Theme.of(context).colorScheme.onSurface,
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
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  PhosphorIconsRegular.pencilSimple,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (notifier.isTimerPaused) _PausedTimerBanner(notifier),

              // Exercise List
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Build display items: either regular exercises or combined supersets
                    final displayItems = <Widget>[];
                    final renderedSuperSets = <String>{};

                    // Add Exercise Button first
                    displayItems.add(
                      Padding(
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
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .shadow
                                      .withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIconsBold.plus,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add Exercise',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    // Process exercises
                    for (int i = 0; i < workout.exercises.length; i++) {
                      final log = workout.exercises[i];

                      // Check if this exercise is part of a superset
                      if (log.superSetId != null) {
                        // Skip if we already rendered this superset
                        if (renderedSuperSets.contains(log.superSetId)) {
                          continue;
                        }

                        // Get the superset
                        final superSet = notifier.getSuperSet(log.superSetId!);
                        if (superSet != null) {
                          // Gather all exercises in this superset
                          final superSetExercises =
                              <(WorkoutExerciseLog, Exercise, int)>[];

                          for (int j = 0; j < workout.exercises.length; j++) {
                            final exerciseLog = workout.exercises[j];
                            if (exerciseLog.superSetId == log.superSetId) {
                              final exerciseData = EXERCISE_LIBRARY.firstWhere(
                                (e) => e['id'] == exerciseLog.exerciseId,
                                orElse: () => {},
                              );
                              final exercise = Exercise.fromJson(
                                exerciseData.isNotEmpty
                                    ? {
                                        ...exerciseData,
                                        'exerciseType':
                                            exerciseLog.exerciseType ??
                                                exerciseData['exerciseType'],
                                        'gifUrl': exerciseLog.gifUrl ??
                                            exerciseData['gifUrl']
                                      }
                                    : {
                                        'id': exerciseLog.exerciseId,
                                        'name': exerciseLog.exerciseName ??
                                            'Custom Exercise',
                                        'muscleGroup':
                                            exerciseLog.muscleGroup ?? 'Custom',
                                        'equipment':
                                            exerciseLog.equipment ?? 'Custom',
                                        'exerciseType':
                                            exerciseLog.exerciseType ??
                                                exerciseData['exerciseType'],
                                        'gifUrl': exerciseLog.gifUrl ??
                                            exerciseData['gifUrl'],
                                      },
                              );
                              superSetExercises.add((exerciseLog, exercise, j));
                            }
                          }

                          // Sort by orderInSuperSet
                          superSetExercises.sort((a, b) =>
                              (a.$1.orderInSuperSet ?? 0)
                                  .compareTo(b.$1.orderInSuperSet ?? 0));

                          // Add the combined superset card
                          displayItems.add(
                            _SuperSetWorkoutCard(
                              key: ValueKey('superset_${superSet.id}'),
                              superSet: superSet,
                              exercises: superSetExercises,
                            ),
                          );

                          // Mark this superset as rendered
                          renderedSuperSets.add(log.superSetId!);
                        }
                      } else {
                        // Regular exercise card
                        final exerciseData = EXERCISE_LIBRARY.firstWhere(
                          (e) => e['id'] == log.exerciseId,
                          orElse: () => {},
                        );
                        final exercise = Exercise.fromJson(
                          exerciseData.isNotEmpty
                              ? {
                                  ...exerciseData,
                                  'exerciseType': log.exerciseType ??
                                      exerciseData['exerciseType'],
                                  'gifUrl': log.gifUrl ?? exerciseData['gifUrl']
                                }
                              : {
                                  'id': log.exerciseId,
                                  'name': log.exerciseName ?? 'Custom Exercise',
                                  'muscleGroup': log.muscleGroup ?? 'Custom',
                                  'equipment': log.equipment ?? 'Custom',
                                  'exerciseType': log.exerciseType ??
                                      exerciseData['exerciseType'],
                                  'gifUrl':
                                      log.gifUrl ?? exerciseData['gifUrl'],
                                },
                        );

                        displayItems.add(
                          _ExerciseWorkoutCard(
                            key: ValueKey(log.exerciseId),
                            exercise: exercise,
                            log: log,
                            exerciseIndex: i,
                          ),
                        );
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: displayItems,
                    );
                  },
                ),
              ),
            ],
          ),
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
            // Floating AI Button & Finish Workout Row
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    // More options button (discard/save)
                    GestureDetector(
                      onTap: () => _showExitOptions(context, notifier),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .shadow
                                  .withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          PhosphorIconsBold.dotsThreeOutline,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // The save action uses the shared primary-button treatment.
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _showFinishWorkoutConfirmation(
                            context, notifier, workout),
                        child: Text(_saving ? 'Saving…' : 'Finish & save'),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              'Workout Options',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsBold.trash,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
              ),
              title: Text(
                'Discard Workout',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Delete this workout permanently',
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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

  Future<void> _showFinishWorkoutConfirmation(
      BuildContext context, WorkoutNotifier notifier, dynamic workout) async {
    if (_saving || workout == null) return;
    final sets = (workout as WorkoutLog)
        .exercises
        .expand((e) => e.sets)
        .where((s) => !s.isSuperSetRest)
        .toList();
    if (!sets.any((s) => s.isCompleted)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete at least one set before saving.')));
      return;
    }
    if (sets.any((s) => !s.isCompleted)) {
      final finish = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('Unfinished sets'),
                content: const Text(
                    'Save your completed sets and leave unfinished sets out?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep logging')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Finish & save'))
                ],
              ));
      if (finish != true || !context.mounted) return;
    }
    setState(() => _saving = true);
    final finished = WorkoutLog(
        workoutName: notifier.workoutName,
        timestamp: workout.timestamp,
        durationSeconds: notifier.elapsedSeconds,
        notes: notifier.workoutNotes,
        superSets: workout.superSets,
        exercises: workout.exercises
            .where((e) => e.sets.any((s) => s.isCompleted))
            .map((e) => WorkoutExerciseLog(
                  exerciseId: e.exerciseId,
                  exerciseName: e.exerciseName,
                  muscleGroup: e.muscleGroup,
                  equipment: e.equipment,
                  gifUrl: e.gifUrl,
                  superSetId: e.superSetId,
                  orderInSuperSet: e.orderInSuperSet,
                  sets: e.sets
                      .where((s) => s.isCompleted && !s.isSuperSetRest)
                      .map((s) => s.copyWith())
                      .toList(),
                ))
            .toList());
    try {
      await notifier.finishWorkoutWithData(finished, finished.durationSeconds,
          finished.notes ?? '', context.read<AuthNotifier>().user?.uid);
      if (!context.mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  WorkoutSummaryScreen(completedWorkout: finished)));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not save on this device. Your workout is still here. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Combined card for displaying all exercises in a superset
class _SuperSetWorkoutCard extends StatefulWidget {
  final SuperSet superSet;
  final List<(WorkoutExerciseLog log, Exercise exercise, int exerciseIndex)>
      exercises;

  const _SuperSetWorkoutCard({
    super.key,
    required this.superSet,
    required this.exercises,
  });

  @override
  State<_SuperSetWorkoutCard> createState() => _SuperSetWorkoutCardState();
}

class _SuperSetWorkoutCardState extends State<_SuperSetWorkoutCard> {
  // Get collapsed state from notifier using superset ID
  bool get _isCollapsed {
    final notifier = context.read<WorkoutNotifier>();
    return notifier.isExerciseCollapsed('superset_${widget.superSet.id}');
  }

  void _toggleCollapsed() {
    final notifier = context.read<WorkoutNotifier>();
    notifier.toggleExerciseCollapsed('superset_${widget.superSet.id}');
  }

  /// Get the maximum number of sets across all exercises
  int get _maxSets {
    int max = 0;
    for (final item in widget.exercises) {
      if (item.$1.sets.length > max) {
        max = item.$1.sets.length;
      }
    }
    return max;
  }

  /// Build alternating sets list (A1, B1, A2, B2, etc.)
  List<
      ({
        WorkoutExerciseLog log,
        Exercise exercise,
        int setIndex,
        int exerciseIndex
      })> get _alternatingSetsList {
    final result = <({
      WorkoutExerciseLog log,
      Exercise exercise,
      int setIndex,
      int exerciseIndex
    })>[];
    final maxSets = _maxSets;

    for (int setIdx = 0; setIdx < maxSets; setIdx++) {
      for (final item in widget.exercises) {
        if (setIdx < item.$1.sets.length) {
          result.add((
            log: item.$1,
            exercise: item.$2,
            setIndex: setIdx,
            exerciseIndex: item.$3,
          ));
        }
      }
    }
    return result;
  }

  void _showSuperSetMenu(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Super Set',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(PhosphorIconsBold.arrowsOutLineVertical,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text('Reorder Exercises',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSuperSetManagement(context, notifier, widget.superSet.id);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIconsBold.x,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Break Super Set',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                // Remove all exercises from superset
                for (final item in widget.exercises) {
                  notifier.removeFromSuperSet(item.$1.exerciseId);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Super set broken apart')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final exerciseCount = widget.exercises.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Super Set Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsBold.arrowsClockwise,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Super Set · $exerciseCount exercises',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Menu button
                GestureDetector(
                  onTap: () => _showSuperSetMenu(context),
                  child: Icon(
                    PhosphorIconsRegular.dotsThree,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                // Collapse button
                GestureDetector(
                  onTap: _toggleCollapsed,
                  child: Icon(
                    _isCollapsed
                        ? PhosphorIconsRegular.caretDown
                        : PhosphorIconsRegular.check,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          // Exercise list (mini headers)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: widget.exercises.map((item) {
                final exercise = item.$2;
                final isLast = item == widget.exercises.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Row(
                    children: [
                      // Exercise image/icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: exercise.hasGif
                            ? ExerciseMedia(
                                imageUrl: exercise.gifUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Center(
                                  child: Text(exercise.exerciseType.icon,
                                      style: const TextStyle(fontSize: 16)),
                                ),
                              )
                            : Center(
                                child: Text(exercise.exerciseType.icon,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BestRecordBadge(exercise.id),
                              Text(
                                exercise.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]),
                      ),
                      // Order label (A, B, C...)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          String.fromCharCode(65 +
                              widget.exercises.indexOf(item)), // A, B, C...
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Alternating Sets Section (collapsible)
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  for (final entry in widget.exercises)
                    if (entry.$1.exerciseType == 'cardio' ||
                        entry.$2.exerciseType == ExerciseType.cardio)
                      CardioDetailsButton(exercise: entry.$1),
                  // Column Headers
                  Padding(
                    padding: EdgeInsets.only(left: 56, bottom: 8, right: 48),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'WEIGHT',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'REPS',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  for (final item in widget.exercises)
                    PreviousSets(exerciseId: item.$1.exerciseId),
                  // Alternating Sets List
                  ..._alternatingSetsList.map((item) {
                    final exerciseLetter = String.fromCharCode(65 +
                        widget.exercises.indexWhere(
                            (e) => e.$1.exerciseId == item.log.exerciseId));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SuperSetSetRow(
                        exerciseLetter: exerciseLetter,
                        setNumber: item.setIndex + 1,
                        set: item.log.sets[item.setIndex],
                        exerciseId: item.log.exerciseId,
                        setIndex: item.setIndex,
                        exerciseName: item.exercise.name,
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Add Set Button (adds to ALL exercises)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () =>
                          notifier.addSetToSuperSet(widget.superSet.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsRegular.plusCircle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add Set to All',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
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
  }
}

/// Set row for superset with exercise label
class _SuperSetSetRow extends StatefulWidget {
  final String exerciseLetter;
  final int setNumber;
  final dynamic set;
  final String exerciseId;
  final int setIndex;
  final String exerciseName;

  const _SuperSetSetRow({
    required this.exerciseLetter,
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    required this.exerciseName,
  });

  @override
  State<_SuperSetSetRow> createState() => _SuperSetSetRowState();
}

class _SuperSetSetRowState extends State<_SuperSetSetRow> {
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
  void didUpdateWidget(covariant _SuperSetSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set != widget.set) {
      _weightController.text = widget.set.weight?.toString() ?? '';
      _repsController.text = widget.set.reps?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final isCompleted = widget.set.isCompleted;

    return GestureDetector(
      onTap: () =>
          notifier.toggleSetCompletion(widget.exerciseId, widget.setIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppDesign.of(context).successContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SetRecordBadge(widget.exerciseId, widget.setIndex),
            // Exercise letter + set number (e.g., "A1", "B1")
            Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppDesign.of(context).successContainer
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.exerciseLetter}${widget.setNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? AppDesign.of(context).successContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Weight field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _weightController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    suffixText: widget.set.weightUnit ??
                        (widget.set.weight == null
                            ? context.read<SettingsNotifier>().weightSuffix
                            : '?'),
                    hintText: '—',
                    hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    final weight = double.tryParse(value);
                    notifier.updateSet(widget.exerciseId, widget.setIndex,
                        weight: weight,
                        clearWeight: weight == null,
                        weightUnit: widget.set.weightUnit ??
                            context.read<SettingsNotifier>().weightSuffix);
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Reps field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _repsController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: '—',
                    hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) {
                    final reps = int.tryParse(value);
                    notifier.updateSet(widget.exerciseId, widget.setIndex,
                        reps: reps, clearReps: reps == null);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Completion stays green; the hit target remains comfortable.
            IconButton(
              tooltip: isCompleted ? 'Mark set incomplete' : 'Complete set',
              onPressed: () => notifier.toggleSetCompletion(
                  widget.exerciseId, widget.setIndex),
              style: IconButton.styleFrom(
                backgroundColor: isCompleted
                    ? AppDesign.of(context).successContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                foregroundColor: isCompleted
                    ? AppDesign.of(context).onSuccessContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              icon: Icon(
                  isCompleted
                      ? PhosphorIconsBold.check
                      : PhosphorIconsRegular.check,
                  size: 18),
            ),
          ],
        ),
      ),
    );
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
  // Get collapsed state from notifier instead of local state
  bool get _isCollapsed {
    final notifier = context.read<WorkoutNotifier>();
    return notifier.isExerciseCollapsed(widget.log.exerciseId);
  }

  void _toggleCollapsed() {
    final notifier = context.read<WorkoutNotifier>();
    notifier.toggleExerciseCollapsed(widget.log.exerciseId);
  }

  List<SetFieldType> get _effectiveFields =>
      context.read<WorkoutNotifier>().exerciseFields(widget.log.exerciseId) ??
      _inferDefaultFields(widget.exercise);

  /// Infer default fields based on exercise name and type
  List<SetFieldType> _inferDefaultFields(Exercise exercise) {
    final lowerName = exercise.name.toLowerCase();

    if (exercise.exerciseType != ExerciseType.cardio) {
      return exercise.exerciseType.defaultFields;
    }

    // Treadmill: time, speed, incline
    if (lowerName.contains('treadmill') ||
        lowerName.contains('run') ||
        lowerName.contains('jog')) {
      return [SetFieldType.time, SetFieldType.speed, SetFieldType.incline];
    }

    // Bike/Cycling: time, distance, resistance
    if (lowerName.contains('bike') ||
        lowerName.contains('cycling') ||
        lowerName.contains('cycle')) {
      return [
        SetFieldType.time,
        SetFieldType.distance,
        SetFieldType.resistance
      ];
    }

    // Rowing: time, distance
    if (lowerName.contains('row')) {
      return [SetFieldType.time, SetFieldType.distance];
    }

    // Elliptical/Stair: time, resistance, incline
    if (lowerName.contains('elliptical') || lowerName.contains('stair')) {
      return [SetFieldType.time, SetFieldType.resistance, SetFieldType.incline];
    }

    // Fall back to exercise type defaults
    return exercise.exerciseType.defaultFields;
  }

  void _showFieldSelector(BuildContext context) {
    List<SetFieldType> tempSelected = List.from(_effectiveFields);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    'Field Types',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, size: 20),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              Text(
                'Select 1-3 field types',
                style: TextStyle(
                    fontSize: 14, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              // Field options
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: SetFieldType.values.map((field) {
                    final isSelected = tempSelected.contains(field);
                    return InkWell(
                      onTap: () {
                        setSheetState(() {
                          if (isSelected) {
                            if (tempSelected.length > 1) {
                              tempSelected.remove(field);
                            }
                          } else {
                            if (tempSelected.length < 3) {
                              tempSelected.add(field);
                            }
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                              width: field != SetFieldType.values.last ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(field.icon,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text(
                              field.displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(PhosphorIconsBold.check,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context
                        .read<WorkoutNotifier>()
                        .setExerciseFields(widget.log.exerciseId, tempSelected);
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseMenu(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.exercise.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(PhosphorIconsBold.info,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text('Exercise Info',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                _showExerciseInfo(parentContext);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIconsBold.copy,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text('Duplicate Exercise',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
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
              leading: Icon(PhosphorIconsBold.trash,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Remove Exercise',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    showExerciseInfo(context, widget.exercise);
  }

  Widget _buildColumnHeaders(List<SetFieldType> fields) {
    final headerStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Row(
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Text(
              fields[i].displayName.toUpperCase(),
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: isInSuperSet
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsBold.arrowsClockwise,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Super Set ${superSetPosition != null ? (superSetPosition + 1) : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${superSet.exerciseIds.length} exercises',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 13,
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
                // Exercise image/icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.exercise.hasGif
                      ? ExerciseMedia(
                          imageUrl: widget.exercise.gifUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Center(
                            child: Text(widget.exercise.exerciseType.icon,
                                style: const TextStyle(fontSize: 20)),
                          ),
                          placeholder: (context, url) {
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(widget.exercise.exerciseType.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                ),
                const SizedBox(width: 12),
                // Exercise name and fields chip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.exercise.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      BestRecordBadge(widget.exercise.id),
                      // Field types chip (tappable to change)
                      GestureDetector(
                        onTap: () => _showFieldSelector(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _effectiveFields
                                      .map((f) => f.displayName)
                                      .join(' · '),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(PhosphorIconsRegular.caretDown,
                                  size: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu button
                IconButton(
                  icon: Icon(PhosphorIconsRegular.dotsThree,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22),
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
                    color: _isCollapsed
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  onPressed: _toggleCollapsed,
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
                  // Column Headers - dynamic based on selected fields
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 56, bottom: 8, right: 48),
                    child: _buildColumnHeaders(_effectiveFields),
                  ),

                  if (widget.log.exerciseType == 'cardio' ||
                      widget.exercise.exerciseType == ExerciseType.cardio)
                    CardioDetailsButton(exercise: widget.log),
                  PreviousSets(exerciseId: widget.exercise.id),
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                title: const Text(
                                  'Delete Set?',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                content: Text(
                                  'Remove set ${index + 1} from ${widget.exercise.name}?',
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withValues(alpha: 0.1),
                                    ),
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
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
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(PhosphorIconsBold.trash,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                size: 20),
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
                        fields: _effectiveFields,
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 8),

                  // Compact Action Buttons Row
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Add Set button
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () => notifier.addSet(widget.exercise.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIconsRegular.plusCircle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 18),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Add Set',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Divider
                        Container(
                            width: 1,
                            height: 24,
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                        // Super Set button
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () {
                              _showSuperSetOptions(
                                  context, notifier, widget.exercise.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIconsRegular.arrowsClockwise,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 18),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Super Set',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Divider
                        Container(
                            width: 1,
                            height: 24,
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
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
                            child: Icon(
                              PhosphorIconsBold.checks,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
  final List<SetFieldType> fields;

  const _SetRow({
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    required this.totalSets,
    this.isWarmup = false,
    this.superSetId,
    required this.fields,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  final Map<SetFieldType, TextEditingController> _controllers = {};
  final Map<SetFieldType, FocusNode> _focusNodes = {};
  SetFieldType? _focusedField;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    for (final field in SetFieldType.values) {
      _controllers[field] = TextEditingController(text: _getFieldValue(field));
      _focusNodes[field] = FocusNode()
        ..addListener(() {
          if (_focusNodes[field]!.hasFocus) {
            _focusedField = field;
          } else if (_focusedField == field) {
            _focusedField = null;
          }
        });
    }
  }

  String _getFieldValue(SetFieldType field) {
    switch (field) {
      case SetFieldType.weight:
        return widget.set.weight?.toString() ?? '';
      case SetFieldType.reps:
        return widget.set.reps?.toString() ?? '';
      case SetFieldType.time:
        return UserSettings.formatDuration(widget.set.durationSeconds);
      case SetFieldType.distance:
        return widget.set.distance?.toString() ?? '';
      case SetFieldType.speed:
        return widget.set.speed?.toString() ?? '';
      case SetFieldType.incline:
        return widget.set.incline?.toString() ?? '';
      case SetFieldType.resistance:
        return widget.set.resistance?.toString() ?? '';
    }
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controllers that are NOT currently focused
    for (final field in SetFieldType.values) {
      if (_focusedField == field) {
        continue; // Skip if user is editing this field
      }

      final newVal = _getFieldValue(field);
      final controller = _controllers[field]!;
      if (controller.text != newVal) {
        controller.text = newVal;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Check if this is the last set that should skip the timer
  bool _isLastSetOfBlock(BuildContext context) {
    final isLastSetOfExercise = widget.setIndex == widget.totalSets - 1;

    if (widget.superSetId == null) {
      return isLastSetOfExercise;
    }

    final workout = context.read<WorkoutNotifier>().currentWorkout;
    if (workout == null) return isLastSetOfExercise;

    final superSet =
        workout.superSets.where((s) => s.id == widget.superSetId).firstOrNull;
    if (superSet == null) return isLastSetOfExercise;

    final isLastExerciseInSuperSet = superSet.exerciseIds.isNotEmpty &&
        superSet.exerciseIds.last == widget.exerciseId;

    return isLastSetOfExercise && isLastExerciseInSuperSet;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final settings = context.read<SettingsNotifier>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SetRecordBadge(widget.exerciseId, widget.setIndex),
          _SetTypeBadge(
            setNumber: widget.setNumber,
            isWarmup: widget.isWarmup,
            isCompleted: widget.set.isCompleted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDynamicInputFields(context, notifier, settings),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip:
                widget.set.isCompleted ? 'Mark set incomplete' : 'Complete set',
            onPressed: () {
              final wasCompleted = widget.set.isCompleted;
              notifier.toggleSetCompletion(widget.exerciseId, widget.setIndex);
              if (!wasCompleted && !_isLastSetOfBlock(context)) {
                settings.startRestTimer();
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: widget.set.isCompleted
                  ? AppDesign.of(context).successContainer
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              foregroundColor: widget.set.isCompleted
                  ? AppDesign.of(context).onSuccessContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            icon: Icon(
                widget.set.isCompleted
                    ? PhosphorIconsBold.check
                    : PhosphorIconsRegular.check,
                size: 18),
          ),
        ],
      ),
    );
  }

  /// Build dynamic input fields based on the fields list
  Widget _buildDynamicInputFields(BuildContext context,
      WorkoutNotifier notifier, SettingsNotifier settings) {
    final isMetric = settings.userSettings.weightUnit == WeightUnit.kg;
    final fieldCount = widget.fields.length;

    return Row(
      children: [
        for (int i = 0; i < fieldCount; i++) ...[
          // Add vertical divider between fields
          if (i > 0)
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).colorScheme.outlineVariant,
              margin: EdgeInsets.symmetric(horizontal: fieldCount > 2 ? 6 : 10),
            ),
          Expanded(
            child: _buildFieldInput(
                widget.fields[i], context, settings, isMetric, fieldCount),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldInput(SetFieldType field, BuildContext context,
      SettingsNotifier settings, bool isMetric, int fieldCount) {
    final controller = _controllers[field]!;
    final focusNode = _focusNodes[field]!;
    final suffix = field == SetFieldType.weight
        ? (widget.set.weightUnit ??
            (widget.set.weight == null ? settings.weightSuffix : '?'))
        : field == SetFieldType.distance
            ? (widget.set.distanceUnit ??
                (widget.set.distance == null
                    ? (settings.userSettings.distanceUnit == DistanceUnit.miles
                        ? 'mi'
                        : 'km')
                    : '?'))
            : field == SetFieldType.speed
                ? (settings.userSettings.distanceUnit == DistanceUnit.miles
                    ? 'mph'
                    : 'km/h')
                : field.getSuffix(isMetric);

    switch (field) {
      case SetFieldType.weight:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '0',
          isDecimal: true,
          fieldCount: fieldCount,
          onChanged: (val) {
            final weight = double.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  weight: weight,
                  clearWeight: weight == null,
                  weightUnit: widget.set.weightUnit ?? settings.weightSuffix,
                );
          },
        );

      case SetFieldType.reps:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '10',
          isDecimal: false,
          fieldCount: fieldCount,
          onChanged: (val) {
            final reps = int.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  reps: reps,
                  clearReps: reps == null,
                );
          },
        );

      case SetFieldType.time:
        return _buildTimeInput(
          controller: controller,
          focusNode: focusNode,
          fieldCount: fieldCount,
          onChanged: (val) {
            final seconds = UserSettings.parseDuration(val);
            if (seconds != null) {
              context.read<WorkoutNotifier>().updateSet(
                    widget.exerciseId,
                    widget.setIndex,
                    durationSeconds: seconds,
                  );
            }
          },
        );

      case SetFieldType.distance:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '0',
          isDecimal: true,
          fieldCount: fieldCount,
          onChanged: (val) {
            final distance = double.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  distance: distance,
                  distanceUnit: widget.set.distanceUnit ??
                      (settings.userSettings.distanceUnit == DistanceUnit.miles
                          ? 'mi'
                          : 'km'),
                );
          },
        );

      case SetFieldType.speed:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '0',
          isDecimal: true,
          fieldCount: fieldCount,
          onChanged: (val) {
            final speed = double.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  speed: speed,
                );
          },
        );

      case SetFieldType.incline:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '0',
          isDecimal: true,
          fieldCount: fieldCount,
          onChanged: (val) {
            final incline = double.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  incline: incline,
                );
          },
        );

      case SetFieldType.resistance:
        return _buildNumericInput(
          controller: controller,
          focusNode: focusNode,
          suffix: suffix,
          hintText: '0',
          isDecimal: false,
          fieldCount: fieldCount,
          onChanged: (val) {
            final resistance = int.tryParse(val);
            context.read<WorkoutNotifier>().updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  resistance: resistance,
                );
          },
        );
    }
  }

  Widget _buildNumericInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String suffix,
    required String hintText,
    required bool isDecimal,
    required int fieldCount,
    required ValueChanged<String> onChanged,
  }) {
    // Adaptive font size based on number of fields
    final fontSize = fieldCount > 2 ? 13.0 : 14.0;
    final suffixSize = fieldCount > 2 ? 10.0 : 11.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        if (suffix.isNotEmpty) ...[
          Text(
            suffix,
            style: TextStyle(
              fontSize: suffixSize,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int fieldCount,
    required ValueChanged<String> onChanged,
  }) {
    final fontSize = fieldCount > 2 ? 13.0 : 14.0;
    final iconSize = fieldCount > 2 ? 11.0 : 12.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhosphorIconsRegular.timer,
            size: iconSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
              hintText: '--',
              hintStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
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
        width: 32,
        height: 24,
        decoration: BoxDecoration(
          color: isCompleted
              ? AppDesign.of(context).successContainer
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            'W',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? AppDesign.of(context).onSuccessContainer
                  : AppDesign.of(context).success,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 32,
      child: Text(
        '$setNumber',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isCompleted
              ? AppDesign.of(context).success
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                color: Theme.of(context).colorScheme.outlineVariant,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (widget.unit.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.unit,
                          style: TextStyle(
                            fontSize: 24,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'C',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.error,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIconsRegular.backspace,
                                size: 24,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
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
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
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
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
  List<Exercise> _allExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    final notifier = context.read<ExerciseDbNotifier>();

    // Initialize filters and load all exercises
    await notifier.initialize();

    // Search with forceLoad to get all exercises
    await notifier.search(forceLoad: true);

    // Get all cached exercises
    final exercises = notifier.exercises;

    // Also include saved exercises if available
    final savedExercises = notifier.savedExercises;

    // Combine and deduplicate
    final allExercises = <String, Exercise>{};
    for (final e in savedExercises) {
      allExercises[e.id] = e;
    }
    for (final e in exercises) {
      allExercises[e.id] = e;
    }

    setState(() {
      _allExercises = allExercises.values.toList();
      _isLoading = false;
    });
  }

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
    try {
      return _allExercises.firstWhere(
        (e) => e.id == widget.currentExerciseId,
      );
    } catch (e) {
      return null;
    }
  }

  String? get _currentMuscleGroup => _currentExercise?.muscleGroup;

  List<String> get _muscleGroups {
    final groups = _allExercises.map((e) => e.muscleGroup).toSet().toList();
    groups.sort();
    return ['All', ...groups];
  }

  /// Get suggested exercises based on antagonist muscle pairs
  List<Exercise> get _suggestedExercises {
    if (_currentMuscleGroup == null) return [];

    final antagonistGroups = _antagonistPairs[_currentMuscleGroup] ?? [];

    return _allExercises
        .where((e) {
          if (e.id == widget.currentExerciseId) return false;
          return antagonistGroups.contains(e.muscleGroup);
        })
        .take(6)
        .toList();
  }

  /// Get exercises from the same muscle group (compound sets)
  List<Exercise> get _sameMuscleExercises {
    if (_currentMuscleGroup == null) return [];

    return _allExercises
        .where((e) {
          if (e.id == widget.currentExerciseId) return false;
          return e.muscleGroup == _currentMuscleGroup;
        })
        .take(6)
        .toList();
  }

  List<Exercise> get _filteredExercises {
    return _allExercises.where((e) {
      if (e.id == widget.currentExerciseId) return false;

      final matchesSearch = _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesMuscle = _selectedMuscleGroup == 'All' ||
          e.muscleGroup == _selectedMuscleGroup;

      return matchesSearch && matchesMuscle;
    }).toList();
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
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(PhosphorIconsBold.check,
                  size: 14,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
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
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
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
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIconsBold.barbell,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exercise.muscleGroup} • ${exercise.equipment}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(PhosphorIconsBold.check,
                      color: Theme.of(context).colorScheme.onPrimary, size: 14)
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const CircleBorder(),
          ),
          icon: Icon(PhosphorIconsRegular.x,
              color: Theme.of(context).colorScheme.onSurface, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Super Set',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Done (${_selectedExercises.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
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
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsBold.arrowsClockwise,
                      color: Theme.of(context).colorScheme.primary, size: 18),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentExercise?.name ?? 'Current',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
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
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(PhosphorIconsBold.x,
                                          size: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
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
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : _allExercises.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIconsRegular.barbell,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No exercises found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadExercises,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _showAllExercises || !hasSuggestions
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(PhosphorIconsBold.lightningA,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Antagonist Pairs',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Opposite muscle groups for balanced training',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: AppDesign.of(context).warningContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(PhosphorIconsBold.fire,
                      size: 16, color: AppDesign.of(context).warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compound Set',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Same muscle ($_currentMuscleGroup) for intensity',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 8),
                  Text(
                    'Browse All Exercises',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  Icon(PhosphorIconsRegular.arrowLeft,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'Back to Suggestions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 15),
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20),
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
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      group,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
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
          Text(
            'Manage Super Set',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  title: Text(
                    _getExerciseNameById(context, exerciseId),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  trailing: IconButton(
                    icon: Icon(PhosphorIconsRegular.x,
                        color: Theme.of(context).colorScheme.error),
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
              child: Text('Done',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
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
    final colors = Theme.of(context).colorScheme;
    final timer = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(settings.isPaused ? 'Paused' : 'Rest timer',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onPrimaryContainer)),
        Text(settings.formatRestTime(settings.currentRestSeconds),
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(color: colors.onPrimaryContainer)),
      ],
    );
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => settings.adjustRestTime(-15),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: colors.onPrimaryContainer,
              backgroundColor: colors.surface),
          child: const Text('−15'),
        ),
        TextButton(
          onPressed: () => settings.adjustRestTime(15),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: colors.onPrimaryContainer,
              backgroundColor: colors.surface),
          child: const Text('+15'),
        ),
        IconButton(
          tooltip: settings.isPaused ? 'Resume rest timer' : 'Pause rest timer',
          onPressed: () {
            if (settings.isPaused) {
              settings.resumeRestTimer();
            } else {
              settings.pauseRestTimer();
            }
          },
          style: IconButton.styleFrom(backgroundColor: colors.surface),
          icon: Icon(settings.isPaused
              ? PhosphorIconsBold.play
              : PhosphorIconsBold.pause),
        ),
        IconButton(
          tooltip: 'Stop rest timer',
          onPressed: onDismiss,
          style: IconButton.styleFrom(
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer),
          icon: const Icon(PhosphorIconsBold.x),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(15) > 20;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [timer, const SizedBox(height: 8), controls],
            );
          }
          return Row(children: [
            Expanded(child: timer),
            const SizedBox(width: 12),
            controls,
          ]);
        }),
      ),
    );
  }
}

/// Shown when the workout clock stopped after 10 minutes without activity.
class _PausedTimerBanner extends StatelessWidget {
  final WorkoutNotifier notifier;
  const _PausedTimerBanner(this.notifier);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.lime, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsBold.pause,
                size: 16, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Timer paused',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    'Nothing logged for 10 minutes, so the clock stopped at your last change.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: notifier.resumeTimer,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lavender,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}
