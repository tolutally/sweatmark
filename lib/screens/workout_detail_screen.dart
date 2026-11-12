import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../widgets/duration_editor.dart';
import '../widgets/exercise_media.dart';
import '../models/exercise_model.dart';
import '../models/weekly_progress.dart';
import '../models/workout_model.dart';
import '../models/workout_result.dart';
import '../state/exercise_db_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/round_back_button.dart';
import 'active_workout_screen.dart';
import 'workout_share_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final WorkoutLog workout;
  final bool isEditable;

  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    this.isEditable = false,
  });

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text(
            'Are you sure you want to delete this workout? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context, 'deleted');
              context.read<WorkoutNotifier>().deleteWorkout(workout);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showWorkoutActions(BuildContext context) {
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
            const Text(
              'Workout Options',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsBold.copy,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(
                context.read<WorkoutNotifier>().isWorkoutActive
                    ? 'Resume Current Workout'
                    : 'Repeat Workout',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                context.read<WorkoutNotifier>().isWorkoutActive
                    ? 'Finish it before repeating this one'
                    : 'Start a new workout with these exercises',
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final notifier = context.read<WorkoutNotifier>();
                // Repeating resets the draft, so never replace one in progress.
                if (!notifier.isWorkoutActive) {
                  await notifier.repeatWorkout(workout);
                }
                if (!context.mounted) return;
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ActiveWorkoutScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesign.of(context).warningContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsBold.pencilSimple,
                  color: AppDesign.of(context).warning,
                  size: 20,
                ),
              ),
              title: const Text(
                'Edit Notes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Add or edit workout notes',
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditNotesDialog(context);
              },
            ),
            const Divider(height: 1),
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
              title: const Text(
                'Delete Workout',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Permanently delete this workout',
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _editTime(BuildContext context, WorkoutLog current) async {
    final seconds = await showDurationEditor(context, current.durationSeconds);
    if (seconds == null || !context.mounted) return;
    try {
      await context
          .read<WorkoutNotifier>()
          .updateWorkoutDuration(current, seconds);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save the time. Please try again.')));
      }
    }
  }

  void _showEditNotesDialog(BuildContext context) {
    final controller = TextEditingController(text: workout.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add workout notes...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context
                  .read<WorkoutNotifier>()
                  .updateWorkoutHistoryNotes(workout, controller.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notes updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  static String _duration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
  }

  static String _number(double value) => NumberFormat('#,##0.#').format(value);

  static bool _unknownUnit(WorkoutSet set) =>
      (set.weight ?? 0) > 0 && !['kg', 'lb'].contains(set.weightUnit);

  /// One recorded set in the terms it was logged; nothing is inferred. A
  /// missing weight unit is disclosed once per exercise, not on every set.
  static String _setLabel(WorkoutSet set) {
    final parts = <String>[];
    final weighted = set.weight != null && set.weight! > 0;
    final unit = _unknownUnit(set) ? '' : ' ${set.weightUnit}';
    if (weighted && (set.reps ?? 0) > 0) {
      parts.add('${_number(set.weight!)}$unit × ${set.reps}');
    } else if ((set.reps ?? 0) > 0) {
      parts.add('${set.reps} reps');
    } else if (weighted) {
      parts.add('${_number(set.weight!)}$unit');
    }
    if ((set.distance ?? 0) > 0) {
      parts.add(
          '${_number(set.distance!)} ${set.distanceUnit ?? 'unit unknown'}');
    }
    if ((set.durationSeconds ?? 0) > 0) {
      parts.add(_duration(set.durationSeconds!));
    }
    // Cardio sessions save average speed in their distance unit; older logs
    // saved a speed with no unit.
    if ((set.speed ?? 0) > 0) {
      parts.add(switch (set.distanceUnit) {
        'mi' => '${_number(set.speed!)} mph',
        'km' => '${_number(set.speed!)} km/h',
        _ => 'speed ${_number(set.speed!)}',
      });
    }
    if ((set.incline ?? 0) > 0) parts.add('${_number(set.incline!)}% incline');
    if ((set.resistance ?? 0) > 0) parts.add('level ${set.resistance}');
    if ((set.calories ?? 0) > 0) parts.add('${set.calories} kcal');
    return parts.isEmpty ? 'Not recorded' : parts.join(' · ');
  }

  static List<WorkoutSet> _completed(WorkoutExerciseLog exercise) =>
      exercise.sets
          .where((set) => set.isCompleted && !set.isSuperSetRest)
          .toList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final workouts = context.watch<WorkoutNotifier>();
    final settings = context.watch<SettingsNotifier>();
    final catalog = {
      for (final e in context.watch<ExerciseDbNotifier?>()?.exercises ??
          const <Exercise>[])
        e.id: e
    };
    final catalogNames = {
      for (final entry in catalog.entries) entry.key: entry.value.name
    };
    // Edited notes live in history; prefer the stored copy of this workout.
    final current = workouts.workoutHistory
            .where((entry) => entry.id == workout.id)
            .firstOrNull ??
        workout;
    final result = WorkoutResultData.fromWorkout(
      workout: current,
      history: workouts.workoutHistory,
      records: workouts.personalRecords,
      weightUnit: settings.weightSuffix,
      distanceUnit: settings.distanceSuffix,
      weeklyGoals: settings.userSettings.weeklyGoals,
      catalogNames: catalogNames,
      catalog: catalog,
    );
    final exercises =
        current.exercises.where((e) => _completed(e).isNotEmpty).toList();
    final totalReps = [
      for (final exercise in exercises)
        for (final set in _completed(exercise)) set.reps ?? 0
    ].fold<int>(0, (sum, reps) => sum + reps);

    // The week this workout belongs to, counted like the Home weekly goal.
    final week = weekStart(current.timestamp);
    final weekLogs = <String, WorkoutLog>{
      for (final entry in [...workouts.workoutHistory, current])
        if (!entry.isTestData &&
            weekKey(entry.timestamp) == weekKey(week) &&
            entry.exercises.any((e) => _completed(e).isNotEmpty))
          entry.id: entry,
    }.values;
    final trainedDays = {
      for (final entry in weekLogs) entry.timestamp.toLocal().weekday
    };
    final goal = goalForWeek(settings.userSettings.weeklyGoals, week);

    final panel = dark ? colors.surfaceContainerLow : AppColors.referencePanel;
    final muted = colors.onSurfaceVariant;
    const title = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);

    Widget panelBox(Widget child) => Container(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
          decoration: BoxDecoration(
              color: panel, borderRadius: BorderRadius.circular(30)),
          child: child,
        );
    Widget whiteCard(Widget child, {EdgeInsets? padding}) => Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: colors.surface, borderRadius: BorderRadius.circular(24)),
          child: child,
        );
    Widget badge(IconData icon, Color fill, {Color? iconColor}) => Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: fill.withValues(alpha: .35), width: 4),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
        );
    Widget progressBar(double value, Color color) => ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 14,
            color: color,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        );
    Widget sectionHeader(String text, {VoidCallback? onMore}) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 0, 12),
          child: Row(children: [
            Expanded(child: Text(text, style: title)),
            if (onMore != null)
              IconButton(
                tooltip: 'Workout options',
                onPressed: onMore,
                style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    minimumSize: const Size(40, 40)),
                icon: const Icon(PhosphorIconsBold.dotsThree, size: 20),
              ),
          ]),
        );

    final metrics = [
      (
        'Duration',
        current.durationSeconds > 0
            ? _duration(current.durationSeconds)
            : 'Not recorded'
      ),
      ('Sets', '${result.completedSets}'),
      ('Reps', totalReps > 0 ? '$totalReps' : '—'),
      ('Volume', result.volumeLabel),
    ];
    final prNames = result.exercises
        .where((exercise) => exercise.isNewRecord)
        .map((exercise) => exercise.name)
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 72,
          leading: const Padding(
              padding: EdgeInsets.only(left: 16), child: RoundBackButton()),
          centerTitle: true,
          title: const Text('Workout details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          actions: [
            IconButton(
              tooltip: 'Share workout',
              onPressed: () => showWorkoutShare(context, result),
              style: IconButton.styleFrom(
                  backgroundColor: panel, minimumSize: const Size(48, 48)),
              icon: const Icon(PhosphorIconsRegular.export),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: 'More workout options',
                onPressed: () => _showWorkoutActions(context),
                style: IconButton.styleFrom(
                    backgroundColor: panel, minimumSize: const Size(48, 48)),
                icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            panelBox(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionHeader('Overview',
                      onMore: () => _showWorkoutActions(context)),
                  // Workout identity and the week it counted toward.
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(26)),
                    child: Column(children: [
                      whiteCard(Row(children: [
                        badge(PhosphorIconsBold.barbell, AppColors.lavender),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(current.workoutName,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text(
                                    DateFormat('EEE, MMM d, yyyy · h:mm a')
                                        .format(current.timestamp.toLocal()),
                                    style:
                                        TextStyle(fontSize: 13, color: muted)),
                              ]),
                        ),
                      ])),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        decoration: BoxDecoration(
                          color: dark
                              ? colors.surface
                              : AppColors.referenceLavenderPanel,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: colors.primaryContainer, width: 1.5),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                      'Week of ${DateFormat('MMM d').format(week)}',
                                      style: TextStyle(
                                          fontSize: 15, color: muted)),
                                ),
                                Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                          text: '${weekLogs.length}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      TextSpan(
                                          text: '/$goal',
                                          style: TextStyle(color: muted)),
                                    ]),
                                    style: const TextStyle(fontSize: 15)),
                              ]),
                              const SizedBox(height: 12),
                              progressBar(
                                  weekLogs.length / goal, AppColors.lavender),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (var day = 1; day <= 7; day++)
                                    Flexible(
                                        child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: _DayRing(
                                              label: 'MTWTFSS'[day - 1],
                                              trained:
                                                  trainedDays.contains(day),
                                              isThisWorkout: current.timestamp
                                                      .toLocal()
                                                      .weekday ==
                                                  day,
                                            ))),
                                ],
                              ),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  // Session totals.
                  whiteCard(
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            badge(PhosphorIconsBold.target, AppColors.lime,
                                iconColor: AppColors.ink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Session totals',
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 3),
                                    Text(
                                        '${exercises.length} ${exercises.length == 1 ? 'exercise' : 'exercises'}',
                                        style: TextStyle(
                                            fontSize: 13, color: muted)),
                                  ]),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.lime.withValues(alpha: .16)
                                  : const Color(0xFFF1F9C4),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              prNames.isEmpty
                                  ? 'Saved to your history. Every completed set counts toward your progress.'
                                  : '${prNames.length} new personal ${prNames.length == 1 ? 'record' : 'records'}: ${prNames.join(', ')}.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: panel,
                                borderRadius: BorderRadius.circular(18)),
                            child: LayoutBuilder(builder: (context, box) {
                              final width = box.maxWidth < 260
                                  ? box.maxWidth
                                  : (box.maxWidth - 12) / 2;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 14,
                                children: [
                                  for (final (label, value) in metrics)
                                    SizedBox(
                                      width: width,
                                      child: InkWell(
                                        // The time can be corrected after
                                        // the workout.
                                        onTap: label == 'Duration'
                                            ? () => _editTime(context, current)
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Text(label,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: muted)),
                                                if (label == 'Duration') ...[
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit_outlined,
                                                      size: 13,
                                                      color: muted,
                                                      semanticLabel:
                                                          'Edit time'),
                                                ],
                                              ]),
                                              const SizedBox(height: 2),
                                              Text(value,
                                                  style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ]),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ]),
                  ),
                ])),
            if (current.notes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 16),
              panelBox(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 0, 12),
                      child: Row(children: [
                        const Expanded(child: Text('Notes', style: title)),
                        IconButton(
                          tooltip: 'Edit notes',
                          onPressed: () => _showEditNotesDialog(context),
                          style: IconButton.styleFrom(
                              backgroundColor: colors.surface,
                              minimumSize: const Size(40, 40)),
                          icon: const Icon(PhosphorIconsRegular.pencilSimple,
                              size: 18),
                        ),
                      ]),
                    ),
                    whiteCard(Text(current.notes!.trim(),
                        style: const TextStyle(fontSize: 15, height: 1.4))),
                  ])),
            ],
            const SizedBox(height: 16),
            panelBox(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionHeader('Exercises'),
                  if (exercises.isEmpty)
                    whiteCard(Text('No completed sets were saved.',
                        style: TextStyle(fontSize: 15, color: muted))),
                  for (final (index, exercise) in exercises.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: whiteCard(
                        _ExerciseDetails(
                          exercise: exercise,
                          sets: _completed(exercise),
                          summary: result.exercises
                              .where((row) =>
                                  row.exerciseId == exercise.exerciseId)
                              .firstOrNull,
                          name: exerciseDisplayName(exercise.exerciseId,
                              saved: exercise.exerciseName,
                              catalog: catalogNames),
                          setLabel: _setLabel,
                          unknownUnit: _completed(exercise).any(_unknownUnit),
                          accent: _ExerciseDetails
                              .accents[index % _ExerciseDetails.accents.length],
                        ),
                      ),
                    ),
                ])),
          ],
        ),
      ),
    );
  }
}

