import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/workout_model.dart';
import '../data/muscle_assets.dart';

class BodyMapSvg extends StatelessWidget {
  final Map<String, MuscleStatus> statusMap;
  final bool isFront;

  const BodyMapSvg({
    super.key,
    required this.statusMap,
    required this.isFront,
  });

  String _getColorHex(MuscleStatus status) {
    switch (status) {
      case MuscleStatus.recovered:
        return '#3b82f6'; // Blue
      case MuscleStatus.recovering:
        return '#eab308'; // Yellow
      case MuscleStatus.fatigued:
        return '#ef4444'; // Red
    }
  }

  String _processSvg(String rawSvg) {
    String processed = rawSvg;

    // Iterate through all muscle groups in the status map
    statusMap.forEach((muscleGroup, status) {
      final ids = MUSCLE_MAP[muscleGroup];
      if (ids != null) {
        final color = _getColorHex(status);
        for (final id in ids) {
          // We need to find the path with this ID and inject the fill color.
          // The SVG paths look like: <path id="muscle-chest" class="muscle fill-gray-700" ... />
          // We will replace 'id="$id"' with 'id="$id" fill="$color"'
          // Note: This is a simple string replacement and assumes standard formatting.
          
          // A more robust way: Replace `id="muscle-chest"` with `id="muscle-chest" fill="color"`
          // But we should check if fill is already there or if class handles it.
          // The provided SVG has `class="muscle fill-gray-700"`.
          // We can replace `id="$id"` with `id="$id" fill="$color"`.
          // flutter_svg prioritizes attributes over classes usually.
          
          processed = processed.replaceAll('id="$id"', 'id="$id" fill="$color"');
        }
      }
    });

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    final svgString = isFront ? BODY_FRONT_SVG : BODY_BACK_SVG;
    final coloredSvg = _processSvg(svgString);

    return SvgPicture.string(
      coloredSvg,
      fit: BoxFit.contain,
    );
  }
}
