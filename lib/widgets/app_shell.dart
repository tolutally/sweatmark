import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/recovery_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/active_workout_screen.dart';
import '../state/workout_notifier.dart';
import '../state/navigation/tab_navigation_notifier.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    AnalyticsScreen(),
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
          const _ActiveWorkoutIndicator(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.brandTeal.withValues(alpha: 0.18),
        height: 60,
        selectedIndex: currentIndex,
        onDestinationSelected: tabController.goTo,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.house, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.house, color: AppColors.brandTeal),
            label: 'Home',
          ),
          NavigationDestination(
            icon:
                Icon(PhosphorIconsRegular.chartBar, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.chartBar, color: AppColors.brandTeal),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.heartbeat,
                color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.heartbeat, color: AppColors.brandTeal),
            label: 'Recovery',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.user, color: AppColors.neutral400),
            selectedIcon:
                Icon(PhosphorIconsFill.user, color: AppColors.brandTeal),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutIndicator extends StatefulWidget {
  const _ActiveWorkoutIndicator();

  @override
  State<_ActiveWorkoutIndicator> createState() => _ActiveWorkoutIndicatorState();
}

class _ActiveWorkoutIndicatorState extends State<_ActiveWorkoutIndicator> {
  Offset _position = Offset.zero;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutNotifier>(
      builder: (context, notifier, _) {
        final workout = notifier.currentWorkout;
        if (!notifier.isWorkoutActive || workout == null) {
          return const SizedBox.shrink();
        }

        final exerciseCount = workout.exercises.length;
        final screenSize = MediaQuery.of(context).size;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        
        // Initialize position to bottom center on first build
        if (!_initialized) {
          _position = Offset(
            16, // left padding
            screenSize.height - bottomPadding - kBottomNavigationBarHeight - 70,
          );
          _initialized = true;
        }

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  (_position.dx + details.delta.dx).clamp(0, screenSize.width - 200),
                  (_position.dy + details.delta.dy).clamp(100, screenSize.height - bottomPadding - 80),
                );
              });
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Material(
                key: const ValueKey('active_workout_indicator'),
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            PhosphorIconsBold.play,
                            color: AppColors.brandNavyDeep,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              workout.workoutName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(notifier.elapsedSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
