import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../screens/home_screen.dart';
import '../screens/workout_screen.dart';
import '../screens/recovery_screen.dart';
import '../screens/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const WorkoutScreen(),
    const RecoveryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.house),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.barbell),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.heartbeat),
            label: 'Recovery',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
