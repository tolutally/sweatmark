import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/workout_screen.dart';
import '../screens/recovery_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/active_workout_screen.dart';
import '../state/workout_notifier.dart';
import '../state/navigation/tab_navigation_notifier.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    WorkoutScreen(),
    RecoveryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tabController = context.watch<TabNavigationNotifier>();
    final currentIndex = tabController.currentIndex;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: kBottomNavigationBarHeight +
                MediaQuery.of(context).padding.bottom +
                12,
            child: const _ActiveWorkoutIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.brandCoral.withValues(alpha: 0.18),
        selectedIndex: currentIndex,
        onDestinationSelected: tabController.goTo,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.house, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.house, color: AppColors.brandCoral),
            label: 'Home',
          ),
          NavigationDestination(
            icon:
                Icon(PhosphorIconsRegular.barbell, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.barbell, color: AppColors.brandCoral),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.heartbeat,
                color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.heartbeat, color: AppColors.brandCoral),
            label: 'Recovery',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.user, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.user, color: AppColors.brandCoral),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutIndicator extends StatelessWidget {
  const _ActiveWorkoutIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutNotifier>(
      builder: (context, notifier, _) {
        final workout = notifier.currentWorkout;
        if (!notifier.isWorkoutActive || workout == null) {
          return const SizedBox.shrink();
        }

        final exerciseCount = workout.exercises.length;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Material(
            key: const ValueKey('active_workout_indicator'),
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            color: AppColors.brandNavy,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ActiveWorkoutScreen(),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.play,
                        color: AppColors.brandNavyDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.workoutName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDuration(notifier.elapsedSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}
