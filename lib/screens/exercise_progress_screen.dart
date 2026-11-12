import '../data/exercise_catalog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/workout_model.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';
import '../services/pr_service.dart';
import '../theme/app_theme.dart';

class ExerciseProgressScreen extends StatelessWidget {
  final String exerciseId;
  final String name;
  final String? section;
  const ExerciseProgressScreen(
      {super.key, required this.exerciseId, required this.name, this.section});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unit = context.watch<SettingsNotifier>().weightSuffix;
    final history = context
        .watch<WorkoutNotifier>()
        .workoutHistory
        .where((w) =>
            !w.isTestData &&
            w.exercises.any((e) =>
                ExerciseCatalog.sameExercise(e.exerciseId, exerciseId,
                    nameA: e.exerciseName) &&
                e.sets.any((s) => s.isCompleted && !s.isSuperSetRest)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    List<WorkoutSet> sets(WorkoutLog w) => w.exercises
        .where((e) => ExerciseCatalog.sameExercise(e.exerciseId, exerciseId,
            nameA: e.exerciseName))
        .expand((e) => e.sets)
        .where((s) => s.isCompleted && !s.isSuperSetRest)
        .toList();
    final best = PRService.bestSet(history.expand(sets));
    final chart = history.reversed
        .where((w) => PRService.bestSet(sets(w)) != null)
        .toList();
    final panel = Theme.of(context).brightness == Brightness.dark
        ? colors.surfaceContainer
        : AppColors.referencePanel;

    return Scaffold(
      body: SafeArea(
        top: section == null,
        child: Column(children: [
          if (section == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: panel,
                    foregroundColor: colors.onSurface,
                    minimumSize: const Size(46, 46),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(name,
                        textAlign: TextAlign.center, style: text.titleLarge)),
                const SizedBox(width: 58),
              ]),
            ),
          Expanded(
            child: ListView(
              padding:
                  EdgeInsets.fromLTRB(16, section == null ? 0 : 12, 16, 28),
              children: [
                if (history.isEmpty)
                  _panel(context, [
                    _icon(context, Icons.show_chart_rounded),
                    const SizedBox(height: 14),
                    Text('Your progress', style: text.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        'No completed sets yet. Log this exercise to start tracking your progress.',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ]),
                if (best != null && section != 'history')
                  _panel(context, [
                    Text('Your progress', style: text.titleLarge),
                    const SizedBox(height: 16),
                    _inset(
                      context,
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _icon(context, Icons.emoji_events_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Best completed set',
                                        style: text.bodySmall?.copyWith(
                                            color: colors.onSurfaceVariant)),
                                    const SizedBox(height: 5),
                                    Text(
                                        '${best.weightLabel} × ${best.reps} reps',
                                        style: text.headlineSmall),
                                  ]),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _metric(context, Icons.history_rounded,
                          '${history.length} sessions'),
                      _metric(context, Icons.check_rounded,
                          '${history.expand(sets).length} completed sets'),
                    ]),
                  ]),
                if (chart.length >= 2 && section != 'history') ...[
                  const SizedBox(height: 18),
                  _panel(context, [
                    Text('Heaviest completed set ($unit)',
                        style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                        'Each point is a session, oldest to newest. Tap a point for its date.',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 18),
                    _inset(
                      context,
                      Column(children: [
                        SizedBox(
                          height: 190,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
                            child: LineChart(LineChartData(
                              minY: 0,
                              titlesData: const FlTitlesData(show: false),
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                    color: colors.outlineVariant,
                                    strokeWidth: 1,
                                    dashArray: [3, 4]),
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  getTooltipColor: (_) => colors.inverseSurface,
                                  getTooltipItems: (spots) => spots
                                      .map((spot) => LineTooltipItem(
                                          '${DateFormat('MMM d, yyyy · h:mm a').format(chart[spot.x.toInt()].timestamp.toLocal())}\n${spot.y.toStringAsFixed(1)} $unit',
                                          TextStyle(
                                              color: colors.onInverseSurface,
                                              fontSize: 13)))
                                      .toList(),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  color: AppColors.lavender,
                                  barWidth: 3,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.lavender
                                            .withValues(alpha: .25),
                                        AppColors.lavender
                                            .withValues(alpha: .02),
                                      ],
                                    ),
                                  ),
                                  dotData: FlDotData(
                                      getDotPainter: (_, __, ___, ____) =>
                                          FlDotCirclePainter(
                                              radius: 4,
                                              color: AppColors.lavender,
                                              strokeWidth: 2,
                                              strokeColor: colors.surface)),
                                  isCurved: false,
                                  spots: [
                                    for (var i = 0; i < chart.length; i++)
                                      FlSpot(
                                          i.toDouble(),
                                          PRService.bestSet(sets(chart[i]))!
                                                  .weightKg! *
                                              (unit == 'lb' ? 2.2046226218 : 1))
                                  ],
                                )
                              ],
                            )),
                          ),
                        ),
                        Row(children: [
                          Expanded(
                              child: Text(
                                  DateFormat('MMM d')
                                      .format(chart.first.timestamp.toLocal()),
                                  style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant))),
                          Expanded(
                              child: Text(
                                  DateFormat('MMM d')
                                      .format(chart.last.timestamp.toLocal()),
                                  textAlign: TextAlign.right,
                                  style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant))),
                        ]),
                      ]),
                    ),
                  ]),
                ],
                if (section == 'chart' && chart.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _panel(context, [
                      _icon(context, Icons.show_chart_rounded),
                      const SizedBox(height: 12),
                      Text(
                          'Complete two sessions with recorded weights and units to see your chart.',
                          style: text.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ]),
                  ),
                if (history.isNotEmpty && section != 'chart') ...[
                  const SizedBox(height: 18),
                  _panel(context, [
                    Text('Previous sessions', style: text.titleLarge),
                    const SizedBox(height: 16),
                    for (var i = 0; i < history.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _session(context, history[i], sets(history[i])),
                    ],
                  ]),
                ],
                if (history
                    .expand(sets)
                    .any((s) => s.weight != null && s.weightUnit == null))
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                          'Older entries without a recorded unit are shown unchanged and excluded from weight comparisons.',
                          style: text.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant))),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _session(
      BuildContext context, WorkoutLog workout, List<WorkoutSet> sets) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final logged = workout.timestamp.toLocal();
    return _inset(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _icon(context, Icons.fitness_center_outlined),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('MMM d, yyyy').format(logged),
                  style: text.titleMedium),
              const SizedBox(height: 3),
              Text('Logged ${DateFormat('h:mm a').format(logged)}',
                  style:
                      text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ]),
          ),
        ]),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: colors.outlineVariant)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final set in sets)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(_setLabel(set), style: text.bodySmall),
            ),
        ]),
      ]),
    );
  }

  String _setLabel(WorkoutSet set) {
    if (set.weight != null) return '${set.weightLabel} × ${set.reps ?? 0}';
    if (set.reps != null) return '${set.reps} reps';
    final distance = set.distance == null
        ? ''
        : ' · ${set.distance} ${set.distanceUnit ?? 'distance units'}';
    return '${set.durationSeconds ?? 0}s$distance';
  }

  Widget _panel(BuildContext context, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _inset(BuildContext context, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      );

  Widget _icon(BuildContext context, IconData icon) => Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
            color: AppColors.lavender, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: AppColors.ink),
      );

  Widget _metric(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: AppColors.lavender),
          const SizedBox(width: 8),
          Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class PreviousSets extends StatelessWidget {
  final String exerciseId;
  const PreviousSets({super.key, required this.exerciseId});
  @override
  Widget build(BuildContext context) {
    // One pass for the most recent workout with this exercise; sorting the
    // whole history here ran on every keystroke while logging.
    WorkoutLog? latest;
    List<WorkoutSet> latestSets = const [];
    for (final workout in context.watch<WorkoutNotifier>().workoutHistory) {
      if (workout.isTestData) continue;
      if (latest != null && !workout.timestamp.isAfter(latest.timestamp)) {
        continue;
      }
      final sets = workout.exercises
          .where((e) => ExerciseCatalog.sameExercise(e.exerciseId, exerciseId,
              nameA: e.exerciseName))
          .expand((e) => e.sets)
          .where((s) => s.isCompleted && !s.isSuperSetRest)
          .toList();
      if (sets.isEmpty) continue;
      latest = workout;
      latestSets = sets;
    }
    if (latest == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: dark ? colors.primaryContainer : AppColors.paleLavender,
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.history_rounded, size: 16, color: colors.onSurface),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              'Last time: ${latestSets.map((s) => s.weight != null ? '${s.weightLabel} × ${s.reps ?? 0}' : s.reps != null ? '${s.reps} reps' : '${s.durationSeconds ?? 0}s').join(' · ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface)),
        ),
      ]),
    );
  }
}
