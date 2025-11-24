import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/exercise_model.dart';
import '../state/workout_notifier.dart';
import 'dart:async';

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
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;

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
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _restSeconds = 90; // 1:30 default rest
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _stopRestTimer();
        }
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSeconds = 0;
    });
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

                    // Reps Counter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          const Text(
                            'REPS',
                            style: TextStyle(
                              fontSize: 14,
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
                                  width: 48,
                                  height: 48,
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
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                              Text(
                                reps.toString(),
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                onPressed: () {
                                  setState(() => reps++);
                                },
                                icon: Container(
                                  width: 48,
                                  height: 48,
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Rest Timer (if active)
                    if (_isResting)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2BD4BD), Color(0xFF8EC5FC)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'REST',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatRestTime(_restSeconds),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _stopRestTimer,
                              child: const Text(
                                'Skip Rest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  String _formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }
}
