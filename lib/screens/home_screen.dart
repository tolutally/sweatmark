import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../models/monthly_stats.dart';
import '../models/weekly_progress.dart';
import '../models/workout_model.dart';
import '../models/template_model.dart';
import '../state/auth_notifier.dart';
import '../state/navigation/tab_navigation_notifier.dart';
import '../state/workout_notifier.dart';
import '../state/exercise_db_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/template_notifier.dart';
import '../widgets/personal_records.dart';
import 'active_workout_screen.dart';
import 'library_screen.dart';
import 'routine_editor_screen.dart';
import 'routine_detail_screen.dart';
import 'settings_screen.dart';
import 'account_profile_screen.dart';
import 'workout_detail_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _panel =>
      _dark ? _colors.surfaceContainerLow : AppColors.referencePanel;
  Color get _lavenderPanel => _dark
      ? _colors.primaryContainer.withValues(alpha: .45)
      : AppColors.referenceLavenderPanel;
  Color get _muted =>
      _dark ? _colors.onSurfaceVariant : AppColors.referenceMuted;
  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  void _showStats() {
    final navigation = context.read<TabNavigationNotifier?>();
    if (navigation != null) {
      navigation.goTo(3);
    } else {
      _push(Scaffold(appBar: AppBar(), body: const StatsScreen()));
    }
  }

  void _start() {
    final workouts = context.read<WorkoutNotifier>();
    if (!workouts.isWorkoutActive) workouts.startWorkout();
    _push(const ActiveWorkoutScreen());
  }

  String _duration(int seconds) {
    if (seconds <= 0) return 'No time recorded';
    final minutes = (seconds / 60).round();
    if (minutes < 1) return '<1 min';
    return minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
  }

  void _day(DateTime day, List<WorkoutLog> history) {
    final matches =
        history.where((w) => isSameDay(w.timestamp.toLocal(), day)).toList();
    _sheet(
        DateFormat('EEEE, MMM d').format(day),
        Column(children: [
          if (matches.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No workouts on this day')),
          for (final workout in matches) _workoutRow(workout),
        ]));
  }

  void _sheet(String title, Widget content, {String? subtitle}) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
                child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * .8),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(title,
                                style:
                                    Theme.of(sheet).textTheme.headlineMedium)),
                        IconButton(
                            tooltip: 'Close details',
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close_rounded))
                      ]),
                      if (subtitle != null)
                        Text(subtitle,
                            style: TextStyle(
                                color: _colors.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 20),
                      content,
                    ]),
              ),
            )));
  }

  Widget _workoutRow(WorkoutLog workout) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        title: Text(workout.workoutName),
        subtitle: Text(
            '${DateFormat('MMM d · h:mm a').format(workout.timestamp.toLocal())}\n${_duration(workout.durationSeconds)}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _push(WorkoutDetailScreen(workout: workout)),
      );

  // Decorative gradients; each ends dark so white text stays readable.
  static const _routineGradients = [
    [AppColors.lavender, Color(0xFF6741B2), Color(0xFF3D2468)],
    [AppColors.coral, Color(0xFF9A3B8F), Color(0xFF3D2468)],
    [Color(0xFF6741B2), Color(0xFF3D2468), AppColors.ink],
  ];

  /// A tap opens the routine preview; starting stays an explicit action there.
  Widget _routineCard(
      WorkoutTemplate routine, int index, List<WorkoutLog> history,
      {required VoidCallback onTap}) {
    final count = routine.exercises.length;
    // Workouts started from a routine carry its name; reuse the latest
    // recorded duration rather than estimating one.
    final lastSeconds = history
        .where((w) => w.workoutName == routine.name && w.durationSeconds > 0)
        .map((w) => w.durationSeconds)
        .firstOrNull;
    final details = [
      '$count ${count == 1 ? 'exercise' : 'exercises'}',
      if (lastSeconds != null) _duration(lastSeconds),
    ].join(' · ');
    return SizedBox(
      width: 180,
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _routineGradients[index % _routineGradients.length],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(children: [
              Positioned(
                right: -22,
                top: -10,
                child: Transform.rotate(
                  angle: -math.pi / 5,
                  child: Icon(Icons.fitness_center_rounded,
                      size: 130, color: Colors.white.withValues(alpha: .14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(routine.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text(details,
                              maxLines: 2,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: .78))),
                        ),
                        const Icon(Icons.play_arrow_rounded,
                            size: 30, color: Colors.white),
                      ]),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child,
          {Color? color,
          Color? border,
          double radius = 24,
          VoidCallback? onTap,
          Key? key}) =>
      Material(
        key: key,
        color: color ?? _colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: border ?? Colors.transparent)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      );

  Widget _badge(IconData icon, Color foreground, Color background,
          {double size = 34}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: foreground, size: 19),
      );

  Widget _weeklyNumber(String value, String label, IconData icon,
          {bool lime = false}) =>
      _card(
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(children: [
              _badge(icon, lime ? AppColors.ink : Colors.white,
                  lime ? AppColors.lime : AppColors.lavender,
                  size: 32),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label, style: TextStyle(fontSize: 12, color: _muted)),
                    const SizedBox(height: 3),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w500)),
                  ])),
            ])),
      );

  Widget _weeklyProgress(WeeklyProgress progress) {
    final numbers = Column(children: [
      _weeklyNumber(
          '${progress.streak}', 'streak', Icons.local_fire_department_outlined),
      const SizedBox(height: 8),
      _weeklyNumber('${progress.count}/${progress.goal}', 'this week',
          Icons.flag_outlined,
          lime: true),
    ]);
    final gauge = _card(Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: _WeeklyGauge(completed: progress.count, goal: progress.goal)));
    return _card(
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              Row(children: [
                const Expanded(
                    child: Text('Your weekly progress',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500))),
                IconButton(
                    tooltip: 'Edit weekly goal',
                    onPressed: () => _push(const SettingsScreen()),
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    style: IconButton.styleFrom(
                        backgroundColor: _colors.surface,
                        minimumSize: const Size(44, 44))),
              ]),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, box) {
                if (box.maxWidth < 285 ||
                    MediaQuery.textScalerOf(context).scale(15) > 19) {
                  return Column(
                      children: [numbers, const SizedBox(height: 12), gauge]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: numbers),
                      const SizedBox(width: 8),
                      Expanded(flex: 7, child: gauge),
                    ]);
              }),
            ])),
        radius: 32,
        color: _lavenderPanel);
  }

  Widget _metric(
          {required String id,
          required IconData icon,
          required String value,
          required String label,
          required Color accent,
          required Color tint,
          required VoidCallback onTap}) =>
      _card(
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: .22)),
                  child: _badge(icon, accent, tint, size: 29),
                ),
                const Spacer(),
                Icon(Icons.more_vert_rounded,
                    size: 18, color: _colors.onSurface)
              ]),
              const SizedBox(height: 22),
              Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            height: 1.15)),
                    Text(label, style: TextStyle(fontSize: 12, color: _muted)),
                  ]),
            ])),
        key: ValueKey(id),
        onTap: onTap,
        border:
            _dark ? _colors.outlineVariant : AppColors.referenceLavenderPanel,
      );

  Widget _latest(WorkoutLog? workout) {
    const foreground = Colors.white;
    const secondary = Color(0xFFB3AFBB);
    return _card(
      Padding(
          padding: const EdgeInsets.all(8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: AppColors.lime.withValues(alpha: .3),
                          shape: BoxShape.circle),
                      child: _badge(
                          Icons.history_rounded, AppColors.ink, AppColors.lime,
                          size: 30)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Last workout',
                            style: TextStyle(fontSize: 12, color: secondary)),
                        const SizedBox(height: 2),
                        Text(
                            workout == null
                                ? 'Ready?'
                                : isSameDay(workout.timestamp.toLocal(),
                                        DateTime.now())
                                    ? 'Today'
                                    : DateFormat('MMM d')
                                        .format(workout.timestamp.toLocal()),
                            style: const TextStyle(
                                fontSize: 15, color: foreground)),
                      ])),
                ])),
            const SizedBox(height: 18),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(workout?.workoutName ?? 'A fresh start',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: foreground))),
            const SizedBox(height: 3),
            Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          workout == null
                              ? 'Start your first workout'
                              : _duration(workout.durationSeconds),
                          style:
                              const TextStyle(fontSize: 12, color: secondary))),
                  Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .06)),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.lime, size: 22)),
                ])),
            const SizedBox(height: 5),
          ])),
      color: AppColors.ink,
      onTap: workout == null
          ? _start
          : () => _push(WorkoutDetailScreen(workout: workout)),
    );
  }

  Widget _week(
      WeeklyProgress progress, List<WorkoutLog> history, DateTime now) {
    final monday = weekStart(now);
    return _card(Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _panel, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: AppColors.lavender.withValues(alpha: .22),
                        shape: BoxShape.circle),
                    child: _badge(Icons.track_changes_rounded, AppColors.ink,
                        AppColors.lavender,
                        size: 30)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Your goal',
                          style: TextStyle(fontSize: 12, color: _muted)),
                      const SizedBox(height: 2),
                      const Text('This week', style: TextStyle(fontSize: 15)),
                    ])),
              ])),
          const SizedBox(height: 14),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(spacing: 4, children: [
                Text('${progress.count} of ${progress.goal}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text('achieved', style: TextStyle(fontSize: 12, color: _muted)),
              ])),
          const SizedBox(height: 2),
          Semantics(
              button: true,
              label: 'View your week',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _sheet(
                    'Your week',
                    Column(
                        children: List.generate(7, (index) {
                      final day = DateTime(
                          monday.year, monday.month, monday.day + index);
                      final count = history
                          .where((w) => isSameDay(w.timestamp.toLocal(), day))
                          .length;
                      return ListTile(
                          title: Text(DateFormat('EEEE, MMM d').format(day)),
                          subtitle: Text(count == 0
                              ? 'No workouts'
                              : '$count ${count == 1 ? 'workout' : 'workouts'}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _day(day, history));
                    }))),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                          children: List.generate(7, (index) {
                        final day = DateTime(
                            monday.year, monday.month, monday.day + index);
                        final trained = history
                            .any((w) => isSameDay(w.timestamp.toLocal(), day));
                        final today = isSameDay(day, now);
                        return Expanded(
                            child: Column(children: [
                          Container(
                              width: 15,
                              height: 15,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: today
                                          ? AppColors.lavender
                                          : _colors.outlineVariant,
                                      width: today ? 1.5 : 1)),
                              child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: trained
                                          ? AppColors.lavender
                                          : _panel))),
                          const SizedBox(height: 6),
                          Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                              style: TextStyle(fontSize: 10, color: _muted)),
                        ]));
                      }))),
                ),
              )),
        ])));
  }

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutNotifier>();
    final settings = context.watch<SettingsNotifier>();
    final templates = context.watch<TemplateNotifier>().templates;
    final user = context.watch<AuthNotifier?>()?.user;
    final displayName = user?.displayName?.trim();
    final now = DateTime.now();
    final history = workouts.workoutHistory
        .where((w) =>
            !w.isTestData &&
            !w.timestamp.isAfter(now) &&
            w.exercises.any(
                (e) => e.sets.any((s) => s.isCompleted && !s.isSuperSetRest)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final catalog = context.watch<ExerciseDbNotifier?>()?.exercises ?? [];
    final names = <String, String>{
      for (final workout in history.reversed)
        for (final exercise in workout.exercises)
          if (exercise.exerciseName != null)
            exercise.exerciseId: exercise.exerciseName!,
      for (final exercise in catalog) exercise.id: exercise.name,
    };
    final progress = WeeklyProgress.calculate(
        history, settings.userSettings.weeklyGoals, now);
    final month = MonthlyStats.calculate(history, now,
        now: now, catalog: {for (final e in catalog) e.id: e});
    final records = workouts.personalRecords
        .where((r) {
          final date = r.timestamp.toLocal();
          return !r.isBaseline &&
              date.year == now.year &&
              date.month == now.month &&
              !r.timestamp.isAfter(now);
        })
        .toList()
        .reversed
        .toList();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final minutes = (month.totalSeconds / 60).round();
    void showWorkouts({bool time = false}) => _sheet(
        time ? 'Workout time' : 'Workouts',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (time) ...[
            Text('Total time · ${_duration(month.totalSeconds)}'),
            const SizedBox(height: 8),
            Text(
                'Average workout · ${month.averageSeconds == null ? '—' : _duration(month.averageSeconds!)}'),
            const SizedBox(height: 8),
            Text(
                'Includes rest. Workouts without a recorded duration are excluded from the average.',
                style:
                    TextStyle(fontSize: 13, color: _colors.onSurfaceVariant)),
            const SizedBox(height: 20),
          ],
          if (month.loggedWorkouts.isEmpty)
            const Text('Your completed workouts will appear here.'),
          for (final workout in month.loggedWorkouts) _workoutRow(workout),
        ]),
        subtitle: monthLabel);
    final metrics = [
      _metric(
          id: 'home-monthly-workouts',
          icon: Icons.fitness_center_rounded,
          value: '${month.workouts}',
          label: 'workouts',
          accent: Colors.white,
          tint: AppColors.lavender,
          onTap: () => showWorkouts()),
      _metric(
          id: 'home-monthly-time',
          icon: Icons.schedule_rounded,
          value: month.timedWorkouts == 0
              ? '—'
              : minutes < 1
                  ? '<1'
                  : '$minutes',
          label: 'min',
          accent: Colors.white,
          tint: AppColors.ink,
          onTap: () => showWorkouts(time: true)),
      _metric(
          id: 'home-monthly-prs',
          icon: Icons.emoji_events_outlined,
          value: '${records.length}',
          label: 'new PRs',
          accent: Colors.white,
          tint: AppColors.coral,
          onTap: () => _sheet(
              'Personal Records',
              RecordList(records,
                  emptyMessage: 'Your next best starts with a workout.'),
              subtitle: monthLabel)),
    ];
    return Scaffold(
        body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Hello,',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: _colors.onSurface)),
                        Text(
                            displayName?.isNotEmpty == true
                                ? '$displayName!'
                                : 'Ready to train?',
                            style: const TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w500)),
                      ])),
                  const SizedBox(width: 8),
                  IconButton(
                      tooltip: 'Search exercises',
                      onPressed: () => _push(const LibraryScreen()),
                      icon: const Icon(Icons.search_rounded),
                      style: IconButton.styleFrom(
                          backgroundColor: _panel,
                          minimumSize: const Size(48, 48))),
                  const SizedBox(width: 6),
                  IconButton(
                      tooltip: 'Profile',
                      onPressed: () => _push(const AccountProfileScreen()),
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.lavender,
                          minimumSize: const Size(48, 48)),
                      icon: user?.photoURL != null
                          ? CircleAvatar(
                              radius: 17,
                              backgroundImage: NetworkImage(user!.photoURL!))
                          : const Icon(Icons.person_outline_rounded,
                              color: AppColors.ink)),
                ]),
                const SizedBox(height: 22),
                _weeklyProgress(progress),
                const SizedBox(height: 4),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: _showStats,
                          child: Text('This month',
                              style: TextStyle(fontSize: 12, color: _muted))),
                      TextButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: Text(workouts.isWorkoutActive
                              ? 'Resume workout'
                              : 'Start workout'),
                          style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              foregroundColor: _colors.onSurface,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontSize: 12))),
                    ]),
                LayoutBuilder(builder: (context, box) {
                  if (MediaQuery.textScalerOf(context).scale(15) > 19) {
                    return Column(children: [
                      for (var i = 0; i < metrics.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                                width: double.infinity, child: metrics[i]))
                    ]);
                  }
                  return IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: metrics[i])
                        ],
                      ]));
                }),
                const SizedBox(height: 20),
                _card(
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(children: [
                          LayoutBuilder(builder: (context, box) {
                            final latest =
                                _latest(history.isEmpty ? null : history.first);
                            final week = _week(progress, history, now);
                            if (box.maxWidth < 300 ||
                                MediaQuery.textScalerOf(context).scale(15) >
                                    19) {
                              return Column(children: [
                                SizedBox(width: double.infinity, child: latest),
                                const SizedBox(height: 8),
                                week,
                              ]);
                            }
                            return IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Expanded(child: latest),
                                  const SizedBox(width: 8),
                                  Expanded(child: week),
                                ]));
                          }),
                          if (progress.count >= progress.goal) ...[
                            const SizedBox(height: 14),
                            _card(Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(children: [
                                  _badge(Icons.emoji_events_outlined,
                                      Colors.white, AppColors.lavender,
                                      size: 42),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text(
                                            'You hit your weekly target!',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${DateFormat('MMM d').format(weekStart(now))}–${DateFormat('MMM d').format(weekStart(now).add(const Duration(days: 6)))}',
                                            style: TextStyle(
                                                fontSize: 13, color: _muted)),
                                      ])),
                                ]))),
                          ],
                        ])),
                    radius: 32,
                    color: _panel),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.grid_view_rounded,
                      size: 22, color: _colors.onSurface),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('My routines',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w500))),
                  Flexible(
                      child: TextButton(
                          onPressed: () => _push(const RoutineEditorScreen()),
                          child: const Text('New routine',
                              textAlign: TextAlign.end)))
                ]),
                const SizedBox(height: 8),
                if (templates.isEmpty)
                  _card(Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _badge(Icons.playlist_add_rounded, _colors.primary,
                                _colors.primaryContainer),
                            const SizedBox(height: 14),
                            const Text('Make it your routine',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                                'Save your go-to exercises with New routine, or save a finished workout as a routine.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _colors.onSurfaceVariant)),
                          ])))
                else
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(15) > 19
                        ? 260
                        : 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _routineCard(
                          templates[index], index, history,
                          onTap: () => _push(RoutineDetailScreen(
                              routine: templates[index], names: names))),
                    ),
                  ),
              ],
            )));
  }
}

