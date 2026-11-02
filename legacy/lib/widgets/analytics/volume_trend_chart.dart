import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/analytics_model.dart';
import '../../theme/app_theme.dart';

/// Line chart showing volume trend over time
class VolumeTrendChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  final Color lineColor;
  final Color gradientColor;

  const VolumeTrendChart({
    super.key,
    required this.dailyStats,
    this.lineColor = AppColors.brandTeal,
    this.gradientColor = AppColors.brandTeal,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    final spots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < dailyStats.length; i++) {
      final volume = dailyStats[i].volume.toDouble();
      spots.add(FlSpot(i.toDouble(), volume));
      if (volume > maxY) maxY = volume;
    }

    // Ensure maxY has some value for empty data
    if (maxY == 0) maxY = 1000;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  AnalyticsSummary.formatVolume(value.toInt()),
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _getBottomInterval(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= dailyStats.length) {
                  return const SizedBox.shrink();
                }

                final date = dailyStats[index].date;
                final parts = date.split('-');
                if (parts.length >= 3) {
                  return Text(
                    '${parts[1]}/${parts[2]}',
                    style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Only show dot for days with workouts
                if (dailyStats[index].volume > 0) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: lineColor,
                  );
                }
                return FlDotCirclePainter(
                  radius: 0,
                  color: Colors.transparent,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  gradientColor.withValues(alpha: 0.3),
                  gradientColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black87,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= dailyStats.length) return null;

                final day = dailyStats[index];
                return LineTooltipItem(
                  '${AnalyticsSummary.formatVolume(day.volume)}\n${day.date}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _getBottomInterval() {
    if (dailyStats.length <= 7) return 1;
    if (dailyStats.length <= 14) return 2;
    if (dailyStats.length <= 30) return 5;
    return 10;
  }
}
