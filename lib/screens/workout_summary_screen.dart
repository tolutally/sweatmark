import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/duration_editor.dart';
import '../widgets/exercise_media.dart';
import '../models/template_model.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../models/workout_result.dart';
import '../state/exercise_db_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/template_notifier.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import 'workout_share_screen.dart';

/// This screen only presents a workout that has already been committed locally.
class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutLog? completedWorkout;
  final int? elapsedSeconds;
  final String? workoutName;
  const WorkoutSummaryScreen({
    super.key,
    this.completedWorkout,
    this.elapsedSeconds,
    this.workoutName,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  late final notes =
      TextEditingController(text: widget.completedWorkout?.notes ?? '');
  bool busy = false;
  bool routineSaved = false;

  ColorScheme get colors => Theme.of(context).colorScheme;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get panel => dark ? colors.surfaceContainer : AppColors.referencePanel;

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveNotes(WorkoutLog workout) async {
    setState(() => busy = true);
    try {
      await context
          .read<WorkoutNotifier>()
          .updateWorkoutHistoryNotes(workout, notes.text);
      _message('Notes saved');
    } catch (_) {
      _message('Could not save notes. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveRoutine(WorkoutLog workout) async {
    setState(() => busy = true);
    try {
      final result = await context.read<TemplateNotifier>().createTemplate(
            name: workout.workoutName,
            exercises: workout.exercises
                .map((exercise) => TemplateExercise(
                      id: exercise.exerciseId,
                      name: exercise.displayName,
                      targetSets: exercise.sets
                          .where(
                              (set) => set.isCompleted && !set.isSuperSetRest)
                          .length
                          .clamp(1, 100),
                    ))
                .toList(),
          );
      if (!mounted) return;
      setState(() => routineSaved = result != null);
      _message(result != null
          ? 'Routine saved'
          : 'Routine could not be saved. Try again when online.');
    } catch (_) {
      _message('Could not save this routine. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _share(WorkoutResultData data) async {
    setState(() => busy = true);
    try {
      await showWorkoutShare(context, data);
    } catch (_) {
      _message('Could not open the share preview. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _fallbackDuration() {
    final seconds = widget.elapsedSeconds;
    if (seconds == null || seconds <= 0) return 'Duration not recorded';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    return minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Future<void> _showNotes(WorkoutLog workout) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Workout notes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'How did it feel?'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      Navigator.of(sheetContext).pop();
                      await _saveNotes(workout);
                    },
              child: const Text('Save notes'),
            ),
          ),
        ]),
      ),
    );
  }

  String _ordinal(int value) {
    final mod100 = value % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${value}th';
    return switch (value % 10) {
      1 => '${value}st',
      2 => '${value}nd',
      3 => '${value}rd',
      _ => '${value}th',
    };
  }

  int _workoutNumber(WorkoutLog workout, List<WorkoutLog> history) {
    final eligible = <String, WorkoutLog>{
      for (final entry in history)
        if (!entry.isTestData &&
            !entry.timestamp.isAfter(workout.timestamp) &&
            entry.exercises.any((exercise) => exercise.sets
                .any((set) => set.isCompleted && !set.isSuperSetRest)))
          entry.id: entry,
      workout.id: workout,
    };
    return eligible.length;
  }

  Widget _hero(WorkoutResultData? data, int workoutNumber) {
    final workout = _saved(context.read<WorkoutNotifier>());
    String? image;
    for (final exercise in data?.exercises ?? const <WorkoutResultExercise>[]) {
      if (exercise.imageUrl != null && exercise.imageUrl!.isNotEmpty) {
        image = exercise.imageUrl;
        break;
      }
    }
    return SizedBox(
      height: 350,
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF3D2D55), Color(0xFF7D5278)]
                  : const [Color(0xFFD7C9FA), Color(0xFFF3B5C8)],
            ),
          ),
        ),
        if (image != null)
          ExerciseMedia(
            imageUrl: image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            color: const Color(0xFFB26089).withValues(alpha: .40),
            colorBlendMode: BlendMode.srcATop,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                colors.surface.withValues(alpha: .34),
                colors.surface,
              ],
              stops: const [.15, .62, 1],
            ),
          ),
        ),
        Positioned(
          left: 28,
          right: 20,
          top: MediaQuery.paddingOf(context).top + 22,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(
              child: Text('S W E A T M A R K',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            if (workout != null)
              PopupMenuButton<String>(
                tooltip: 'Workout options',
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .64),
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(42, 42),
                ),
                onSelected: (value) {
                  if (value == 'notes') _showNotes(workout);
                  if (value == 'routine') _saveRoutine(workout);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'notes', child: Text('Workout notes')),
                  PopupMenuItem(
                    value: 'routine',
                    enabled: !routineSaved,
                    child: Text(
                        routineSaved ? 'Routine saved' : 'Save as routine'),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded, size: 23),
              ),
          ]),
        ),
        Positioned(
          left: 28,
          right: 24,
          bottom: 34,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(workout?.workoutName ?? widget.workoutName ?? 'Workout',
                style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 38,
                    height: 1.03,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.35)),
            const SizedBox(height: 15),
            Wrap(spacing: 20, runSpacing: 9, children: [
              InkWell(
                onTap: workout == null ? null : () => _editTime(workout),
                borderRadius: BorderRadius.circular(8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _heroFact(Icons.schedule_rounded,
                      data?.durationLabel ?? _fallbackDuration()),
                  if (workout != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 15,
                        color: colors.onSurfaceVariant,
                        semanticLabel: 'Edit time'),
                  ],
                ]),
              ),
              _heroFact(Icons.drag_indicator_rounded,
                  'Your ${_ordinal(workoutNumber)} workout'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _heroFact(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _metric(String value, String label, IconData icon, Color accent) =>
      Container(
        height: 172,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
        decoration: BoxDecoration(
          color: dark ? colors.surfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                      color: const Color(0xFF292334).withValues(alpha: .045),
                      blurRadius: 25,
                      offset: const Offset(0, 10)),
                ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: accent,
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14), shape: BoxShape.circle),
              child: Icon(icon, size: 21, color: accent),
            ),
          ]),
          const Spacer(),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.onSurface,
                  fontSize: value.length > 12 ? 25 : 31,
                  height: 1.05,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.8)),
        ]),
      );

  Widget _metrics(WorkoutResultData data) =>
      LayoutBuilder(builder: (_, constraints) {
        final single = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.65;
        final width =
            single ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
        final metrics = [
          _metric('${data.completedSets}', 'Completed sets',
              Icons.done_all_rounded, const Color(0xFF6741B2)),
          _metric(
              '${data.streakWeeks} ${data.streakWeeks == 1 ? 'week' : 'weeks'}',
              'Weekly streak',
              Icons.trending_up_rounded,
              const Color(0xFF6741B2)),
          _metric('${data.newRecordCount}', 'New PRs',
              Icons.emoji_events_outlined, AppColors.coral),
          _metric(data.volumeLabel, 'Lifting volume',
              Icons.fitness_center_rounded, const Color(0xFF6741B2)),
        ];
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final metric in metrics) SizedBox(width: width, child: metric),
        ]);
      });

  Widget _exercise(WorkoutResultExercise exercise) {
    final image = exercise.imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: image != null && image.isNotEmpty
                ? ExerciseMedia(
                    imageUrl: image,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => Icon(Icons.fitness_center_outlined,
                        color: colors.onSurfaceVariant, size: 18),
                    errorWidget: (_, __, ___) => Icon(
                        Icons.fitness_center_outlined,
                        color: colors.onSurfaceVariant,
                        size: 18))
                : Icon(Icons.fitness_center_outlined,
                    color: colors.onSurfaceVariant, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(exercise.name,
                style: const TextStyle(
                    fontSize: 15, height: 1.25, fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Flexible(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(exercise.resultLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600)),
            ),
            if (exercise.isNewRecord || exercise.isBaseline) ...[
              const SizedBox(width: 7),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                      color: exercise.isNewRecord
                          ? AppColors.coral
                          : AppColors.paleLavender,
                      borderRadius: BorderRadius.circular(7)),
                  child: Text(exercise.isNewRecord ? 'PR' : 'BEST',
                      style: TextStyle(
                          color: exercise.isNewRecord
                              ? Colors.white
                              : const Color(0xFF6741B2),
                          fontSize: 10,
                          fontWeight: FontWeight.w700))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _footer(WorkoutResultData? data) => SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(26, 8, 26, 18),
      child: Row(children: [
        const Spacer(),
        SizedBox(
            width: 168,
            height: 58,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.ink,
                    shadowColor: const Color(0x668B6EE8),
                    elevation: 8),
                onPressed: busy
                    ? null
                    : () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                        colors: [AppColors.lavender, Color(0xFFC7B8FA)]),
                  ),
                  child: const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded, size: 27, color: AppColors.ink),
                      SizedBox(width: 10),
                      Text('Done',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ))),
        const Spacer(),
        IconButton(
            tooltip: 'Share workout',
            style: IconButton.styleFrom(
                backgroundColor: dark ? colors.surfaceContainer : Colors.white,
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outlineVariant),
                minimumSize: const Size(58, 58)),
            onPressed: data == null || busy ? null : () => _share(data),
            icon: const Icon(Icons.ios_share_rounded, size: 23)),
      ]));

  /// The saved copy of the finished workout, so edits such as a corrected
  /// time show here straight away.
  WorkoutLog? _saved(WorkoutNotifier workouts) {
    final finished = widget.completedWorkout;
    if (finished == null) return null;
    return workouts.workoutHistory
            .where((w) => w.id == finished.id)
            .firstOrNull ??
        finished;
  }

  Future<void> _editTime(WorkoutLog workout) async {
    final seconds = await showDurationEditor(context, workout.durationSeconds);
    if (seconds == null || !mounted) return;
    try {
      await context
          .read<WorkoutNotifier>()
          .updateWorkoutDuration(workout, seconds);
      _message('Time updated');
    } catch (_) {
      _message('Could not save the time. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutNotifier>();
    final workout = _saved(workouts);
    final settings = context.watch<SettingsNotifier>();
    final catalog = {
      for (final e in context.watch<ExerciseDbNotifier?>()?.exercises ??
          const <Exercise>[])
        e.id: e
    };
    final data = workout == null
        ? null
        : WorkoutResultData.fromWorkout(
            workout: workout,
            history: workouts.workoutHistory,
            records: workouts.personalRecords,
            weightUnit: settings.weightSuffix,
            distanceUnit: settings.distanceSuffix,
            weeklyGoals: settings.userSettings.weeklyGoals,
            catalogNames: {
              for (final entry in catalog.entries) entry.key: entry.value.name
            },
            catalog: catalog,
          );
    return Scaffold(
      backgroundColor: dark ? colors.surface : const Color(0xFFF5F5F8),
      extendBody: true,
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 132),
          children: [
            _hero(
                data,
                workout == null
                    ? 1
                    : _workoutNumber(workout, workouts.workoutHistory)),
            if (data != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _metrics(data),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                              '${data.exerciseCount} ${data.exerciseCount == 1 ? 'Exercise' : 'Exercises'}',
                              style: const TextStyle(
                                  color: Color(0xFF6741B2),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Text('Best Set',
                            style: TextStyle(
                                color: Color(0xFF6741B2),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 12),
                      if (data.exercises.isEmpty)
                        Text('No completed exercise sets.',
                            style: TextStyle(
                                fontSize: 14, color: colors.onSurfaceVariant)),
                      for (final exercise in data.exercises)
                        _exercise(exercise),
                      const SizedBox(height: 26),
                      if (workout != null)
                        Center(
                          child: Text('Saved · ${data.dateLabel}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant)),
                        ),
                    ]),
              ),
            ],
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _footer(data)),
      ]),
    );
  }
}
