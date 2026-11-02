import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/workout_model.dart';
import '../data/muscle_assets.dart';

class BodyMapSvg extends StatefulWidget {
  final Map<String, MuscleStatus> statusMap;
  final bool isFront;

  const BodyMapSvg({
    super.key,
    required this.statusMap,
    required this.isFront,
  });

  @override
  State<BodyMapSvg> createState() => _BodyMapSvgState();
}

class _BodyMapSvgState extends State<BodyMapSvg>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulsing if any muscle is fatigued
    if (_hasFatiguedMuscle) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BodyMapSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update animation state based on fatigued muscles
    if (_hasFatiguedMuscle && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_hasFatiguedMuscle && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasFatiguedMuscle =>
      widget.statusMap.values.contains(MuscleStatus.fatigued);

  String _getColorHex(MuscleStatus status) {
    switch (status) {
      case MuscleStatus.recovered:
        return '#3b82f6'; // Blue
      case MuscleStatus.recovering:
        return '#FFB648'; // Amber/Warning
      case MuscleStatus.fatigued:
        return '#FF7A68'; // Coral
    }
  }

  String _processSvg(String rawSvg) {
    String processed = rawSvg;

    // Iterate through all muscle groups in the status map
    widget.statusMap.forEach((muscleGroup, status) {
      final ids = MUSCLE_MAP[muscleGroup];
      if (ids != null) {
        final color = _getColorHex(status);
        for (final id in ids) {
          processed = processed.replaceAll('id="$id"', 'id="$id" fill="$color"');
        }
      }
    });

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    final svgString = widget.isFront ? BODY_FRONT_SVG : BODY_BACK_SVG;
    final coloredSvg = _processSvg(svgString);

    // Clean and simple - no background gradient or glow
    return SvgPicture.string(
      coloredSvg,
      fit: BoxFit.contain,
    );
  }
}
