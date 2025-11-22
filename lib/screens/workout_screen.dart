import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/workout_notifier.dart';
import 'active_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout'), backgroundColor: Colors.transparent),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          onPressed: () {
            context.read<WorkoutNotifier>().startWorkout();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
            );
          },
          child: const Text('Start Workout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