class _WeeklyGauge extends StatelessWidget {
  final int completed, goal;
  const _WeeklyGauge({required this.completed, required this.goal});
  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : (completed / goal).clamp(0.0, 1.0);
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final circleSize =
        68.0 * math.max(1.0, MediaQuery.textScalerOf(context).scale(21) / 21);
    return Semantics(
        label: 'Weekly workout goal',
        value: '$completed of $goal workouts',
        child: SizedBox(
            height: 120 + circleSize - 68,
            width: double.infinity,
            child: CustomPaint(
                painter: _GoalArc(ratio,
                    dark ? colors.surfaceContainerHighest : AppColors.ink),
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dark
                                ? colors.primaryContainer
                                : AppColors.referenceLavenderPanel),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${(ratio * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 21,
                                      height: 1.1,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('weekly goal',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: dark
                                          ? colors.onSurfaceVariant
                                          : AppColors.referenceMuted)),
                            ]))))));
  }
}

class _GoalArc extends CustomPainter {
  final double progress;
  final Color track;
  const _GoalArc(this.progress, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.width * .15).clamp(16.0, 24.0);
    final radius = math.min((size.width - stroke - 12) / 2, size.height - 40);
    final center = Offset(size.width / 2, size.height - 30);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false,
          paint..color = AppColors.lavender);
    }
    // The thin outer accent repeats the same goal progress, so both arcs use
    // the actual weekly count rather than implying a second health metric.
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius + stroke / 2 + 3),
          math.pi,
          math.pi * progress,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = AppColors.lime);
    }
    final tick = Paint()
      ..color = AppColors.lavender.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var i = 0; i <= 35; i++) {
      final angle = math.pi + math.pi * i / 35;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + direction * (radius + stroke / 2 + 9),
          center + direction * (radius + stroke / 2 + 11), tick);
    }
  }

  @override
  bool shouldRepaint(covariant _GoalArc old) =>
      old.progress != progress || old.track != track;
}
