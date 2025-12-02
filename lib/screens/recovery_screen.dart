import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../state/recovery_notifier.dart';
import '../widgets/body_map_svg.dart';
import '../models/workout_model.dart';
import '../theme/app_theme.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _showFront = true;

  // Front-facing muscle groups
  static const List<String> _frontMuscles = [
    'Shoulders',
    'Chest',
    'Biceps',
    'Forearms',
    'Abs',
    'Quads',
    'Calves',
  ];

  // Back-facing muscle groups
  static const List<String> _backMuscles = [
    'Traps',
    'Lats',
    'Lower Back',
    'Triceps',
    'Glutes',
    'Hamstrings',
    'Calves',
  ];

  /// Format relative time from a DateTime
  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'Not yet trained';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RecoveryNotifier>();
    final statusMap = notifier.muscleStatus;
    final lastWorkedMap = notifier.lastWorkedMap;
    final hasWorkoutHistory = notifier.hasWorkoutHistory;

    // Filter muscles based on front/back view
    final visibleMuscleNames = _showFront ? _frontMuscles : _backMuscles;
    
    // Get filtered and sorted muscle list (fatigued first, then recovering, then recovered)
    final sortedMuscles = statusMap.keys
        .where((muscle) => visibleMuscleNames.contains(muscle))
        .toList()
      ..sort((a, b) {
        final statusA = statusMap[a]!;
        final statusB = statusMap[b]!;
        return statusA.index.compareTo(statusB.index);
      });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android: dark icons
        statusBarBrightness: Brightness.light, // iOS: dark icons on light bg
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'Muscle Recovery',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x, color: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            // Front/Back Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleButton(
                          label: 'Front',
                          isSelected: _showFront,
                          onTap: () => setState(() => _showFront = true),
                        ),
                        _ToggleButton(
                          label: 'Back',
                          isSelected: !_showFront,
                          onTap: () => setState(() => _showFront = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Body Map or Empty State
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
                  child: hasWorkoutHistory
                      ? BodyMapSvg(
                          statusMap: statusMap,
                          isFront: _showFront,
                        )
                      : _EmptyStateCard(),
                ),
              ),
            ),

            // Muscle Status List Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'MUSCLE GROUPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Muscle Status List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final muscle = sortedMuscles[index];
                  final status = statusMap[muscle]!;
                  final lastWorked = lastWorkedMap[muscle];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _MuscleStatusRow(
                      muscle: muscle,
                      status: status,
                      lastWorkedText: _formatRelativeTime(lastWorked),
                    ),
                  );
                },
                childCount: sortedMuscles.length,
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.primary : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brandCoral.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _MuscleStatusRow extends StatelessWidget {
  final String muscle;
  final MuscleStatus status;
  final String lastWorkedText;

  const _MuscleStatusRow({
    required this.muscle,
    required this.status,
    required this.lastWorkedText,
  });

  Color _getStatusColor() {
    switch (status) {
      case MuscleStatus.recovered:
        return const Color(0xFF3B82F6); // Blue
      case MuscleStatus.recovering:
        return const Color(0xFFFF8C70); // Lighter coral
      case MuscleStatus.fatigued:
        return AppColors.brandCoral;
    }
  }

  String _getStatusText() {
    switch (status) {
      case MuscleStatus.recovered:
        return 'Recovered';
      case MuscleStatus.recovering:
        return 'Recovering';
      case MuscleStatus.fatigued:
        return 'Fatigued';
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case MuscleStatus.recovered:
        return PhosphorIconsBold.checkCircle;
      case MuscleStatus.recovering:
        return PhosphorIconsBold.timer;
      case MuscleStatus.fatigued:
        return PhosphorIconsBold.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFatigued = status == MuscleStatus.fatigued;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFatigued
              ? AppColors.brandCoral.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: isFatigued
            ? [
                BoxShadow(
                  color: AppColors.brandCoral.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(),
              size: 20,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(width: 12),
          // Muscle name and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  muscle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastWorkedText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsRegular.barbell,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Workout History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first workout to see recovery insights',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
