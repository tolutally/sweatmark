import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/exercise_model.dart';
import '../state/workout_notifier.dart';
import '../state/settings_notifier.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final dynamic exerciseLog;
  final int currentSetIndex;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.exerciseLog,
    required this.currentSetIndex,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late int currentSetIndex;
  int reps = 10;
  int? weight;

  @override
  void initState() {
    super.initState();
    currentSetIndex = widget.currentSetIndex;
    
    // Load current set data if available
    if (currentSetIndex < widget.exerciseLog.sets.length) {
      final currentSet = widget.exerciseLog.sets[currentSetIndex];
      reps = currentSet.reps ?? 10;
      weight = currentSet.weight;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startRestTimer() {
    context.read<SettingsNotifier>().startRestTimer();
  }

  void _stopRestTimer() {
    context.read<SettingsNotifier>().stopRestTimer();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkoutNotifier>();
    final totalSets = widget.exerciseLog.sets.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Set ${currentSetIndex + 1}/$totalSets',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Exercise Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.exercise.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Main Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Exercise Icon/Image
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        PhosphorIconsBold.barbell,
                        size: 80,
                        color: Color(0xFF2BD4BD),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Weight and Reps Inputs
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Weight Input
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'WEIGHT (LB)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black38,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (weight == null) {
                                            weight = 0;
                                          } else if (weight! >= 5) {
                                            weight = weight! - 5;
                                          }
                                        });
                                      },
                                      icon: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          PhosphorIconsBold.minus,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => _showWeightPicker(context),
                                      child: Container(
                                        width: 70,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF2BD4BD),
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          weight?.toString() ?? '--',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (weight == null) {
                                            weight = 5;
                                          } else {
                                            weight = weight! + 5;
                                          }
                                        });
                                      },
                                      icon: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2BD4BD),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2BD4BD).withOpacity(0.3),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          PhosphorIconsBold.plus,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Reps Input
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'REPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black38,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (reps > 1) {
                                          setState(() => reps--);
                                        }
                                      },
                                      icon: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          PhosphorIconsBold.minus,
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => _showRepsPicker(context),
                                      child: Container(
                                        width: 70,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF2BD4BD),
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          reps.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed: () {
                                        setState(() => reps++);
                                      },
                                      icon: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2BD4BD),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2BD4BD).withOpacity(0.3),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          PhosphorIconsBold.plus,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Rest Timer (if active)
                    Consumer<SettingsNotifier>(
                      builder: (context, settings, child) {
                        if (!settings.isResting) return const SizedBox.shrink();
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2BD4BD), Color(0xFF8EC5FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'REST',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                settings.formatRestTime(settings.currentRestSeconds),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => settings.adjustRestTime(-30),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    child: const Text('-30s', style: TextStyle(fontSize: 12)),
                                  ),
                                  TextButton(
                                    onPressed: settings.stopRestTimer,
                                    child: const Text(
                                      'Skip Rest',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => settings.adjustRestTime(30),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    child: const Text('+30s', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Complete Set Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // Save current set
                                notifier.updateSet(
                                  widget.exercise.id,
                                  currentSetIndex,
                                  weight,
                                  reps,
                                );
                                notifier.toggleSetCompletion(
                                  widget.exercise.id,
                                  currentSetIndex,
                                );

                                // Start rest timer
                                _startRestTimer();

                                // Move to next set or close
                                if (currentSetIndex < totalSets - 1) {
                                  setState(() {
                                    currentSetIndex++;
                                    // Load next set data
                                    if (currentSetIndex < widget.exerciseLog.sets.length) {
                                      final nextSet = widget.exerciseLog.sets[currentSetIndex];
                                      reps = nextSet.reps ?? 10;
                                      weight = nextSet.weight;
                                    }
                                  });
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2BD4BD),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Complete Set',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Skip Set Button
                          TextButton(
                            onPressed: () {
                              if (currentSetIndex < totalSets - 1) {
                                setState(() {
                                  currentSetIndex++;
                                  if (currentSetIndex < widget.exerciseLog.sets.length) {
                                    final nextSet = widget.exerciseLog.sets[currentSetIndex];
                                    reps = nextSet.reps ?? 10;
                                    weight = nextSet.weight;
                                  }
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              'Skip Set',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text(
              'Select Weight (lb)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) {
                  final value = (index + 1) * 5;
                  return ListTile(
                    title: Text(
                      '$value lb',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: weight == value ? FontWeight.bold : FontWeight.normal,
                        color: weight == value ? const Color(0xFF2BD4BD) : Colors.black,
                      ),
                    ),
                    selected: weight == value,
                    onTap: () {
                      setState(() => weight = value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepsPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text(
              'Select Reps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) {
                  final value = index + 1;
                  return ListTile(
                    title: Text(
                      '$value reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: reps == value ? FontWeight.bold : FontWeight.normal,
                        color: reps == value ? const Color(0xFF2BD4BD) : Colors.black,
                      ),
                    ),
                    selected: reps == value,
                    onTap: () {
                      setState(() => reps = value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
