import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/exercise_model.dart';
import '../models/monthly_stats.dart';
import '../models/user_settings.dart';
import '../models/workout_model.dart';
import '../services/apple_health_service.dart';
import '../services/pr_service.dart';
import '../state/auth_notifier.dart';
import '../state/exercise_db_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/apple_health_activity.dart';
import '../widgets/personal_records.dart';
import 'exercise_progress_screen.dart';
import 'workout_detail_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _year = false;
  String get _period =>
      _year ? '${_month.year}' : DateFormat('MMMM yyyy').format(_month);
  ColorScheme get colors => Theme.of(context).colorScheme;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get panel => dark ? colors.surfaceContainer : AppColors.referencePanel;
  Color get softLavender =>
      dark ? colors.primaryContainer : AppColors.referenceLavenderPanel;
  Color get muted => colors.onSurfaceVariant;

  String _time(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    return minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Widget _note(String text) =>
      Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: muted));

  Widget _surface(Widget child,
          {Color? color, double padding = 16, double radius = 28}) =>
      Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
              color: color ?? colors.surface,
              borderRadius: BorderRadius.circular(radius)),
          child: child);

  Widget _icon(IconData icon, Color accent, {double size = 40}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      child: Icon(icon,
          size: 20,
          color: accent == AppColors.lavender || accent == AppColors.coral
              ? Colors.white
              : AppColors.ink));

  Widget _heading(String title, IconData icon,
          {Color accent = AppColors.lavender}) =>
      Row(children: [
        _icon(icon, accent),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)))
      ]);

  Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3, child: Text(label, style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 12),
        Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))
      ]));

  Widget _metrics(List<Widget> items) =>
      LayoutBuilder(builder: (_, constraints) {
        final single = constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in items)
            SizedBox(
                width: single
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2,
                child: item)
        ]);
      });

  Widget _metric(String value, String label, IconData icon,
          {Color accent = AppColors.paleLavender, bool onPanel = false}) =>
      _surface(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _icon(icon, accent, size: 34),
            const SizedBox(height: 10),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            _note(label)
          ]),
          color: onPanel ? colors.surface : panel,
          radius: 22,
          padding: 14);

  Widget _bar(String label, int count, int largest,
          {Color accent = AppColors.lavender, VoidCallback? onTap}) =>
      Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: Text(label,
                                  style: const TextStyle(fontSize: 15))),
                          const SizedBox(width: 10),
                          Text('$count',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                          if (onTap != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: muted)
                          ]
                        ]),
                        const SizedBox(height: 9),
                        Semantics(
                            label: '$label: $count',
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                    value: largest > 0 ? count / largest : 0,
                                    minHeight: 10,
                                    color: accent,
                                    backgroundColor: panel)))
                      ])))));

  Widget _entries(MonthlyStats data, Map<String, Exercise> catalog,
      {bool cardio = false, int? limit}) {
    final workouts = data.loggedWorkouts
        .where((w) =>
            !cardio ||
            w.exercises.any((e) =>
                MonthlyStats.isCardio(e, catalog[e.exerciseId]) &&
                e.sets.any((s) => s.isCompleted && !s.isSuperSetRest)))
        .take(limit ?? data.loggedWorkouts.length)
        .toList();
    return _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cardio ? 'Logged cardio' : 'Logged workouts',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (workouts.isEmpty) _note('No entries in this period.'),
          for (var index = 0; index < workouts.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _loggedCard(workouts[index], catalog, cardio: cardio),
          ]
        ]),
        color: panel);
  }

  Widget _loggedCard(WorkoutLog workout, Map<String, Exercise> catalog,
      {bool cardio = false}) {
    final completedSets = workout.exercises
        .expand((e) => e.sets)
        .where((s) => s.isCompleted && !s.isSuperSetRest)
        .length;
    final exercises = workout.exercises.where((e) =>
        MonthlyStats.isCardio(e, catalog[e.exerciseId]) &&
        e.sets.any((s) => s.isCompleted && !s.isSuperSetRest));
    return _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Material(
              color: Colors.transparent,
              child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              WorkoutDetailScreen(workout: workout))),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        _icon(
                            cardio
                                ? Icons.directions_run_rounded
                                : Icons.fitness_center_outlined,
                            cardio ? AppColors.lime : AppColors.lavender),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(workout.workoutName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              _note(
                                  'Logged ${DateFormat('MMM d, yyyy · h:mm a').format(workout.timestamp.toLocal())}')
                            ])),
                        const SizedBox(width: 4),
                        Container(
                            width: 34,
                            height: 40,
                            decoration: BoxDecoration(
                                color: softLavender,
                                borderRadius: BorderRadius.circular(16)),
                            child: Icon(Icons.chevron_right_rounded,
                                color: colors.onSurface, size: 20))
                      ])))),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: softLavender)),
          _metrics([
            _metric(
                workout.durationSeconds > 0
                    ? _time(workout.durationSeconds)
                    : '—',
                workout.durationSeconds > 0
                    ? 'workout time'
                    : 'Duration not recorded',
                Icons.timer_outlined),
            _metric('$completedSets', 'completed sets',
                Icons.fitness_center_outlined)
          ]),
          if (cardio)
            for (final exercise in exercises) ...[
              const SizedBox(height: 16),
              Text(
                  exercise.exerciseName ??
                      catalog[exercise.exerciseId]?.name ??
                      'Cardio exercise',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              _note(
                  'Average HR: ${exercise.averageHeartRate == null ? 'Not recorded' : '${exercise.averageHeartRate} bpm'} · Effort: ${exercise.intensity ?? 'Not recorded'}'),
              for (final set in exercise.sets
                  .where((s) => s.isCompleted && !s.isSuperSetRest))
                _note(
                    '${set.durationSeconds == null ? 'Time not recorded' : _time(set.durationSeconds!)} · ${set.distance == null ? 'Distance not recorded' : '${set.distance} ${set.distanceUnit ?? '(unit not recorded)'}'}'),
            ]
        ]),
        padding: 14,
        radius: 26);
  }

  void _details(String title, List<Widget> content) {
    final period = _period;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        clipBehavior: Clip.antiAlias,
        builder: (sheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .88,
            minChildSize: .4,
            maxChildSize: .96,
            builder: (_, controller) => Column(children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Row(children: [
                        const SizedBox(width: 44),
                        Expanded(
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500))),
                        IconButton(
                            tooltip: 'Close details',
                            style: IconButton.styleFrom(
                                backgroundColor: panel,
                                foregroundColor: colors.onSurface,
                                minimumSize: const Size(44, 44)),
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close_rounded, size: 21))
                      ])),
                  Expanded(
                      child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                          children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                    color: softLavender,
                                    borderRadius: BorderRadius.circular(22)),
                                child: Text(period,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)))),
                        const SizedBox(height: 16),
                        for (final section in content)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: section)
                      ]))
                ])));
  }

  /// Movement from Apple Health for the selected period, up to now.
  Widget _healthSection(DateTime now, UserSettings settings) {
    final start =
        _year ? DateTime(_month.year) : DateTime(_month.year, _month.month);
    final next = _year
        ? DateTime(_month.year + 1)
        : DateTime(_month.year, _month.month + 1);
    // Keep "now" stable within a minute so rebuilds do not refetch.
    final cap = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return AppleHealthActivity(
      uid: context.watch<AuthNotifier?>()?.user?.uid,
      start: start,
      end: next.isAfter(cap) ? cap : next,
      miles: settings.distanceUnit == DistanceUnit.miles,
    );
  }

  Widget _tile(String title, String value, String subtitle, IconData icon,
          Color accent, VoidCallback tap) =>
      Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(25),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: tap,
              child: Semantics(
                  button: true,
                  child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _icon(icon, accent, size: 36),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded,
                                  size: 19, color: muted)
                            ]),
                            const SizedBox(height: 14),
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(value,
                                style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -.6)),
                            const SizedBox(height: 3),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 12, height: 1.35, color: muted)),
                          ])))));

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
        context: context,
        initialDate: _month.isAfter(now) ? now : _month,
        firstDate: DateTime(1970),
        lastDate: now,
        helpText:
            _year ? 'Choose a date in the year' : 'Choose a date in the month');
    if (chosen != null && mounted) {
      setState(() => _month = DateTime(chosen.year, chosen.month));
    }
  }

  Widget _periodControl(bool current, DateTime now) => _surface(
      Column(children: [
        Row(children: [
          for (final yearly in [false, true])
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(
                        selected: _year == yearly,
                        button: true,
                        child: Material(
                            color: _year == yearly
                                ? AppColors.lavender
                                : colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => setState(() {
                                      _year = yearly;
                                      if (!_year &&
                                          _month.year == now.year &&
                                          _month.month > now.month) {
                                        _month = DateTime(now.year, now.month);
                                      }
                                    }),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(yearly ? 'Year' : 'Month',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: _year == yearly
                                                ? AppColors.ink
                                                : colors.onSurface))))))))
        ]),
        const SizedBox(height: 10),
        Row(children: [
          IconButton(
              tooltip: _year ? 'Previous year' : 'Previous month',
              onPressed: () => setState(() => _month = _year
                  ? DateTime(_month.year - 1, _month.month)
                  : DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
              child: Text(_period,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500))),
          IconButton(
              tooltip: _year ? 'Next year' : 'Next month',
              onPressed: current
                  ? null
                  : () => setState(() => _month = _year
                      ? DateTime(
                          _month.year + 1, math.min(_month.month, now.month))
                      : DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded))
        ]),
        if (!current)
          TextButton(
              onPressed: () =>
                  setState(() => _month = DateTime(now.year, now.month)),
              child: Text(_year ? 'This year' : 'This month'))
      ]),
      color: panel,
      padding: 9);

  Widget _activityChart(MonthlyStats data, DateTime now) {
    final buckets = _year ? data.monthlyWorkouts : data.dailyWorkouts;
    final maxCount = buckets.fold<int>(1, math.max);
    return _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Showing up', Icons.calendar_month_outlined),
          const SizedBox(height: 12),
          _note(data.workouts == 0
              ? 'No completed workouts this ${_year ? 'year' : 'month'} yet.'
              : _year
                  ? 'Workouts by month · tap a month to explore.'
                  : 'Workouts by day · every session counts.'),
          const SizedBox(height: 20),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: List.generate(buckets.length, (i) {
                final date = _year
                    ? DateTime(_month.year, i + 1)
                    : DateTime(_month.year, _month.month, i + 1);
                final active = buckets[i] > 0;
                final canOpen =
                    _year && !(_month.year == now.year && i + 1 > now.month);
                final label =
                    _year ? DateFormat('MMMM').format(date) : 'Day ${i + 1}';
                return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                        label: '$label: ${buckets[i]} workouts',
                        button: canOpen,
                        child: Material(
                            color: active ? AppColors.lavender : colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: canOpen
                                    ? () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _month = date;
                                          _year = false;
                                        });
                                      }
                                    : null,
                                child: Container(
                                    width: 48,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Column(children: [
                                      Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                              color: active
                                                  ? AppColors.ink
                                                      .withValues(alpha: .65)
                                                  : colors.outlineVariant,
                                              shape: BoxShape.circle)),
                                      const SizedBox(height: 9),
                                      Text(
                                          _year
                                              ? DateFormat('MMM').format(date)
                                              : DateFormat('E').format(date),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: active
                                                  ? AppColors.ink
                                                  : muted)),
                                      const SizedBox(height: 4),
                                      Text(_year ? '${buckets[i]}' : '${i + 1}',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: active
                                                  ? AppColors.ink
                                                  : colors.onSurface))
                                    ]))))));
              }))),
          const SizedBox(height: 24),
          _surface(
              Column(children: [
                SizedBox(
                    height: 105,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                            buckets.length,
                            (i) => Expanded(
                                child: Tooltip(
                                    message:
                                        '${_year ? DateFormat('MMMM').format(DateTime(_month.year, i + 1)) : 'Day ${i + 1}'}: ${buckets[i]} workouts',
                                    child: InkWell(
                                        onTap: _year &&
                                                !(_month.year == now.year &&
                                                    i + 1 > now.month)
                                            ? () {
                                                Navigator.pop(context);
                                                setState(() {
                                                  _month = DateTime(
                                                      _month.year, i + 1);
                                                  _year = false;
                                                });
                                              }
                                            : null,
                                        child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            height: buckets[i] == 0
                                                ? 4
                                                : 105 * buckets[i] / maxCount,
                                            decoration: BoxDecoration(
                                                color: buckets[i] == 0
                                                    ? panel
                                                    : AppColors.lavender,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8))))))))),
                const SizedBox(height: 9),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _note(_year ? 'Jan' : '1'),
                      _note(_year ? 'Jun' : '15'),
                      _note(_year ? 'Dec' : '${data.dailyWorkouts.length}')
                    ])
              ]),
              padding: 14,
              radius: 24)
        ]),
        color: panel);
  }

  Widget _timeOverview(MonthlyStats data) => _surface(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _heading('Workout duration', Icons.timer_outlined),
        const SizedBox(height: 22),
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                        painter: _DurationRing(
                            fraction: data.workouts == 0
                                ? 0
                                : data.timedWorkouts / data.workouts,
                            track: colors.surface,
                            accent: AppColors.lavender),
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(36),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          data.timedWorkouts == 0
                                              ? '—'
                                              : _time(data.totalSeconds),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -.6)),
                                      const SizedBox(height: 4),
                                      Text('Total time',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 13, color: muted))
                                    ]))))))),
        const SizedBox(height: 16),
        Center(
            child: Text(
                'Duration recorded for ${data.timedWorkouts} of ${data.workouts} workouts',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted))),
        const SizedBox(height: 20),
        _surface(
            _metrics([
              _metric(
                  data.averageSeconds == null
                      ? '—'
                      : _time(data.averageSeconds!),
                  'Average workout',
                  Icons.schedule_rounded),
              _metric('${data.timedWorkouts}', 'with recorded time',
                  Icons.check_circle_outline,
                  accent: AppColors.lime)
            ]),
            padding: 12),
        const SizedBox(height: 14),
        _note(
            'Includes rest. ${data.timedWorkouts} of ${data.workouts} workouts have recorded durations. Missing durations are excluded from the average.')
      ]),
      color: panel);

  @override
  Widget build(BuildContext context) {
    final history = context.watch<WorkoutNotifier>().workoutHistory;
    final allRecords = PRService.records(history);
    final recentRecords = allRecords
        .where((r) =>
            !r.isBaseline &&
            r.timestamp.toLocal().year == _month.year &&
            (_year || r.timestamp.toLocal().month == _month.month))
        .toList()
        .reversed
        .toList();
    final bestRecords = {for (final r in allRecords) r.key: r}.values.toList()
      ..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
    final catalog = <String, Exercise>{
      for (final e
          in context.watch<ExerciseDbNotifier?>()?.exercises ?? <Exercise>[])
        e.id: e
    };
    final settings = context.watch<SettingsNotifier>().userSettings;
    final now = DateTime.now();
    final current =
        _month.year == now.year && (_year || _month.month == now.month);
    final data = MonthlyStats.calculate(history, _month,
        catalog: catalog, now: now, year: _year);
    final previousMonth = _year
        ? DateTime(_month.year - 1, now.month)
        : DateTime(_month.year, _month.month - 1);
    final previousCutoff = current
        ? DateTime(
            previousMonth.year,
            previousMonth.month,
            math.min(now.day,
                DateTime(previousMonth.year, previousMonth.month + 1, 0).day),
            now.hour,
            now.minute,
            now.second)
        : now;
    final previous = MonthlyStats.calculate(history, previousMonth,
        catalog: catalog, now: previousCutoff, year: _year);
    final delta = data.workouts - previous.workouts;
    final days = current
        ? (_year
            ? DateTime.utc(now.year, now.month, now.day)
                    .difference(DateTime.utc(now.year))
                    .inDays +
                1
            : now.day)
        : data.dailyWorkouts.length;
    final cardioEntries = data.loggedWorkouts
        .expand((w) => w.exercises)
        .where((e) =>
            MonthlyStats.isCardio(e, catalog[e.exerciseId]) &&
            e.sets.any((s) => s.isCompleted && !s.isSuperSetRest))
        .toList();
    final rates = cardioEntries
        .where((e) => e.averageHeartRate != null)
        .map((e) => e.averageHeartRate!)
        .toList();
    final unit = settings.weightUnit == WeightUnit.lb ? 'lb' : 'kg';
    final distanceUnit =
        settings.distanceUnit == DistanceUnit.miles ? 'mi' : 'km';
    final volume = data.volumeKg * (unit == 'lb' ? 2.2046226218 : 1);
    final distance = data.distanceKm / (distanceUnit == 'mi' ? 1.609344 : 1);
    final muscles = data.muscleSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final strength = <String, ({String name, int sets})>{};
    for (final workout in data.loggedWorkouts) {
      for (final exercise in workout.exercises) {
        if (MonthlyStats.isCardio(exercise, catalog[exercise.exerciseId])) {
          continue;
        }
        final count = exercise.sets
            .where((s) => s.isCompleted && !s.isSuperSetRest)
            .length;
        if (count == 0) continue;
        strength[exercise.exerciseId] = (
          name: exercise.exerciseName ??
              catalog[exercise.exerciseId]?.name ??
              'Exercise',
          sets: (strength[exercise.exerciseId]?.sets ?? 0) + count
        );
      }
    }
    final strengthRows = strength.entries.toList()
      ..sort((a, b) => b.value.sets.compareTo(a.value.sets));
    final overview = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading(
              'Your ${_year ? 'year' : 'month'}${current ? ' so far' : ''}',
              Icons.insights_outlined),
          const SizedBox(height: 18),
          _metrics([
            _metric(
                '${data.workouts}', 'workouts', Icons.fitness_center_outlined,
                onPanel: true),
            _metric('${data.activeDays}', 'active days',
                Icons.calendar_today_outlined,
                accent: AppColors.lime, onPanel: true),
            _metric(data.timedWorkouts == 0 ? '—' : _time(data.totalSeconds),
                'total time', Icons.timer_outlined,
                onPanel: true),
            _metric(
                data.averageSeconds == null ? '—' : _time(data.averageSeconds!),
                'average workout',
                Icons.schedule_rounded,
                onPanel: true)
          ]),
          const SizedBox(height: 16),
          _surface(
              Text(
                  '${delta > 0 ? '+' : ''}$delta workouts vs ${current ? 'the same period last ${_year ? 'year' : 'month'}' : 'last ${_year ? 'year' : 'month'}'} · ${(data.workouts * 7 / days).toStringAsFixed(1)} per week',
                  style: const TextStyle(fontSize: 13, height: 1.45)),
              color: softLavender,
              padding: 13,
              radius: 20),
          const SizedBox(height: 10),
          _note(
              'Time includes rest. ${data.timedWorkouts} of ${data.workouts} workouts have a recorded duration.')
        ]),
        color: panel);
    final strengthDetails = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Strength & holds', Icons.fitness_center_outlined),
          const SizedBox(height: 18),
          _metrics([
            _metric('${data.strengthSets}', 'Completed sets',
                Icons.fitness_center_outlined,
                onPanel: true),
            _metric(NumberFormat.decimalPattern().format(data.reps),
                'Recorded reps', Icons.repeat_rounded,
                accent: AppColors.lime, onPanel: true)
          ]),
          const SizedBox(height: 12),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row(
                    'Lifting volume',
                    data.weightedSets == 0
                        ? '—'
                        : '${NumberFormat('#,##0').format(volume)} $unit'),
                _note('Volume = weight × reps across completed weighted sets.'),
                if (data.unknownWeightSets > 0)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _note(
                          '${data.unknownWeightSets} sets have no saved weight unit and are excluded from volume.'))
              ]),
              padding: 14,
              radius: 24),
          const SizedBox(height: 20),
          const Text('Exercise progress',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          _note('Completed sets by exercise. Tap to see your progress.'),
          const SizedBox(height: 12),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (strengthRows.isEmpty)
                  _note(
                      'Log your first completed sets to see your exercise progress.'),
                for (final row in strengthRows)
                  _bar(row.value.name, row.value.sets,
                      strengthRows.first.value.sets,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ExerciseProgressScreen(
                                  exerciseId: row.key, name: row.value.name))))
              ]),
              padding: 14,
              radius: 24)
        ]),
        color: panel);
    final cardioDetails = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Cardio', Icons.directions_run_rounded,
              accent: AppColors.coral),
          const SizedBox(height: 18),
          _metrics([
            _metric(data.timedCardioSets == 0 ? '—' : _time(data.cardioSeconds),
                'Recorded cardio time', Icons.timer_outlined,
                onPanel: true),
            _metric(
                data.distanceSets == 0
                    ? '—'
                    : '${distance.toStringAsFixed(1)} $distanceUnit',
                'Recorded distance',
                Icons.route_outlined,
                accent: AppColors.lime,
                onPanel: true)
          ]),
          const SizedBox(height: 12),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _row('Workouts with cardio', '${data.cardioSessions}'),
                _row(
                    'Average recorded HR',
                    rates.isEmpty
                        ? 'Not recorded'
                        : '${(rates.reduce((a, b) => a + b) / rates.length).round()} bpm'),
                _note(
                    'Mean of recorded exercise averages; not a heart-rate zone.')
              ]),
              padding: 14,
              radius: 24),
          const SizedBox(height: 20),
          const Text('Recorded effort',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final effort in ['Low', 'Moderate', 'High'])
                  _bar(
                      '$effort effort entries',
                      cardioEntries.where((e) => e.intensity == effort).length,
                      cardioEntries.length,
                      accent: effort == 'High'
                          ? AppColors.coral
                          : effort == 'Low'
                              ? AppColors.lime
                              : AppColors.lavender),
                _row('Effort not recorded',
                    '${cardioEntries.where((e) => e.intensity == null).length}')
              ]),
              padding: 14,
              radius: 24),
          const SizedBox(height: 14),
          _note(
              'Time and distance come from completed cardio sets, not the whole workout.'),
          if (data.unknownDistanceSets > 0)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _note(
                    '${data.unknownDistanceSets} distances have no saved unit and are excluded.'))
        ]),
        color: panel);
    final muscleDetails = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('Muscle groups', Icons.accessibility_new_rounded,
              accent: AppColors.lime),
          const SizedBox(height: 12),
          _note('Completed non-cardio sets by primary muscle group.'),
          const SizedBox(height: 16),
          _surface(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (muscles.isEmpty)
                  _note(
                      'Your muscle breakdown starts with your first completed sets.'),
                for (final group in muscles)
                  _bar('${group.key} · sets', group.value, muscles.first.value)
              ]),
              padding: 14,
              radius: 24),
          const SizedBox(height: 18),
          _note(
              'Unspecified means the exercise has no saved muscle group. These are training totals, not recovery estimates.')
        ]),
        color: panel);
    final tiles = [
      _tile(
          'Workouts',
          '${data.workouts}',
          'completed this ${_year ? 'year' : 'month'}',
          Icons.fitness_center_outlined,
          AppColors.lavender,
          () => _details('Workouts',
              [overview, _activityChart(data, now), _entries(data, catalog)])),
      _tile(
          'Time',
          data.timedWorkouts == 0 ? '—' : _time(data.totalSeconds),
          'total workout time',
          Icons.timer_outlined,
          AppColors.paleLavender,
          () => _details(
              'Workout time', [_timeOverview(data), _entries(data, catalog)])),
      _tile(
          'Personal Records',
          '${recentRecords.length}',
          'new bests this ${_year ? 'year' : 'month'}',
          Icons.emoji_events_outlined,
          AppColors.lime,
          () => _details('Personal Records', [
                _surface(
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading('Recent PRs', Icons.emoji_events_outlined,
                              accent: AppColors.lime),
                          const SizedBox(height: 12),
                          RecordList(recentRecords)
                        ]),
                    color: panel),
                _surface(
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading('All-time bests',
                              Icons.workspace_premium_outlined),
                          const SizedBox(height: 12),
                          RecordList(bestRecords)
                        ]),
                    color: panel)
              ])),
      _tile(
          'Strength',
          '${data.strengthSets}',
          'completed sets',
          Icons.fitness_center_rounded,
          AppColors.lavender,
          () => _details('Strength & holds', [strengthDetails])),
      _tile(
          'Cardio',
          '${data.cardioSessions}',
          'workouts with cardio',
          Icons.directions_run_rounded,
          AppColors.coral,
          () => _details('Cardio',
              [cardioDetails, _entries(data, catalog, cardio: true)])),
      _tile(
          'Muscles',
          '${muscles.where((e) => e.key != 'Unspecified').length}',
          'recorded muscle groups',
          Icons.accessibility_new_rounded,
          AppColors.lime,
          () => _details('Muscle groups', [muscleDetails])),
      _tile(
          'Active days',
          '${data.activeDays}',
          'days you trained',
          Icons.calendar_month_outlined,
          AppColors.paleLavender,
          () => _details('Active days', [
                _activityChart(data, now),
                _surface(
                    _note(
                        '${data.activeDays} days with completed workouts. Multiple workouts on the same day count as one active day.'),
                    color: panel)
              ]))
    ];
    return Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
            bottom: false,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Row(children: [
                    const SizedBox(width: 48),
                    const Expanded(
                        child: Text('Stats',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500))),
                    IconButton(
                        tooltip: 'Choose period',
                        onPressed: _pickPeriod,
                        style: IconButton.styleFrom(
                            backgroundColor: panel,
                            minimumSize: const Size(48, 48),
                            foregroundColor: colors.onSurface),
                        icon:
                            const Icon(Icons.calendar_month_outlined, size: 20))
                  ]),
                  const SizedBox(height: 20),
                  _periodControl(current, now),
                  const SizedBox(height: 18),
                  _surface(
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Insight',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 16),
                            LayoutBuilder(builder: (context, constraints) {
                              final single = constraints.maxWidth < 270 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3;
                              final width = single
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 10) / 2;
                              return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (var i = 0; i < tiles.length; i++)
                                      SizedBox(
                                          width:
                                              i == tiles.length - 1 && !single
                                                  ? constraints.maxWidth
                                                  : width,
                                          child: tiles[i])
                                  ]);
                            })
                          ]),
                      color: panel,
                      padding: 13,
                      radius: 30),
                  if (AppleHealthService.instance.isAvailable) ...[
                    const SizedBox(height: 18),
                    _healthSection(now, settings),
                  ],
                  const SizedBox(height: 18),
                  _entries(data, catalog, limit: 3),
                  const SizedBox(height: 16),
                  Center(
                      child: _note(
                          'Tap a card to explore your ${_year ? 'year' : 'month'}.'))
                ])));
  }
}

/// The ring represents recorded-duration coverage, never an invented time goal.
class _DurationRing extends CustomPainter {
  final double fraction;
  final Color track, accent;
  const _DurationRing(
      {required this.fraction, required this.track, required this.accent});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bounds = rect.deflate(18);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 29
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        bounds, -math.pi / 2, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      paint.shader = SweepGradient(colors: [
        accent.withValues(alpha: .3),
        accent,
        accent.withValues(alpha: .3)
      ], stops: const [
        0,
        .6,
        1
      ], transform: const GradientRotation(-math.pi / 2))
          .createShader(rect);
      canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * fraction.clamp(0, 1),
          false, paint);
    }
  }

  @override
  bool shouldRepaint(_DurationRing old) =>
      old.fraction != fraction || old.track != track || old.accent != accent;
}
