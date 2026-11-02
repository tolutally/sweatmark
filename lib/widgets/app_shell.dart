import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/library_screen.dart';
import '../screens/workout_history_screen.dart';
import '../screens/active_workout_screen.dart';
import '../state/workout_notifier.dart';
import '../state/navigation/tab_navigation_notifier.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<TabNavigationNotifier>();
    final workout = context.watch<WorkoutNotifier>();
    final colors = Theme.of(context).colorScheme;
    void openWorkout() {
      if (!workout.isWorkoutActive) workout.startWorkout();
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()));
    }

    return Scaffold(
      body: IndexedStack(
        index: navigation.currentIndex.clamp(0, 3),
        children: const [
          HomeScreen(),
          LibraryScreen(),
          WorkoutHistoryScreen(),
          StatsScreen()
        ],
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (workout.isWorkoutActive && navigation.currentIndex != 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(PhosphorIconsFill.play,
                    color: colors.onPrimaryContainer),
                textColor: colors.onPrimaryContainer,
                title: Text(
                    'Resume ${workout.currentWorkout?.workoutName ?? 'workout'}'),
                onTap: openWorkout,
              ),
            ),
          ),
        AppNavigationDock(
          selectedIndex: navigation.currentIndex,
          onSelected: navigation.goTo,
          onWorkoutPressed: openWorkout,
          isWorkoutActive: workout.isWorkoutActive,
        ),
      ]),
    );
  }
}

/// Reference dock: edge-to-edge ink surface and a raised lavender action.
class AppNavigationDock extends StatelessWidget {
  const AppNavigationDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onWorkoutPressed,
    this.isWorkoutActive = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onWorkoutPressed;
  final bool isWorkoutActive;

  Widget _destination(BuildContext context, int index, String label,
      IconData icon, IconData activeIcon) {
    final selected = selectedIndex == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkWell(
            key: ValueKey('navigation-${label.toLowerCase()}'),
            onTap: () => onSelected(index),
            splashColor: AppColors.lavender.withValues(alpha: .15),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 78),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 2, 14),
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(selected ? activeIcon : icon,
                        size: 21,
                        color: selected
                            ? AppColors.paleLavender
                            : AppColors.referenceMuted),
                    const SizedBox(height: 10),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w400,
                            color: selected
                                ? AppColors.paleLavender
                                : const Color(0xFF9C9BAF))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = isWorkoutActive ? 'Resume workout' : 'Start workout';
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Material(
            key: const ValueKey('navigation-surface'),
            color: AppColors.ink,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _destination(context, 0, 'Home', PhosphorIconsRegular.house,
                    PhosphorIconsFill.house),
                _destination(
                    context,
                    2,
                    'History',
                    PhosphorIconsRegular.clipboardText,
                    PhosphorIconsFill.clipboardText),
                const SizedBox(width: 80),
                _destination(
                    context,
                    1,
                    'Browse',
                    PhosphorIconsRegular.folderSimple,
                    PhosphorIconsFill.folderSimple),
                _destination(context, 3, 'Stats', PhosphorIconsRegular.chartBar,
                    PhosphorIconsFill.chartBar),
              ]),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Tooltip(
              message: action,
              child: Semantics(
                button: true,
                label: action,
                child: Material(
                  key: const ValueKey('navigation-workout-action'),
                  color: AppColors.paleLavender,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onWorkoutPressed,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                            color: AppColors.lavender, shape: BoxShape.circle),
                        child: ExcludeSemantics(
                          child: Icon(
                              isWorkoutActive
                                  ? PhosphorIconsFill.play
                                  : PhosphorIconsRegular.plus,
                              size: 23,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
