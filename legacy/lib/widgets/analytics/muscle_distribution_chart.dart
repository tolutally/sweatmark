import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

/// Donut chart showing muscle group distribution
class MuscleDistributionChart extends StatefulWidget {
  final Map<String, int> distribution;
  final double size;

  const MuscleDistributionChart({
    super.key,
    required this.distribution,
    this.size = 200,
  });

  @override
  State<MuscleDistributionChart> createState() =>
      _MuscleDistributionChartState();
}

class _MuscleDistributionChartState extends State<MuscleDistributionChart> {
  int touchedIndex = -1;

  static const List<Color> _muscleColors = [
    AppColors.brandTeal, // Teal
    Color(0xFFFF6B6B), // Red
    Color(0xFF4ECDC4), // Cyan
    Color(0xFFFFE66D), // Yellow
    Color(0xFF95E1D3), // Light teal
    Color(0xFFFF9F43), // Orange
    Color(0xFF6C5CE7), // Purple
    Color(0xFFFF85A1), // Pink
    Color(0xFF00B894), // Green
    Color(0xFF74B9FF), // Blue
  ];

  Color _getColorForMuscle(int index) {
    return _muscleColors[index % _muscleColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.distribution.isEmpty) {
      return SizedBox(
        height: widget.size,
        child: const Center(
          child: Text(
            'No workout data yet',
            style: TextStyle(color: Colors.black38),
          ),
        ),
      );
    }

    final sorted = widget.distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = widget.distribution.values.fold(0, (a, b) => a + b);

    return Row(
      children: [
        // Donut chart
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: widget.size * 0.3,
              sections: List.generate(sorted.length, (index) {
                final entry = sorted[index];
                final isTouched = index == touchedIndex;
                final percentage = (entry.value / total * 100).toStringAsFixed(0);

                return PieChartSectionData(
                  color: _getColorForMuscle(index),
                  value: entry.value.toDouble(),
                  title: isTouched ? '$percentage%' : '',
                  radius: isTouched ? widget.size * 0.22 : widget.size * 0.18,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sorted.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              final percentage = (data.value / total * 100).toStringAsFixed(0);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getColorForMuscle(index),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.key,
                        style: TextStyle(
                          fontSize: 12,
                          color: touchedIndex == index
                              ? Colors.black87
                              : Colors.black54,
                          fontWeight: touchedIndex == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: touchedIndex == index
                            ? Colors.black87
                            : Colors.black38,
                        fontWeight: touchedIndex == index
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Bar chart alternative for muscle distribution
class MuscleDistributionBarChart extends StatelessWidget {
  final Map<String, int> distribution;

  const MuscleDistributionBarChart({
    super.key,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) {
      return const Center(
        child: Text(
          'No workout data yet',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.first.value;

    return Column(
      children: sorted.take(6).map((entry) {
        final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${entry.value} sessions',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.brandTeal),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
