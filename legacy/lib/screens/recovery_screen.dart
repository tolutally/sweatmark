import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import '../services/recovery_service.dart';
import '../models/muscle_recovery_model.dart';
import '../widgets/body_map_svg.dart';
import '../models/workout_model.dart';
import '../theme/app_theme.dart';
import '../state/auth_notifier.dart';
import 'muscle_detail_screen.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final RecoveryService _recoveryService = RecoveryService();
  bool _showFront = true;
  bool _isLoading = true;
  List<MuscleRecovery> _recoveries = [];
  Map<String, MuscleRecovery> _recoveryMap = {};

  // Front-facing muscle groups
  static const List<String> _frontMuscles = [
    'Shoulders',
    'Chest',
    'Arms', // Maps to Biceps/Triceps
    'Core', // Maps to Abs
    'Legs', // Maps to Quads/Calves
  ];

  // Back-facing muscle groups
  static const List<String> _backMuscles = [
    'Shoulders', // Traps
    'Back', // Lats/Lower Back
    'Arms', // Triceps
    'Legs', // Hamstrings/Calves/Glutes
  ];

  @override
  void initState() {
    super.initState();
    _loadRecoveryData();
  }

  Future<void> _loadRecoveryData() async {
    setState(() => _isLoading = true);
    
    final authNotifier = context.read<AuthNotifier>();
    final userId = authNotifier.user?.uid;
    
    final recoveries = userId != null
        ? await _recoveryService.getRecoveryFirestore(userId)
        : await _recoveryService.getRecoveryLocal();
    
    // Apply current decay to all recoveries for accurate display
    final updatedRecoveries = recoveries.map((r) {
      final currentFatigue = RecoveryService.getCurrentFatigue(r);
      return r.copyWith(fatigue: currentFatigue);
    }).toList();
    
    setState(() {
      _recoveries = updatedRecoveries;
      _recoveryMap = {for (var r in updatedRecoveries) r.muscleGroup: r};
      _isLoading = false;
    });
  }

  void _showMuscleDetail(BuildContext context, MuscleRecovery recovery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleDetailScreen(recovery: recovery),
      ),
    );
  }

  /// Convert RecoveryService data to body map format
  /// Maps exercise library muscle names to body SVG muscle IDs
  Map<String, MuscleStatus> _getBodyMapStatus() {
    final Map<String, MuscleStatus> statusMap = {};
    
    // Map exercise library muscles to SVG body map muscles
    final muscleMapping = {
      'Chest': 'Chest',
      'Lats': 'Lats',
      'Mid Back': 'Lats', // Map to same SVG
      'Lower Back': 'Lower Back',
      'Quads': 'Quads',
      'Hamstrings': 'Hamstrings',
      'Calves': 'Calves',
      'Shoulders': 'Shoulders', // Maps to both left and right
      'Rear Delts': 'Shoulders', // Part of shoulders in SVG
      'Biceps': 'Biceps',
      'Triceps': 'Triceps',
      'Forearms': 'Forearms',
      'Core': 'Abs',
      'Glutes': 'Hamstrings', // Glutes shown with hamstrings in back view
      'Glutes/Quads': 'Quads', // Hybrid muscles
      'Glutes/Hamstrings': 'Hamstrings',
    };

    // Initialize all SVG muscles as recovered
    const svgMuscles = [
      'Shoulders', 'Chest', 'Biceps', 'Forearms', 'Abs', 'Quads', 'Calves',
      'Lats', 'Lower Back', 'Triceps', 'Hamstrings',
    ];
    
    for (final muscle in svgMuscles) {
      statusMap[muscle] = MuscleStatus.recovered;
    }

    // Update with actual recovery data from exercise library muscles
    _recoveryMap.forEach((group, recovery) {
      final targetMuscle = muscleMapping[group];
      if (targetMuscle != null) {
        // Use worst status if multiple muscles map to same SVG muscle
        final currentStatus = statusMap[targetMuscle];
        if (currentStatus == null || recovery.status.index > currentStatus.index) {
          statusMap[targetMuscle] = recovery.status;
        }
      }
    });

    return statusMap;
  }

  @override
  Widget build(BuildContext context) {
    final statusMap = _getBodyMapStatus();
    final hasWorkoutHistory = _recoveries.isNotEmpty;

    // Show only muscles with readiness < 80 (adaptive display)
    // Sort by readiness ascending (most fatigued first)
    final visibleRecoveries = _recoveries
      .where((r) => r.readiness < 80)
      .toList()
      ..sort((a, b) => a.readiness.compareTo(b.readiness));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(PhosphorIconsBold.caretLeft, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
              icon: const Icon(PhosphorIconsBold.arrowClockwise, color: Colors.black54),
              onPressed: _loadRecoveryData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadRecoveryData,
                child: CustomScrollView(
                  slivers: [
                    // Summary Stats
                    if (hasWorkoutHistory) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: _buildSummaryCard(),
                        ),
                      ),
                    ],

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
                    if (hasWorkoutHistory) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              Text(
                                visibleRecoveries.isEmpty ? 'ALL MUSCLES RECOVERED' : 'MUSCLES NEEDING RECOVERY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (visibleRecoveries.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${visibleRecoveries.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Muscle Status List or All Recovered Message
                      if (visibleRecoveries.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  PhosphorIconsBold.smiley,
                                  size: 64,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All Muscles Recovered!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your muscles are ready for training',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final recovery = visibleRecoveries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: _MuscleStatusRow(
                                  recovery: recovery,
                                  onTap: () => _showMuscleDetail(context, recovery),
                                ),
                              );
                            },
                            childCount: visibleRecoveries.length,
                          ),
                        ),
                    ],

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final recovered = _recoveries.where((r) => r.isFullyRecovered).length;
    final recovering = _recoveries.where((r) => r.status == MuscleStatus.recovering).length;
    final fatigued = _recoveries.where((r) => r.status == MuscleStatus.fatigued).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandNavy, AppColors.brandNavyDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('💪', recovered.toString(), 'Recovered'),
          _buildStatColumn('⏳', recovering.toString(), 'Recovering'),
          _buildStatColumn('😓', fatigued.toString(), 'Fatigued'),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
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
                    color: AppColors.brandTeal.withValues(alpha: 0.3),
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
  final MuscleRecovery recovery;
  final VoidCallback? onTap;

  const _MuscleStatusRow({
    required this.recovery,
    this.onTap,
  });

  Color _getStatusColor() {
    return Color(int.parse('0xFF${recovery.statusColor.substring(1)}'));
  }

  IconData _getStatusIcon() {
    switch (recovery.status) {
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
    final isFatigued = recovery.shouldWarn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFatigued
              ? _getStatusColor().withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: isFatigued
            ? [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
              color: _getStatusColor().withValues(alpha: 0.1),
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
                  recovery.muscleGroup,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      recovery.timeSinceLastTrained,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      RecoveryService.getMuscleRecoverySpeed(recovery.muscleGroup),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Readiness percentage
          Column(
            children: [
              Text(
                '${recovery.readiness.toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recovery.statusEmoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
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