class _DayRing extends StatelessWidget {
  final String label;
  final bool trained;
  final bool isThisWorkout;
  const _DayRing(
      {required this.label,
      required this.trained,
      required this.isThisWorkout});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label ${trained ? 'trained' : 'no workout'}',
      excludeSemantics: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trained ? AppColors.paleLavender : colors.surface,
            border: Border.all(
              color: isThisWorkout
                  ? colors.onSurface
                  : trained
                      ? AppColors.lavender
                      : colors.outlineVariant,
              width: isThisWorkout ? 3 : 2.5,
            ),
          ),
          child: trained
              ? const Icon(Icons.check_rounded,
                  size: 16, color: Color(0xFF6741B2))
              : null,
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: trained ? FontWeight.w600 : FontWeight.w400,
                color: trained ? colors.onSurface : colors.onSurfaceVariant)),
      ]),
    );
  }
}

class _ExerciseDetails extends StatefulWidget {
  final WorkoutExerciseLog exercise;
  final List<WorkoutSet> sets;
  final WorkoutResultExercise? summary;
  final String name;
  final String Function(WorkoutSet) setLabel;
  final bool unknownUnit;
  final (Color, Color) accent;

  // Decorative rhythm only; (tile fill, icon color).
  static const accents = [
    (AppColors.lavender, AppColors.ink),
    (AppColors.lime, AppColors.ink),
    (AppColors.coral, Colors.white),
    (AppColors.ink, AppColors.lime),
  ];

