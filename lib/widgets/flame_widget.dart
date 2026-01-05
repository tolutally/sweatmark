import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/flame_model.dart';
import '../state/flame_notifier.dart';

/// Flame card widget for home screen
class FlameWidget extends StatefulWidget {
  final bool compact; // For summary screen

  const FlameWidget({super.key, this.compact = false});

  @override
  State<FlameWidget> createState() => _FlameWidgetState();
}

class _FlameWidgetState extends State<FlameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlameNotifier?>(
      builder: (context, notifier, child) {
        if (notifier == null) return const SizedBox.shrink();

        final stats = notifier.stats;
        final isLoading = notifier.isLoading;

        // Trigger animation on new peak
        if (notifier.showPeakAnimation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerAnimation();
            notifier.consumePeakAnimation();
          });
        }

        // Show level-up celebration
        if (notifier.showLevelUpAnimation && notifier.newLevel != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLevelUpCelebration(context, notifier.newLevel!);
            notifier.consumeLevelUpAnimation();
          });
        }

        if (isLoading) {
          return _buildCard(
            context,
            volume: '--',
            label: 'Peak Volume',
            subtitle: 'Loading...',
            level: FlameLevel.spark,
            onTap: null,
          );
        }

        final peak = stats?.peak7d ?? 0;
        final level = stats?.level ?? FlameLevel.spark;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildCard(
                context,
                volume: FlameNotifier.formatVolume(peak),
                label: '7-Day Peak',
                subtitle: level.label,
                level: level,
                glowIntensity: _glowAnimation.value,
                onTap: () => _showFlameDetails(context, notifier),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String volume,
    required String label,
    required String subtitle,
    required FlameLevel level,
    double glowIntensity = 0,
    VoidCallback? onTap,
  }) {
    final flameColor = _getFlameColor(level);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(widget.compact ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: glowIntensity > 0
              ? [
                  BoxShadow(
                    color: flameColor.withValues(alpha: 0.4 * glowIntensity),
                    blurRadius: 20 * glowIntensity,
                    spreadRadius: 2 * glowIntensity,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: flameColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsBold.flame,
                color: flameColor,
                size: widget.compact ? 18 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    volume,
                    style: TextStyle(
                      fontSize: widget.compact ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: widget.compact ? 11 : 12,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: widget.compact ? 9 : 10,
                      color: flameColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              color: Colors.black26,
              size: widget.compact ? 16 : 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getFlameColor(FlameLevel level) {
    switch (level) {
      case FlameLevel.spark:
        return const Color(0xFFFF9500);
      case FlameLevel.ember:
        return const Color(0xFFFF7A00);
      case FlameLevel.blaze:
        return const Color(0xFFFF5722);
      case FlameLevel.inferno:
        return const Color(0xFFE64A19);
      case FlameLevel.furnace:
        return const Color(0xFFD32F2F);
      case FlameLevel.nova:
        return const Color(0xFFB71C1C);
      case FlameLevel.supernova:
        return const Color(0xFF880E4F);
    }
  }

  void _showFlameDetails(BuildContext context, FlameNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FlameBottomSheet(notifier: notifier),
    );
  }

  void _showLevelUpCelebration(BuildContext context, FlameLevel newLevel) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _LevelUpDialog(level: newLevel),
    );
  }
}

/// Bottom sheet with flame details and 7-day chart
class _FlameBottomSheet extends StatelessWidget {
  final FlameNotifier notifier;

  const _FlameBottomSheet({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final stats = notifier.stats ?? FlameStats.empty();
    final dailyVolumes = notifier.dailyVolumes ?? [];
    final level = stats.level;
    final nextLevel = level.nextLevel;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Row(
              children: [
                const Icon(PhosphorIconsBold.flame,
                    color: Color(0xFFFF5722), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your Flame',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    level.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Peak 7-Day',
                    value: FlameNotifier.formatVolume(stats.peak7d),
                    icon: PhosphorIconsBold.trophy,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _StatItem(
                    label: 'Current 7-Day',
                    value: FlameNotifier.formatVolume(stats.current7d),
                    icon: PhosphorIconsBold.chartLine,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _StatItem(
                    label: 'Today',
                    value: FlameNotifier.formatVolume(stats.todayVolume),
                    icon: PhosphorIconsBold.calendarBlank,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 7-day bar chart
            if (dailyVolumes.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: _VolumeBarChart(volumes: dailyVolumes),
              ),
              const SizedBox(height: 24),
            ],

            // Progress to next level
            if (nextLevel != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Next: ${nextLevel.label}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        '${FlameNotifier.formatVolume(nextLevel.threshold)} needed',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: level.progressToNext(stats.peak7d),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF5722)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(PhosphorIconsRegular.info,
                      color: Color(0xFFFF9500), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your flame tracks your best 7-day volume. It never goes down!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF5722), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black38,
          ),
        ),
      ],
    );
  }
}

/// Simple bar chart for 7-day volume
class _VolumeBarChart extends StatelessWidget {
  final List<DailyVolume> volumes;

  const _VolumeBarChart({required this.volumes});

  @override
  Widget build(BuildContext context) {
    final maxVolume = volumes.isEmpty
        ? 1
        : volumes.map((v) => v.volume).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVolume == 0 ? 1 : maxVolume;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(volumes.length, (i) {
        final volume = volumes[i];
        final height = (volume.volume / effectiveMax) * 70;
        final dayIndex = DateTime.parse(volume.date).weekday - 1;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              volume.volume > 0
                  ? FlameNotifier.formatVolume(volume.volume)
                  : '',
              style: const TextStyle(fontSize: 9, color: Colors.black38),
            ),
            const SizedBox(height: 4),
            Container(
              width: 28,
              height: height.clamp(4.0, 70.0),
              decoration: BoxDecoration(
                color: i == volumes.length - 1
                    ? const Color(0xFFFF5722)
                    : const Color(0xFFFFCCBC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              days[dayIndex],
              style: TextStyle(
                fontSize: 11,
                color: i == volumes.length - 1
                    ? const Color(0xFFFF5722)
                    : Colors.black38,
                fontWeight: i == volumes.length - 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Level-up celebration dialog
class _LevelUpDialog extends StatelessWidget {
  final FlameLevel level;

  const _LevelUpDialog({required this.level});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔥',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'LEVEL UP!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5722),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You reached ${level.label}!',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      ),
    );
  }
}
