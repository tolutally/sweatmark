import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../models/user_settings.dart';
import '../models/weekly_progress.dart';
import '../services/apple_health_service.dart';
import '../state/auth_notifier.dart';
import '../state/settings_notifier.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _goalKey = GlobalKey();
  final _health = AppleHealthService.instance;
  bool _healthOn = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthNotifier?>()?.user?.uid;
    _health.isEnabled(uid).then((on) {
      if (mounted) setState(() => _healthOn = on);
    });
  }

  Future<void> _setHealth(bool on) async {
    final uid = context.read<AuthNotifier?>()?.user?.uid;
    if (uid == null) return;
    if (!on) {
      await _health.disable(uid);
      if (mounted) setState(() => _healthOn = false);
      return;
    }
    final granted = await _health.enable(uid);
    if (!mounted) return;
    setState(() => _healthOn = granted);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Allow SweatMark to save workouts in Settings › Health › Data Access & Devices.')));
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _panelColor => _isDark
      ? Theme.of(context).colorScheme.surfaceContainer
      : AppColors.referencePanel;
  Color get _captionColor => _isDark
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.referenceMuted;

  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save setting. Please try again.')));
      }
    }
  }

  void _showGoal() {
    final target = _goalKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target,
        alignment: .15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  Widget _panel(Widget child,
          {Color? color, double padding = 16, double radius = 24}) =>
      Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
              color: color ?? _panelColor,
              borderRadius: BorderRadius.circular(radius)),
          child: child);

  Widget _iconBadge(IconData icon, Color color, Color background) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: color));

  Widget _segments<T extends Object>(
      String label, T value, Map<T, String> options, ValueChanged<T> changed) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(28)),
      child: Row(
          children: options.entries.map((entry) {
        final selected = value == entry.key;
        return Expanded(
            child: Semantics(
          label: '$label unit: ${entry.value}',
          selected: selected,
          button: true,
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => changed(entry.key),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: selected
                            ? (_isDark
                                ? colors.primaryContainer
                                : AppColors.referenceLavenderPanel)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24)),
                    child: Text(entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            color: selected
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                  ))),
        ));
      }).toList()),
    );
  }

  Widget _unitCard(String title, IconData icon, Color color, Color background,
          Widget control) =>
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconBadge(icon, color, background),
        const SizedBox(height: 18),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        control,
      ]));

  Widget _preference({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
    Widget? details,
  }) {
    final colors = Theme.of(context).colorScheme;
    return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _iconBadge(icon, iconColor, iconBackground),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500))),
                    const SizedBox(width: 4),
                    Semantics(
                      label: title,
                      toggled: value,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(!value),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: ExcludeSemantics(
                              child: Transform.scale(
                                scale: .72,
                                child: CupertinoSwitch(
                                    value: value,
                                    activeTrackColor: activeColor,
                                    inactiveTrackColor: _panelColor,
                                    onChanged: onChanged),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _captionColor, fontSize: 12, height: 1.4)),
                ])),
          ]),
          if (details != null) ...[
            const SizedBox(height: 16),
            details,
          ],
        ]),
        color: colors.surface,
        padding: 12,
        radius: 20);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
    if (!settings.userSettingsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final subtitleStyle =
        type.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final week = weekStart(DateTime.now());
    final next = DateTime(week.year, week.month, week.day + 7);
    final current = goalForWeek(settings.userSettings.weeklyGoals, week);
    final scheduled = goalForWeek(settings.userSettings.weeklyGoals, next);
    final weight = _unitCard(
        'Weight',
        PhosphorIconsRegular.barbell,
        _isDark ? colors.onPrimaryContainer : AppColors.ink,
        _isDark ? colors.primaryContainer : AppColors.paleLavender,
        _segments(
            'Weight',
            settings.userSettings.weightUnit,
            {WeightUnit.lb: 'lb', WeightUnit.kg: 'kg'},
            (unit) => _save(() => settings.setWeightUnit(unit))));
    final distance = _unitCard(
        'Distance',
        PhosphorIconsRegular.footprints,
        AppColors.ink,
        AppColors.lime,
        _segments(
            'Distance',
            settings.userSettings.distanceUnit,
            {DistanceUnit.miles: 'mi', DistanceUnit.kilometers: 'km'},
            (unit) => _save(() => settings.setDistanceUnit(unit))));
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(
                  tooltip: 'Back',
                  style: IconButton.styleFrom(
                      backgroundColor: _panelColor,
                      foregroundColor: colors.onSurfaceVariant,
                      minimumSize: const Size(48, 48),
                      shape: const CircleBorder()),
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(PhosphorIconsRegular.caretLeft, size: 18)),
              Expanded(
                  child: Text('Settings',
                      textAlign: TextAlign.center,
                      style: type.titleMedium?.copyWith(
                          fontSize: 18, fontWeight: FontWeight.w500))),
              IconButton(
                  tooltip: 'Weekly workout goal',
                  style: IconButton.styleFrom(
                      backgroundColor: _panelColor,
                      foregroundColor: colors.onSurfaceVariant,
                      minimumSize: const Size(48, 48),
                      shape: const CircleBorder()),
                  onPressed: _showGoal,
                  icon:
                      const Icon(PhosphorIconsRegular.calendarBlank, size: 18)),
            ]),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(15) > 20) {
                return Column(children: [
                  weight,
                  const SizedBox(height: 12),
                  distance,
                ]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: weight),
                    const SizedBox(width: 12),
                    Expanded(child: distance),
                  ]);
            }),
            const SizedBox(height: 16),
            _panel(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 22),
                      child: Text('Workout preferences',
                          style: type.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500))),
                  _preference(
                    title: 'Rest Timer',
                    description:
                        'Start a rest countdown after completing a set.',
                    icon: PhosphorIconsRegular.timer,
                    iconColor: colors.onSurfaceVariant,
                    iconBackground: _isDark
                        ? colors.primaryContainer
                        : AppColors.paleLavender,
                    activeColor: AppColors.lavender,
                    value: settings.restTimerDuration > 0,
                    onChanged: (on) =>
                        _save(() => settings.setRestTimerDuration(on ? 60 : 0)),
                    details: settings.restTimerDuration > 0
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ({
                              30,
                              60,
                              90,
                              120,
                              180,
                              settings.restTimerDuration
                            }.toList()
                                  ..sort())
                                .map((seconds) => ChoiceChip(
                                    label: Text('${seconds}s'),
                                    labelStyle: type.bodySmall
                                        ?.copyWith(color: colors.onSurface),
                                    backgroundColor: _panelColor,
                                    selectedColor: _isDark
                                        ? colors.primaryContainer
                                        : AppColors.paleLavender,
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 5),
                                    selected:
                                        settings.restTimerDuration == seconds,
                                    onSelected: (_) => _save(
                                        () => settings.setRestTimerDuration(seconds))))
                                .toList())
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _preference(
                    title: 'Haptic Feedback',
                    description:
                        'Use vibration for supported workout feedback.',
                    icon: PhosphorIconsRegular.vibrate,
                    iconColor: _isDark ? colors.onSurface : AppColors.ink,
                    iconBackground: AppColors.coral.withValues(alpha: .25),
                    activeColor: AppColors.coral,
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (on) =>
                        _save(() => settings.setHapticFeedbackEnabled(on)),
                  ),
                  if (_health.isAvailable) ...[
                    const SizedBox(height: 12),
                    _preference(
                      title: 'Apple Health',
                      description:
                          'Save finished workouts to Health, and show runs, walks and steps from Health in Stats.',
                      icon: PhosphorIconsRegular.heartbeat,
                      iconColor: _isDark ? colors.onSurface : AppColors.ink,
                      iconBackground: AppColors.lime.withValues(alpha: .45),
                      activeColor: const Color(0xFF6741B2),
                      value: _healthOn,
                      onChanged: _setHealth,
                    ),
                  ],
                ]),
                padding: 8,
                radius: 28),
            const SizedBox(height: 18),
            Container(
              key: _goalKey,
              child: _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _iconBadge(PhosphorIconsRegular.flag,
                          colors.onPrimaryContainer, colors.primaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text('Weekly workout goal',
                              style: type.titleMedium)),
                    ]),
                    const SizedBox(height: 18),
                    _panel(
                        Row(children: [
                          IconButton.filledTonal(
                              tooltip: 'Decrease weekly goal',
                              onPressed: scheduled > 1
                                  ? () => _save(() =>
                                      settings.setWeeklyGoal(scheduled - 1))
                                  : null,
                              icon: const Icon(Icons.remove_rounded)),
                          Expanded(
                              child: Column(children: [
                            Text('$scheduled', style: type.displayMedium),
                            Text('per week', style: subtitleStyle),
                          ])),
                          IconButton.filledTonal(
                              tooltip: 'Increase weekly goal',
                              onPressed: scheduled < 14
                                  ? () => _save(() =>
                                      settings.setWeeklyGoal(scheduled + 1))
                                  : null,
                              icon: const Icon(Icons.add_rounded)),
                        ]),
                        color: colors.surface,
                        padding: 12,
                        radius: 20),
                    const SizedBox(height: 14),
                    Text('$current this week. Changes start next Monday.',
                        style: subtitleStyle),
                    const SizedBox(height: 8),
                    Text(
                        'Weeks run Monday–Sunday. Meet your weekly goal to extend your streak.',
                        style: subtitleStyle),
                  ])),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 0),
                child: Text(
                    'Units apply to new entries. Saved sets keep their original unit.',
                    style: subtitleStyle)),
            const SizedBox(height: 20),
            TextButton.icon(
                onPressed: () => context.read<AuthNotifier>().signOut(),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign out')),
          ]),
        ),
      ),
    );
  }
}
