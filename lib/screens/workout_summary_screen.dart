import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../state/workout_notifier.dart';
import '../state/auth_notifier.dart';
import '../models/workout_model.dart';
import '../services/pr_service.dart';
import '../theme/app_theme.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutLog? completedWorkout;
  final int? elapsedSeconds;
  final String? workoutName;
  
  const WorkoutSummaryScreen({
    super.key,
    this.completedWorkout,
    this.elapsedSeconds,
    this.workoutName,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final TextEditingController _notesController = TextEditingController();
  final bool _showEnergyBanner = true;
  final GlobalKey _shareKey = GlobalKey();
  
  // Store workout data locally to prevent crashes if notifier state changes
  WorkoutLog? _workout;
  int _duration = 0;
  String _workoutName = 'My Workout';
  List<String> _prExercises = []; // Track which exercises achieved PRs

  @override
  void initState() {
    super.initState();
    // Capture workout data immediately before any async operations can reset it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkoutData();
    });
  }
  
  void _initializeWorkoutData() {
    final notifier = context.read<WorkoutNotifier>();
    setState(() {
      _workout = widget.completedWorkout ?? notifier.currentWorkout;
      _duration = widget.elapsedSeconds ?? notifier.elapsedSeconds;
      _workoutName = widget.workoutName ?? notifier.workoutName;
      
      // Calculate PRs for this workout
      if (_workout != null) {
        final prService = PRService();
        _prExercises = prService.detectPersonalRecords(_workout!, notifier.workoutHistory);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateWorkoutName(String newName) {
    setState(() {
      _workoutName = newName;
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  String _formatClockTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _bestSetLabel(WorkoutExerciseLog log) {
    // Pick the set with the highest weight*reps, fallback to first set
    if (log.sets.isEmpty) return '';
    final sets = [...log.sets];
    sets.sort((a, b) {
      final av = (a.weight ?? 0) * (a.reps ?? 1);
      final bv = (b.weight ?? 0) * (b.reps ?? 1);
      return bv.compareTo(av);
    });
    final set = sets.first;
    if (set.weight != null && set.reps != null) {
      return '${set.weight!.toStringAsFixed(0)} lb • ${set.reps} reps';
    }
    if (set.distance != null && set.speed != null) {
      return '${set.distance} km • ${set.speed} km/h';
    }
    if (set.distance != null && set.durationSeconds != null) {
      final mins = (set.durationSeconds! ~/ 60).toString().padLeft(1, '0');
      final secs = (set.durationSeconds! % 60).toString().padLeft(2, '0');
      return '$mins:$secs • ${set.distance} km';
    }
    if (set.reps != null) {
      return '${set.reps} reps';
    }
    return '';
  }

  Future<void> _saveSummaryAsImage() async {
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final pixelRatio = View.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        name: 'workout_summary_${DateTime.now().millisecondsSinceEpoch}',
      );

      final success = (result['isSuccess'] as bool?) ?? false;
      if (!mounted) return;

      // Clear any existing snackbars first to prevent stacking
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Saved to photos 🎉' : 'Unable to save image'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          // Position it well above the bottom button to prevent blocking interaction
          margin: const EdgeInsets.only(bottom: 140, left: 20, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.only(bottom: 140, left: 20, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: _workoutName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Workout name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateWorkoutName(controller.text.trim());
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use local state instead of notifier to prevent crashes
    final workout = _workout;

    if (workout == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.brandTeal,
          ),
        ),
      );
    }

    // Calculate stats
    double totalWeight = 0;
    int pointsEarned = 32;
    int caloriesBurned = 63;

    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        if (set.weight != null && set.reps != null) {
          totalWeight += (set.weight! * set.reps!);
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: RepaintBoundary(
          key: _shareKey,
          child: Stack(
            children: [
              // Background hero
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/icon.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.25),
                      BlendMode.darken,
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA000000),
                      Color(0x00FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0.0, 0.35, 0.65],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            _formatClockTime(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(PhosphorIconsBold.calendarCheck, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('SWEATMARK', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title block
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _workoutName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showRenameDialog(context),
                                icon: const Icon(PhosphorIconsRegular.pencilSimple, color: Colors.white70, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(PhosphorIconsRegular.clock, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Cards
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryCard(
                                      title: 'Points earned',
                                      value: '$pointsEarned',
                                      icon: PhosphorIconsBold.sealCheck,
                                      iconColor: const Color(0xFF34C759),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: _SummaryCard(
                                      title: 'Streak',
                                      value: '0 days',
                                      icon: PhosphorIconsBold.trendUp,
                                      iconColor: Color(0xFF1DD3C3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SummaryCard(
                                      title: 'Energy',
                                      value: '$caloriesBurned cal',
                                      icon: PhosphorIconsBold.fire,
                                      iconColor: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SummaryCard(
                                      title: 'Total Weight',
                                      value: '${totalWeight.toStringAsFixed(0)} lb',
                                      icon: PhosphorIconsBold.barbell,
                                      iconColor: const Color(0xFFFFA000),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${workout.exercises.length} Exercises',
                                  style: const TextStyle(
                                    color: Color(0xFF1DA1F2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...workout.exercises.map((e) {
                                final name = e.exerciseName ?? 'Exercise';
                                final best = _bestSetLabel(e);
                                final isPR = _prExercises.contains(name);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F4F8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(PhosphorIconsBold.mountains, size: 18, color: Colors.black54),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                            if (best.isNotEmpty)
                                              Text(
                                                best,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isPR)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.warningSoft,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'PR',
                                            style: TextStyle(
                                              color: AppColors.warning,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: () async {
                final notifier = context.read<WorkoutNotifier>();
                final userId = context.read<AuthNotifier>().user?.uid;
                
                // Use local workout data with updated name
                if (_workout != null) {
                  final workoutToSave = WorkoutLog(
                    workoutName: _workoutName,
                    timestamp: _workout!.timestamp,
                    durationSeconds: _duration,
                    exercises: _workout!.exercises,
                    superSets: _workout!.superSets,
                    notes: _notesController.text,
                    isTestData: false,
                  );
                  await notifier.finishWorkoutWithData(
                    workoutToSave, 
                    _duration, 
                    _notesController.text,
                    userId,
                  );
                } else {
                  // Fallback to old method
                  notifier.updateWorkoutNotes(_notesController.text);
                  await notifier.finishWorkout(userId);
                }

                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: _saveSummaryAsImage,
          child:
              const Icon(PhosphorIconsBold.shareNetwork, color: Colors.black),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
