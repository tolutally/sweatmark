import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/weekly_progress.dart';
import '../state/auth_notifier.dart';
import '../state/settings_notifier.dart';
import '../state/template_notifier.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/round_back_button.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'workout_history_screen.dart';

/// The account page: who you are, your goals and your data. Preferences,
/// sign out and account deletion live in Settings (the gear), so nothing
/// is repeated here. Soft lavender panels of white rows, each with a
/// colored icon circle and a chevron.
class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({super.key});

  static const _page = Color(0xFFF6F4FC);
  static const _panel = Color(0xFFF0EEF5);
  static const _muted = AppColors.referenceMuted;

  static String initials(String? name, String? email) {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isNotEmpty) {
      return (words.first[0] + (words.length > 1 ? words.last[0] : ''))
          .toUpperCase();
    }
    final mail = email?.trim() ?? '';
    return mail.isEmpty ? '?' : mail[0].toUpperCase();
  }

  static String _signInMethod(Iterable<String> providers) {
    if (providers.contains('apple.com')) return 'Apple';
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('password')) return 'Email and password';
    return 'Signed in';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    final name = user?.displayName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.userSettings;
    final history = context
        .watch<WorkoutNotifier>()
        .workoutHistory
        .where((w) =>
            !w.isTestData &&
            w.exercises.any((e) => e.sets.any((s) => s.isCompleted)))
        .toList();
    final progress =
        WeeklyProgress.calculate(history, settings.weeklyGoals, DateTime.now());
    final routines = context.watch<TemplateNotifier>().templates.length;
    final created = user?.metadata.creationTime;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    void openSettings() => open(const SettingsScreen());

    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: RoundBackButton(close: true)),
            const SizedBox(height: 14),
            // Hello header: avatar in a lavender ring, name, settings.
            _Panel(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Avatar(initials(name, user?.email)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: 'Hello, ',
                                style: TextStyle(fontWeight: FontWeight.w400)),
                            TextSpan(
                                text: hasName ? name : 'there',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.15,
                              letterSpacing: -.5,
                              color: AppColors.ink),
                        ),
                      ),
                      _RoundButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Settings',
                          onTap: openSettings),
                    ]),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (user?.email != null) _Chip(user!.email!),
                      if (created != null)
                        _Chip(
                            'Member since ${DateFormat('MMMM yyyy').format(created.toLocal())}'),
                    ]),
                  ]),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Account',
              child: Column(children: [
                _Row(
                    icon: Icons.person_outline_rounded,
                    circle: AppColors.lavender,
                    title: 'Name',
                    subtitle: hasName ? name : 'Add your name',
                    onTap: () => _editName(context, name ?? '')),
                _Row(
                    icon: Icons.mail_outline_rounded,
                    circle: AppColors.lime,
                    title: 'Email',
                    subtitle: user?.email ?? 'No email on this account'),
                _Row(
                    icon: Icons.verified_user_outlined,
                    circle: AppColors.coral,
                    iconColor: Colors.white,
                    title: 'Sign-in',
                    subtitle: _signInMethod(
                        user?.providerData.map((p) => p.providerId) ??
                            const [])),
              ]),
            ),
            const SizedBox(height: 14),
            // Goals, two up.
            _Panel(
              title: 'Your goals',
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: _GoalTile(
                        icon: Icons.flag_rounded,
                        circle: AppColors.paleLavender,
                        label: 'This week',
                        value: '${progress.count}',
                        of: '/${progress.goal}',
                        onTap: openSettings),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GoalTile(
                        icon: Icons.local_fire_department_rounded,
                        circle: const Color(0xFFFFD9DB),
                        label: 'Week streak',
                        value: '${progress.streak}',
                        of: progress.streak == 1 ? ' week' : ' weeks'),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _GoalTile(
                        icon: Icons.fitness_center_rounded,
                        circle: const Color(0xFFEFF8C2),
                        label: 'Workouts logged',
                        value: NumberFormat.decimalPattern()
                            .format(history.length),
                        of: '',
                        onTap: () => open(const WorkoutHistoryScreen())),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GoalTile(
                        icon: Icons.playlist_play_rounded,
                        circle: AppColors.paleLavender,
                        label: 'Routines',
                        value: '$routines',
                        of: ''),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Your data',
              child: Column(children: [
                _Row(
                    icon: Icons.history_rounded,
                    circle: AppColors.lavender,
                    title: 'Workout history',
                    subtitle: 'Every workout you’ve logged',
                    onTap: () => open(const WorkoutHistoryScreen())),
                _Row(
                    icon: Icons.menu_book_rounded,
                    circle: AppColors.lime,
                    title: 'Exercise library',
                    subtitle: 'Browse and search exercises',
                    onTap: () => open(const LibraryScreen())),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _page,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _NameSheet(current),
    );
    final name = saved?.trim();
    if (name == null || name.isEmpty || name == current || !context.mounted) {
      return;
    }
    try {
      await context.read<AuthNotifier>().updateName(name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your name. Please try again.')));
      }
    }
  }
}

/// Bottom sheet for editing the display name; owns its text controller so
/// it is released only after the sheet has closed.
class _NameSheet extends StatefulWidget {
  final String current;
  const _NameSheet(this.current);

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Your name',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Shown on your profile and on cards you share.',
                  style: TextStyle(
                      fontSize: 13, color: AccountProfileScreen._muted)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Name'),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _controller.text),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lavender,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Save'),
              ),
            ]),
      );
}

/// A soft grey panel holding white rows, with an optional title.
class _Panel extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets padding;
  const _Panel(
      {this.title,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(10, 14, 10, 10)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: AccountProfileScreen._panel,
            borderRadius: BorderRadius.circular(28)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(title!,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.2,
                      color: AppColors.ink)),
            ),
          ],
          child,
        ]),
      );
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar(this.initials);

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lavender, width: 3)),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.paleLavender, shape: BoxShape.circle),
          child: Text(initials,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            minimumSize: const Size(46, 46)),
        icon: Icon(icon, size: 21),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AccountProfileScreen._muted)),
      );
}

/// A small white square with a chevron, as in the reference rows.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDEBF2))),
        child: const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.ink),
      );
}

class _GoalTile extends StatelessWidget {
  final IconData icon;
  final Color circle;
  final String label;
  final String value;
  final String of;
  final VoidCallback? onTap;
  const _GoalTile(
      {required this.icon,
      required this.circle,
      required this.label,
      required this.value,
      required this.of,
      this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(color: circle, shape: BoxShape.circle),
                  child: Icon(icon, size: 21, color: AppColors.ink),
                ),
                const Spacer(),
                if (onTap != null) const _Chevron(),
              ]),
              const SizedBox(height: 16),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.5,
                          color: AppColors.ink)),
                  if (of.isNotEmpty)
                    TextSpan(
                        text: of,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AccountProfileScreen._muted)),
                ])),
              ),
            ]),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color circle;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _Row(
      {required this.icon,
      required this.circle,
      this.iconColor = AppColors.ink,
      required this.title,
      required this.subtitle,
      this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: circle, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AccountProfileScreen._muted)),
                      ]),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 10),
                  const _Chevron(),
                ],
              ]),
            ),
          ),
        ),
      );
}
