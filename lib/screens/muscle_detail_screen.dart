import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../models/muscle_recovery_model.dart';
import '../services/recovery_service.dart';
import '../theme/app_theme.dart';

class MuscleDetailScreen extends StatelessWidget {
  final MuscleRecovery recovery;

  const MuscleDetailScreen({
    super.key,
    required this.recovery,
  });

  /// Calculate projected readiness over the next 7 days
  List<FlSpot> _calculateRecoveryProjection() {
    final spots = <FlSpot>[];
    final currentFatigue = recovery.fatigue;
    final k = RecoveryService.getMuscleRecoveryRate(recovery.muscleGroup);
    
    // Add current readiness at hour 0
    spots.add(FlSpot(0, recovery.readiness));
    
    // Project readiness for next 168 hours (7 days) in 4-hour increments
    for (int hour = 4; hour <= 168; hour += 4) {
      final projectedFatigue = currentFatigue * math.exp(-k * hour);
      final projectedReadiness = (100 - projectedFatigue).clamp(0.0, 100.0);
      spots.add(FlSpot(hour.toDouble(), projectedReadiness));
      
      // Stop if fully recovered (readiness >= 95)
      if (projectedReadiness >= 95) break;
    }
    
    return spots;
  }

  /// Calculate hours until fully recovered (readiness >= 95)
  int _hoursUntilRecovered() {
    final currentFatigue = recovery.fatigue;
    if (currentFatigue <= 5) return 0; // Already recovered
    
    final k = RecoveryService.getMuscleRecoveryRate(recovery.muscleGroup);
    
    // Solve: 100 - (fatigue × e^(-k×t)) = 95
    // → fatigue × e^(-k×t) = 5
    // → e^(-k×t) = 5/fatigue
    // → -k×t = ln(5/fatigue)
    // → t = -ln(5/fatigue) / k
    
    final hours = -math.log(5 / currentFatigue) / k;
    return hours.ceil().clamp(0, 9999);
  }

  String _formatHoursToTime(int hours) {
    if (hours <= 0) return 'Now';
    if (hours < 24) return '${hours}h';
    
    final days = (hours / 24).floor();
    final remainingHours = hours % 24;
    
    if (remainingHours == 0) {
      return days == 1 ? '1 day' : '$days days';
    } else {
      return days == 1 ? '1d ${remainingHours}h' : '${days}d ${remainingHours}h';
    }
  }

  Color _getReadinessColor(double readiness) {
    if (readiness >= 80) return const Color(0xFF10B981); // Green
    if (readiness >= 60) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final readiness = recovery.readiness;
    final readinessColor = _getReadinessColor(readiness);
    final projectionSpots = _calculateRecoveryProjection();
    final hoursUntilRecovered = _hoursUntilRecovered();
    final recoverySpeed = RecoveryService.getMuscleRecoverySpeed(recovery.muscleGroup);

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
          leading: IconButton(
            icon: const Icon(PhosphorIconsBold.caretLeft, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            recovery.muscleGroup,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Readiness Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [readinessColor, readinessColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: readinessColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Current Readiness',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          readiness.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const Text(
                          '%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recovery.statusName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: PhosphorIconsBold.clockCounterClockwise,
                      label: 'Last Trained',
                      value: recovery.timeSinceLastTrained,
                      color: AppColors.brandTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: PhosphorIconsBold.timer,
                      label: 'Until Ready',
                      value: _formatHoursToTime(hoursUntilRecovered),
                      color: AppColors.brandNavy,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Recovery Speed Card
              _StatCard(
                icon: PhosphorIconsBold.lightning,
                label: 'Recovery Speed',
                value: recoverySpeed,
                color: AppColors.warning,
              ),

              const SizedBox(height: 32),

              // Recovery Projection Chart
              const Text(
                'Recovery Projection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '7-day forecast based on current fatigue',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Chart
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 20,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 24,
                          getTitlesWidget: (value, meta) {
                            final days = (value / 24).round();
                            if (days == 0) return const Text('Now');
                            return Text(
                              '${days}d',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: projectionSpots.last.x,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: projectionSpots,
                        isCurved: true,
                        color: readinessColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            if (index == 0) {
                              // Highlight current readiness
                              return FlDotCirclePainter(
                                radius: 6,
                                color: readinessColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 2,
                              color: readinessColor.withValues(alpha: 0.5),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              readinessColor.withValues(alpha: 0.3),
                              readinessColor.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Add reference line at 80% (recovered threshold)
                      LineChartBarData(
                        spots: [
                          const FlSpot(0, 80),
                          FlSpot(projectionSpots.last.x, 80),
                        ],
                        isCurved: false,
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        barWidth: 2,
                        dashArray: [5, 5],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Chart Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChartLegendItem(
                    color: readinessColor,
                    label: 'Projected Readiness',
                  ),
                  const SizedBox(width: 20),
                  _ChartLegendItem(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    label: 'Recovery Threshold (80%)',
                    isDashed: true,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brandTeal.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsBold.info,
                      color: AppColors.brandTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Recovery projection assumes no additional training. Training while fatigued applies a 1.3x penalty.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _ChartLegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? Colors.transparent : color,
            border: isDashed ? Border.all(color: color, width: 1.5) : null,
          ),
          child: isDashed
              ? CustomPaint(
                  painter: _DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    double startX = 0;
    const dashWidth = 3.0;
    const dashSpace = 2.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