  const _ExerciseDetails(
      {required this.exercise,
      required this.sets,
      required this.summary,
      required this.name,
      required this.setLabel,
      required this.unknownUnit,
      required this.accent});

  @override
  State<_ExerciseDetails> createState() => _ExerciseDetailsState();
}

class _ExerciseDetailsState extends State<_ExerciseDetails> {
  // Collapsed by default so long workouts scan quickly.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final sets = widget.sets;
    final summary = widget.summary;
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurfaceVariant;
    final image = exercise.gifUrl?.trim();
    final hasImage = image != null && image.isNotEmpty;
    final (fill, iconColor) = widget.accent;
    final icon = Center(
        child: Icon(PhosphorIconsBold.barbell, size: 20, color: iconColor));
    final name = widget.name;
    final details = [
      '${sets.length} ${sets.length == 1 ? 'set' : 'sets'}',
      if (exercise.muscleGroup?.trim().isNotEmpty == true)
        exercise.muscleGroup!.trim(),
      if (widget.unknownUnit) 'weight unit not recorded',
      if (exercise.averageHeartRate != null)
        '${exercise.averageHeartRate} bpm avg',
      if (exercise.intensity?.trim().isNotEmpty == true)
        '${exercise.intensity!.trim()} effort',
    ].join(' · ');
    void toggle() => setState(() => _expanded = !_expanded);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: toggle,
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            // Artwork sits on a white disc inside a colored ring.
            padding: EdgeInsets.all(hasImage ? 3 : 0),
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: hasImage
                ? ClipOval(
                    child: ColoredBox(
                      color: Colors.white,
                      child: ExerciseMedia(
                        imageUrl: image,
                        fit: BoxFit.contain,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, __) => icon,
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: fill, child: icon),
                      ),
                    ),
                  )
                : icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(details, style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ),
          if (summary?.isNewRecord == true) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('PR',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            tooltip: _expanded ? 'Collapse $name' : 'Expand $name',
            onPressed: toggle,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.outlineVariant)),
            ),
            icon: AnimatedRotation(
              turns: _expanded ? .5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            ),
          ),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: !_expanded
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? colors.surfaceContainerLow
                        : AppColors.referencePanel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    for (var i = 0; i < sets.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(
                            width: 52,
                            child: Text('Set ${i + 1}',
                                style: TextStyle(fontSize: 13, color: muted)),
                          ),
                          Expanded(
                            child: Text(widget.setLabel(sets[i]),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                      ),
                  ]),
                ),
              ),
      ),
    ]);
  }
}
