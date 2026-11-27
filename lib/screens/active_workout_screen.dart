import '../models/cardio_machine.dart';
import '../widgets/cardio_session_card.dart';
import '../widgets/keyboard_done_bar.dart';
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
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../models/user_settings.dart';
import '../data/exercise_data.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'library_screen.dart';
import '../widgets/superset_start_sheet.dart';
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
  final _scroll = ScrollController();

  // The exercise just added; the list scrolls to it so earlier, completed
  // exercises aren't edited by mistake.
  String? _revealId;
  final _revealKey = GlobalKey();

  /// Scrolls to an exercise: a new one ([isNew]) is last in the list; one
  /// already in the workout is found where it is.
  void _revealAdded(String exerciseId, {bool isNew = true}) {
    setState(() => _revealId = exerciseId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      // A new card is last, so bring the end of the list into view first;
      // an existing card off screen may not be built yet, so start from the
      // top. Then line the card's top up with the top of the screen.
      if (isNew) {
        await _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else if (_revealKey.currentContext == null) {
        await _scroll.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      final card = _revealKey.currentContext;
      if (!mounted || card == null || !card.mounted) return;
      await Scrollable.ensureVisible(card,
          alignment: 0.02,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
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
        backgroundColor: _brandPage(context),
        appBar: AppBar(
          backgroundColor: _brandPage(context),
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
                color: _brandPage(context),
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
                          final superSetCard = _SuperSetWorkoutCard(
                            key: ValueKey('superset_${superSet.id}'),
                            superSet: superSet,
                            exercises: superSetExercises,
                          );
                          displayItems.add(superSetExercises
                                  .any((e) => e.$1.exerciseId == _revealId)
                              ? KeyedSubtree(
                                  key: _revealKey, child: superSetCard)
                              : superSetCard);

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

                        // Cardio is one session with a stopwatch, not sets.
                        final Widget card = isCardioSession(exercise,
                                loggedType: log.exerciseType)
                            ? CardioSessionCard(
                                key: ValueKey(log.exerciseId),
                                exercise: exercise,
                                log: log,
                                exerciseIndex: i,
                              )
                            : _ExerciseWorkoutCard(
                                key: ValueKey(log.exerciseId),
                                exercise: exercise,
                                log: log,
                                exerciseIndex: i,
                              );
                        displayItems.add(log.exerciseId == _revealId
                            ? KeyedSubtree(key: _revealKey, child: card)
                            : card);
                      }
                    }

                    // Add Exercise after the exercises, where your thumb already is.
                    displayItems.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 24),
                        child: GestureDetector(
                          onTap: () async {
                            final Exercise? selected = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const LibraryScreen(isPicker: true)),
                            );
                            if (selected != null) {
                              // Already here: take them to it instead of
                              // adding a second copy.
                              final already = notifier.hasExercise(selected.id);
                              notifier.addExercise(selected);
                              _revealAdded(selected.id, isNew: !already);
                              if (already && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        '${selected.name} is already in this workout')));
                              }
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

                    return ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Scrolling closes the keyboard so it never sits over
                      // the sets you're looking for.
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
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
    // A cardio stopwatch still running keeps its time.
    notifier.stopAllCardio();
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
                  eachSide: e.eachSide,
                  oneSided: e.oneSided,
                  exerciseType: e.exerciseType,
                  averageHeartRate: e.averageHeartRate,
                  intensity: e.intensity,
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

    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        // A lavender outline marks exercises done back to back.
        border: Border.all(
          color: AppColors.lavender.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Superset header, like the exercise cards: icon circle, title,
          // and the small menu and collapse buttons.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.lavender, shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsBold.arrowsClockwise,
                      size: 20, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Superset',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text('$exerciseCount exercises · alternate sets',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: colors.onSurfaceVariant)),
                      ]),
                ),
                _SquareButton(
                  tooltip: 'Superset options',
                  icon: PhosphorIconsBold.dotsThree,
                  onTap: () => _showSuperSetMenu(context),
                ),
                const SizedBox(width: 4),
                _SquareButton(
                  tooltip: _isCollapsed ? 'Show sets' : 'Done, collapse',
                  icon: _isCollapsed
                      ? PhosphorIconsBold.caretDown
                      : PhosphorIconsBold.check,
                  circle: true,
                  fill: _isCollapsed ? null : AppColors.lavender,
                  onTap: _toggleCollapsed,
                ),
              ],
            ),
          ),

          // The exercises in the superset, each with its letter.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Column(
              children: widget.exercises.map((item) {
                final exercise = item.$2;
                final letter =
                    String.fromCharCode(65 + widget.exercises.indexOf(item));
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: _softPill(context).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
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
                              Text(
                                exercise.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              BestRecordBadge(exercise.id),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      // Order letter (A, B, C...)
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: AppColors.lavender, shape: BoxShape.circle),
                        child: Text(letter,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Alternating Sets Section (collapsible)
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                children: [
                  for (final entry in widget.exercises)
                    if (entry.$1.exerciseType == 'cardio' ||
                        entry.$2.exerciseType == ExerciseType.cardio)
                      CardioDetailsButton(exercise: entry.$1),
                  // Each side only for one-sided exercises (or one already
                  // logged that way, so it can be turned off).
                  for (final (i, entry) in widget.exercises.indexed)
                    if (entry.$1.eachSide || entry.$1.canEachSide)
                      _EachSideSwitch(
                          log: entry.$1, letter: String.fromCharCode(65 + i)),
                  // Column Headers
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 58, bottom: 6, right: 58),
                    child: Row(
                      children: [
                        for (final label in ['WEIGHT', 'REPS'])
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.9,
                              ),
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
                      padding: EdgeInsets.zero,
                      child: _SuperSetSetRow(
                        exerciseLetter: exerciseLetter,
                        setNumber: item.setIndex + 1,
                        set: item.log.sets[item.setIndex],
                        exerciseId: item.log.exerciseId,
                        setIndex: item.setIndex,
                        exerciseName: item.exercise.name,
                        // Rest after each round: the last exercise's set.
                        endsRound: widget.exercises.isNotEmpty &&
                            widget.exercises.last.$1.exerciseId ==
                                item.log.exerciseId,
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Add Set Button (adds to ALL exercises)
                  _ActionPill(
                    icon: PhosphorIconsBold.plus,
                    label: 'Add set to all',
                    fill: AppColors.lavender,
                    onTap: () => notifier.addSetToSuperSet(widget.superSet.id),
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
  final bool endsRound;

  const _SuperSetSetRow({
    required this.exerciseLetter,
    required this.setNumber,
    required this.set,
    required this.exerciseId,
    required this.setIndex,
    required this.exerciseName,
    this.endsRound = false,
  });

  @override
  State<_SuperSetSetRow> createState() => _SuperSetSetRowState();
}

class _SuperSetSetRowState extends State<_SuperSetSetRow> {
  late final _weightController =
      TextEditingController(text: _text(widget.set.weight));
  late final _repsController =
      TextEditingController(text: _text(widget.set.reps));
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();
  // The right side of an "each side" set.
  late final _rightWeightController =
      TextEditingController(text: _text(widget.set.weightRight as num?));
  late final _rightRepsController =
      TextEditingController(text: _text(widget.set.repsRight as num?));
  final _rightWeightFocus = FocusNode();
  final _rightRepsFocus = FocusNode();

  static String _text(num? value) => value?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    // Select the value on focus so typing replaces it.
    for (final (node, controller) in [
      (_weightFocus, _weightController),
      (_repsFocus, _repsController),
      (_rightWeightFocus, _rightWeightController),
      (_rightRepsFocus, _rightRepsController),
    ]) {
      node.addListener(() {
        if (!node.hasFocus) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (node.hasFocus) {
            controller.selection = TextSelection(
                baseOffset: 0, extentOffset: controller.text.length);
          }
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SuperSetSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Show values filled in from an earlier set, except while typing here.
    final weight = _text(widget.set.weight);
    final reps = _text(widget.set.reps);
    if (!_weightFocus.hasFocus && _weightController.text != weight) {
      _weightController.text = weight;
    }
    if (!_repsFocus.hasFocus && _repsController.text != reps) {
      _repsController.text = reps;
    }
    for (final (node, controller, value) in [
      (_rightWeightFocus, _rightWeightController, widget.set.weightRight),
      (_rightRepsFocus, _rightRepsController, widget.set.repsRight),
    ]) {
      final text = _text(value as num?);
      if (!node.hasFocus && controller.text != text) controller.text = text;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _rightWeightController.dispose();
    _rightRepsController.dispose();
    _rightWeightFocus.dispose();
    _rightRepsFocus.dispose();
    super.dispose();
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required bool decimal,
    String? suffix,
    String hint = '—',
    required ValueChanged<String> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    // The whole cell takes the tap, not just the digits.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              suffixText: suffix,
              suffixStyle:
                  TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              hintText: hint,
              hintStyle: TextStyle(color: colors.onSurfaceVariant),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _sideLabel(String side) => SizedBox(
        width: 10,
        child: Text(side,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _divider() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6));

  String _unit(SettingsNotifier settings) =>
      widget.set.weightUnit ??
      (widget.set.weight == null ? settings.weightSuffix : '?');

  Widget _leftInputs(WorkoutNotifier notifier, SettingsNotifier settings) =>
      Row(children: [
        Expanded(
          child: _field(
            controller: _weightController,
            focus: _weightFocus,
            decimal: true,
            suffix: _unit(settings),
            onChanged: (value) {
              final weight = double.tryParse(value);
              notifier.updateSet(widget.exerciseId, widget.setIndex,
                  weight: weight,
                  clearWeight: weight == null,
                  weightUnit: widget.set.weightUnit ?? settings.weightSuffix);
            },
          ),
        ),
        _divider(),
        Expanded(
          child: _field(
            controller: _repsController,
            focus: _repsFocus,
            decimal: false,
            onChanged: (value) {
              final reps = int.tryParse(value);
              notifier.updateSet(widget.exerciseId, widget.setIndex,
                  reps: reps, clearReps: reps == null);
            },
          ),
        ),
      ]);

  /// The right side; an empty box shows the left value it matches.
  Widget _rightInputs(WorkoutNotifier notifier, SettingsNotifier settings) =>
      Row(children: [
        Expanded(
          child: _field(
            controller: _rightWeightController,
            focus: _rightWeightFocus,
            decimal: true,
            suffix: _unit(settings),
            hint: _weightController.text.isEmpty ? '—' : _weightController.text,
            onChanged: (value) {
              final weight = double.tryParse(value);
              notifier.updateRightSide(widget.exerciseId, widget.setIndex,
                  weight: weight, clearWeight: weight == null);
            },
          ),
        ),
        _divider(),
        Expanded(
          child: _field(
            controller: _rightRepsController,
            focus: _rightRepsFocus,
            decimal: false,
            hint: _repsController.text.isEmpty ? '—' : _repsController.text,
            onChanged: (value) {
              final reps = int.tryParse(value);
              notifier.updateRightSide(widget.exerciseId, widget.setIndex,
                  reps: reps, clearReps: reps == null);
            },
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final settings = context.read<SettingsNotifier>();
    final done = widget.set.isCompleted;
    final colors = Theme.of(context).colorScheme;
    final eachSide = notifier.currentWorkout?.exercises
            .where((e) => e.exerciseId == widget.exerciseId)
            .firstOrNull
            ?.eachSide ??
        false;

    // Same row as single exercises: soft, rounded, lime once done.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: done
            ? AppColors.lime.withValues(alpha: 0.22)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SetRecordBadge(widget.exerciseId, widget.setIndex),
          // Exercise letter + set number (e.g., "A1", "B1")
          Container(
            width: 40,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.lime : colors.surface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${widget.exerciseLetter}${widget.setNumber}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done ? AppColors.ink : colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // "Each side": a left line and a right line, each with its own
            // weight and reps.
            child: eachSide
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      _sideLabel('L'),
                      Expanded(child: _leftInputs(notifier, settings)),
                    ]),
                    Row(children: [
                      _sideLabel('R'),
                      Expanded(child: _rightInputs(notifier, settings)),
                    ]),
                  ])
                : _leftInputs(notifier, settings),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: done ? 'Mark set incomplete' : 'Complete set',
            onPressed: () {
              final wasCompleted = widget.set.isCompleted as bool;
              // A set without reps would save as nothing: open reps instead.
              if (!wasCompleted && ((widget.set.reps as int?) ?? 0) <= 0) {
                _repsFocus.requestFocus();
                return;
              }
              hideKeyboard();
              notifier.toggleSetCompletion(widget.exerciseId, widget.setIndex);
              if (!wasCompleted && widget.endsRound) {
                context.read<SettingsNotifier>().startRestTimer();
              }
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: done ? AppColors.lime : colors.surface,
              foregroundColor: done ? AppColors.ink : colors.onSurfaceVariant,
              side: done
                  ? null
                  : BorderSide(color: colors.outlineVariant, width: 1),
            ),
            icon: Icon(
                done ? PhosphorIconsBold.check : PhosphorIconsRegular.check,
                size: 19),
          ),
        ],
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
              leading: Icon(PhosphorIconsBold.plus,
                  color: Theme.of(context).colorScheme.onSurface),
              title: Text('Add another set',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              // An exercise appears once per workout, so more work on it is
              // another set rather than a second copy.
              onTap: () {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                notifier.addSet(widget.exercise.id);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Set added')),
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

  // "Each side" is only for one-sided exercises with weight or reps (or one
  // already logged that way, so it can be turned off).
  bool get _sidedFields =>
      widget.log.exerciseType != 'cardio' &&
      widget.exercise.exerciseType != ExerciseType.cardio &&
      (widget.log.eachSide || widget.log.canEachSide) &&
      _effectiveFields
          .any((f) => f == SetFieldType.weight || f == SetFieldType.reps);

  Widget _buildColumnHeaders(List<SetFieldType> fields) {
    final headerStyle = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.9,
    );

    return Row(
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fields[i].displayName.toUpperCase(),
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
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
        borderRadius: BorderRadius.circular(26),
        border: isInSuperSet
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : null,
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
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                // Exercise image/icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _softPill(context),
                    borderRadius: BorderRadius.circular(16),
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
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      BestRecordBadge(widget.exercise.id),
                      // Field types chip (tappable to change)
                      GestureDetector(
                        onTap: () => _showFieldSelector(context),
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _softPill(context),
                            borderRadius: BorderRadius.circular(99),
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
                // Menu button: a small rounded square, as on the profile.
                _SquareButton(
                  tooltip: 'Exercise options',
                  icon: PhosphorIconsBold.dotsThree,
                  onTap: () => _showExerciseMenu(context),
                ),
                const SizedBox(width: 4),
                // Collapse: a lavender circle with a check.
                _SquareButton(
                  tooltip: _isCollapsed ? 'Show sets' : 'Done, collapse',
                  icon: _isCollapsed
                      ? PhosphorIconsBold.caretDown
                      : PhosphorIconsBold.check,
                  circle: true,
                  fill: _isCollapsed ? null : AppColors.lavender,
                  onTap: _toggleCollapsed,
                ),
              ],
            ),
          ),

          // Sets Section (collapsible)
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  if (_sidedFields) _EachSideSwitch(log: widget.log),
                  // Column Headers - dynamic based on selected fields
                  Padding(
                    // Lines up over the inputs, past the L / R labels too.
                    padding: EdgeInsets.only(
                        left: widget.log.eachSide && _sidedFields ? 58 : 48,
                        bottom: 6,
                        right: 58),
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
                        isWarmup: set.isWarmup,
                        superSetId: widget.log.superSetId,
                        fields: _effectiveFields,
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 8),

                  // Actions as brand pills.
                  Row(
                    children: [
                      Expanded(
                        child: _ActionPill(
                          icon: PhosphorIconsBold.plus,
                          label: 'Add set',
                          fill: AppColors.lavender,
                          onTap: () => notifier.addSet(widget.exercise.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionPill(
                          icon: PhosphorIconsBold.arrowsClockwise,
                          label: 'Superset',
                          fill: _softPill(context),
                          onTap: () => _showSuperSetOptions(
                              context, notifier, widget.exercise.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ActionPill(
                        icon: PhosphorIconsBold.checks,
                        tooltip: 'Complete all sets',
                        fill: AppColors.lime,
                        onTap: () {
                          hideKeyboard();
                          final needsReps =
                              _effectiveFields.contains(SetFieldType.reps);
                          var completed = false;
                          var skipped = 0;
                          for (int i = 0; i < widget.log.sets.length; i++) {
                            final set = widget.log.sets[i];
                            if (set.isCompleted) continue;
                            // Sets without reps stay open; they'd save empty.
                            if (needsReps && (set.reps ?? 0) <= 0) {
                              skipped++;
                              continue;
                            }
                            notifier.toggleSetCompletion(widget.exercise.id, i);
                            completed = true;
                          }
                          if (completed) {
                            context.read<SettingsNotifier>().startRestTimer();
                          }
                          if (skipped > 0) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                  content: Text(skipped == 1
                                      ? 'Add reps to finish 1 set'
                                      : 'Add reps to finish $skipped sets')));
                          }
                        },
                      ),
                    ],
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
  // The right side of an "each side" set; an empty box matches the left.
  static const _sided = [SetFieldType.weight, SetFieldType.reps];
  final Map<SetFieldType, TextEditingController> _right = {};
  final Map<SetFieldType, FocusNode> _rightFocus = {};
  bool _eachSide = false;

  String _rightText(SetFieldType field) => field == SetFieldType.weight
      ? (widget.set.weightRight?.toString() ?? '')
      : (widget.set.repsRight?.toString() ?? '');

  bool get _showSides =>
      _eachSide && widget.fields.any((f) => _sided.contains(f));
  bool get _missingReps =>
      widget.fields.contains(SetFieldType.reps) &&
      ((widget.set.reps as int?) ?? 0) <= 0;

  @override
  void initState() {
    super.initState();
    _initControllers();
    for (final field in _sided) {
      final controller = TextEditingController(text: _rightText(field));
      _right[field] = controller;
      _rightFocus[field] = FocusNode()
        ..addListener(() {
          if (!_rightFocus[field]!.hasFocus) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_rightFocus[field]?.hasFocus ?? false) {
              controller.selection = TextSelection(
                  baseOffset: 0, extentOffset: controller.text.length);
            }
          });
        });
    }
  }

  void _initControllers() {
    for (final field in SetFieldType.values) {
      _controllers[field] = TextEditingController(text: _getFieldValue(field));
      _focusNodes[field] = FocusNode()
        ..addListener(() {
          if (_focusNodes[field]!.hasFocus) {
            _focusedField = field;
            // Select the value so typing replaces it, without first
            // deleting what was there.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final controller = _controllers[field];
              if (controller == null || !_focusNodes[field]!.hasFocus) return;
              controller.selection = TextSelection(
                  baseOffset: 0, extentOffset: controller.text.length);
            });
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
    for (final field in _sided) {
      final text = _rightText(field);
      if (!_rightFocus[field]!.hasFocus && _right[field]!.text != text) {
        _right[field]!.text = text;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _right.values) {
      c.dispose();
    }
    for (final f in _rightFocus.values) {
      f.dispose();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<WorkoutNotifier>();
    final settings = context.read<SettingsNotifier>();
    _eachSide = notifier.currentWorkout?.exercises
            .where((e) => e.exerciseId == widget.exerciseId)
            .firstOrNull
            ?.eachSide ??
        false;

    final done = widget.set.isCompleted;
    final colors = Theme.of(context).colorScheme;
    // Each set is a soft rounded row that turns lime when it's done.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: done
            ? AppColors.lime.withValues(alpha: 0.22)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SetRecordBadge(widget.exerciseId, widget.setIndex),
          // Tapping the set number marks it as a warm-up, and back.
          Tooltip(
            message: widget.isWarmup ? 'Make a working set' : 'Mark as warm-up',
            child: GestureDetector(
              key: ValueKey('set-badge-${widget.setIndex}'),
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  notifier.toggleWarmup(widget.exerciseId, widget.setIndex),
              child: _SetTypeBadge(
                setNumber: widget.setNumber,
                isWarmup: widget.isWarmup,
                isCompleted: done,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            // "Each side": a left line and a right line, each with its own
            // weight and reps.
            child: _showSides
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      _sideLabel('L'),
                      Expanded(
                          child: _buildDynamicInputFields(
                              context, notifier, settings)),
                    ]),
                    Row(children: [
                      _sideLabel('R'),
                      Expanded(child: _buildRightInputs(context, settings)),
                    ]),
                  ])
                : _buildDynamicInputFields(context, notifier, settings),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: done ? 'Mark set incomplete' : 'Complete set',
            onPressed: () {
              final wasCompleted = widget.set.isCompleted;
              // A set without reps would save as nothing: open reps instead.
              if (!wasCompleted && _missingReps) {
                _focusNodes[SetFieldType.reps]!.requestFocus();
                return;
              }
              hideKeyboard();
              notifier.toggleSetCompletion(widget.exerciseId, widget.setIndex);
              // Rest after every set, the last one included.
              if (!wasCompleted) settings.startRestTimer();
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              backgroundColor: done ? AppColors.lime : colors.surface,
              foregroundColor: done ? AppColors.ink : colors.onSurfaceVariant,
              side: done
                  ? null
                  : BorderSide(color: colors.outlineVariant, width: 1),
            ),
            icon: Icon(
                done ? PhosphorIconsBold.check : PhosphorIconsRegular.check,
                size: 19),
          ),
        ],
      ),
    );
  }

  /// Build dynamic input fields based on the fields list
  Widget _sideLabel(String side) => SizedBox(
        width: 10,
        child: Text(side,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  /// The right side's weight and reps, under the left side's columns. An
  /// empty box shows the left value: the right matches until changed.
  Widget _buildRightInputs(BuildContext context, SettingsNotifier settings) {
    final fieldCount = widget.fields.length;
    final notifier = context.read<WorkoutNotifier>();
    return Row(children: [
      for (int i = 0; i < fieldCount; i++) ...[
        if (i > 0)
          Container(
            width: 1,
            height: 22,
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.6),
            margin: EdgeInsets.symmetric(horizontal: fieldCount > 2 ? 4 : 8),
          ),
        Expanded(
          child: !_sided.contains(widget.fields[i])
              ? const SizedBox(height: 44)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _rightFocus[widget.fields[i]]!.requestFocus(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      child: _buildNumericInput(
                        key: ValueKey('right-${widget.fields[i].name}'),
                        controller: _right[widget.fields[i]]!,
                        focusNode: _rightFocus[widget.fields[i]]!,
                        suffix: widget.fields[i] == SetFieldType.weight
                            ? (widget.set.weightUnit ?? settings.weightSuffix)
                            : '',
                        hintText: _controllers[widget.fields[i]]!.text.isEmpty
                            ? '—'
                            : _controllers[widget.fields[i]]!.text,
                        isDecimal: widget.fields[i] == SetFieldType.weight,
                        fieldCount: fieldCount,
                        onChanged: (val) {
                          if (widget.fields[i] == SetFieldType.weight) {
                            final w = double.tryParse(val);
                            notifier.updateRightSide(
                                widget.exerciseId, widget.setIndex,
                                weight: w, clearWeight: w == null);
                          } else {
                            final r = int.tryParse(val);
                            notifier.updateRightSide(
                                widget.exerciseId, widget.setIndex,
                                reps: r, clearReps: r == null);
                          }
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ]);
  }

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
              height: 22,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.6),
              margin: EdgeInsets.symmetric(horizontal: fieldCount > 2 ? 4 : 8),
            ),
          // The whole cell takes the tap, not just the digits, so one tap
          // always opens the field.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNodes[widget.fields[i]]!.requestFocus(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: _buildFieldInput(widget.fields[i], context, settings,
                      isMetric, fieldCount),
                ),
              ),
            ),
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
          hintText: '—',
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
          hintText: '—',
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
          hintText: '—',
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
          hintText: '—',
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
          hintText: '—',
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
          hintText: '—',
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
    Key? key,
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

    // Shrinks rather than overflows in narrow cells at large text sizes.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          IntrinsicWidth(
            child: TextField(
              key: key,
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
      ),
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.lime
              : AppColors.coral.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'W',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isCompleted ? AppColors.ink : AppColors.coral,
            ),
          ),
        ),
      );
    }

    // A numbered circle: white while open, lime when done.
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.lime
            : Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$setNumber',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isCompleted
              ? AppColors.ink
              : Theme.of(context).colorScheme.onSurface,
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

Future<void> _showSuperSetCreation(BuildContext context,
    WorkoutNotifier notifier, String currentExerciseId) async {
  final workout = notifier.currentWorkout;
  final current = workout?.exercises
      .where((e) => e.exerciseId == currentExerciseId)
      .firstOrNull;
  if (workout == null || current == null) return;
  // Exercises already here that can join: not cardio, not in a superset.
  final inWorkout = [
    for (final log in workout.exercises)
      if (log.exerciseId != currentExerciseId &&
          log.superSetId == null &&
          log.exerciseType != 'cardio')
        log,
  ];
  final choice = await showSupersetStartSheet(context,
      current: current, inWorkout: inWorkout);
  if (choice == null || !context.mounted) return;
  String? partner;
  switch (choice) {
    case SupersetFromLibrary():
      final Exercise? picked = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const LibraryScreen(isPicker: true)));
      if (picked == null || picked.id == currentExerciseId) return;
      // Already in the workout: pair with it rather than adding it twice.
      if (!workout.exercises.any((e) => e.exerciseId == picked.id)) {
        notifier.addExercise(picked);
      }
      partner = picked.id;
    case SupersetWithExercise(:final exercise):
      notifier.addExercise(exercise);
      partner = exercise.id;
    case SupersetWithLogged(:final exerciseId):
      partner = exerciseId;
  }
  notifier.createSuperSet([currentExerciseId, partner]);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Superset created')),
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

/// Shown when the workout clock stopped after 30 minutes without activity.
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
                    'Nothing logged for 30 minutes, so the clock stopped at your last change.',
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

/// The soft lavender page behind workout cards (theme surface in dark mode).
Color _brandPage(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : const Color(0xFFF6F4FC);

/// Pale lavender for chips and thumbnails (primary container in dark mode).
Color _softPill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.primaryContainer
        : AppColors.paleLavender;

/// A small rounded-square (or circle) icon button used in card headers.
class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool circle;
  final Color? fill;
  const _SquareButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.circle = false,
      this.fill});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill ?? colors.surface,
        shape: circle
            ? CircleBorder(
                side: fill == null
                    ? BorderSide(color: colors.outlineVariant)
                    : BorderSide.none)
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon,
                size: 17,
                color: fill == null ? colors.onSurface : AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// A rounded pill button for card actions (Add set, Superset, Complete all).
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Color fill;
  final VoidCallback onTap;
  const _ActionPill(
      {required this.icon,
      this.label,
      this.tooltip,
      required this.fill,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      color: fill,
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 16 : 12),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: AppColors.ink),
            if (label != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ),
            ],
          ]),
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// "Each side": the weight and reps typed are for one arm, leg or dumbbell,
/// and the other side did the same. Starts on for one-arm, one-leg,
/// alternating and dumbbell moves; remembered per exercise.
class _EachSideSwitch extends StatelessWidget {
  final WorkoutExerciseLog log;
  // Superset exercise letter, e.g. "A".
  final String? letter;
  const _EachSideSwitch({required this.log, this.letter});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = log.eachSide;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text(
            letter != null
                ? '$letter · ${on ? 'each side' : 'whole set'}'
                : on
                    ? 'Left and right · R matches L until changed'
                    : 'Whole set',
            maxLines: 2,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          toggled: on,
          label: 'Each side',
          child: InkWell(
            key: ValueKey('each-side-${log.exerciseId}'),
            borderRadius: BorderRadius.circular(999),
            onTap: () => context
                .read<WorkoutNotifier>()
                .setEachSide(log.exerciseId, !on),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: on ? AppColors.lavender : colors.surface,
                borderRadius: BorderRadius.circular(999),
                border: on ? null : Border.all(color: colors.outlineVariant),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(on ? PhosphorIconsBold.check : PhosphorIconsRegular.circle,
                    size: 14,
                    color: on ? AppColors.ink : colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Each side',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: on ? AppColors.ink : colors.onSurface)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
