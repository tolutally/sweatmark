import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/template_notifier.dart';
import '../models/weekly_progress.dart';
import '../widgets/round_back_button.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'workout_history_screen.dart';
import 'workout_detail_screen.dart';

class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final name = user?.displayName?.trim();
    final history = context
        .watch<WorkoutNotifier>()
        .workoutHistory
        .where((w) =>
            !w.isTestData &&
            w.exercises.any((e) => e.sets.any((s) => s.isCompleted)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final progress = WeeklyProgress.calculate(
        history,
        context.watch<SettingsNotifier>().userSettings.weeklyGoals,
        DateTime.now());
    final routines = context.watch<TemplateNotifier>().templates.length;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return Scaffold(
      body: SafeArea(
          child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              gradient: AppDesign.of(context).heroGradient),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const RoundBackButton(close: true),
            const SizedBox(height: 28),
            Row(children: [
              Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer),
                  child: Icon(Icons.person_rounded,
                      size: 44,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        name != null && name.isNotEmpty ? name : 'Your account',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600)),
                    if (user?.email != null) ...[
                      const SizedBox(height: 5),
                      Text(user!.email!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary))
                    ],
                    const SizedBox(height: 10),
                    Text('${history.length} workouts logged',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ])),
            ]),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: _shortcut(context, 'History', Icons.history_rounded,
                        () => open(const WorkoutHistoryScreen()))),
                const SizedBox(width: 12),
                Expanded(
                    child: _shortcut(
                        context,
                        'Exercises',
                        Icons.fitness_center_rounded,
                        () => open(const LibraryScreen())))
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _shortcut(
                        context,
                        'Settings',
                        Icons.settings_outlined,
                        () => open(const SettingsScreen()))),
                const SizedBox(width: 12),
                Expanded(
                    child: _shortcut(context, 'Sign out', Icons.logout_rounded,
                        () async {
                  try {
                    await context.read<AuthNotifier>().signOut();
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Could not sign out. Please try again.')));
                  }
                }))
              ]),
              const SizedBox(height: 24),
              _card(
                  context,
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your numbers',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 20),
                        Row(children: [
                          _number(context, '${progress.streak}', 'week streak',
                              Icons.local_fire_department_rounded),
                          _number(context, '${progress.count}/${progress.goal}',
                              'this week', Icons.flag_rounded),
                          _number(context, '$routines', 'routines',
                              Icons.playlist_play_rounded)
                        ]),
                      ])),
              const SizedBox(height: 28),
              const Text('Recent activity',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (history.isEmpty)
                _card(context,
                    const Text('Your completed workouts will appear here.')),
              for (final workout in history.take(3))
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            title: Text(workout.workoutName,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${workout.timestamp.toLocal().toString().split(' ').first} · ${workout.exercises.length} exercises',
                                style: const TextStyle(fontSize: 13)),
                            trailing: Icon(Icons.chevron_right,
                                color: Theme.of(context).colorScheme.primary),
                            onTap: () =>
                                open(WorkoutDetailScreen(workout: workout))))),
            ])),
      ])),
    );
  }

  Widget _shortcut(BuildContext context, String label, IconData icon,
          VoidCallback action) =>
      Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: action,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(children: [
                  Icon(icon,
                      size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Flexible(
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)))
                ]))),
      );
  Widget _card(BuildContext context, Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24)),
      child: child);
  Widget _number(
          BuildContext context, String value, String label, IconData icon) =>
      Expanded(
          child: Column(children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.primary, size: 22)),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
}
