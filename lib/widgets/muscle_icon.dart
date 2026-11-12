import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line icon for a muscle group, from the Hugeicons set in
/// assets/icons/muscles (MIT; see LICENSE.txt there).
class MuscleIcon extends StatelessWidget {
  final String muscle;
  final double size;
  final Color color;
  const MuscleIcon(this.muscle,
      {super.key, this.size = 20, this.color = const Color(0xFF1D1C21)});

  /// The icon file for [muscle]; unknown groups get a general muscle icon.
  static String assetFor(String muscle) {
    final key = muscle.trim().toLowerCase();
    final name = switch (key) {
      'chest' || 'pecs' || 'serratus' => 'equipment-chest-press',
      'back' ||
      'upper back' ||
      'lower back' ||
      'lats' ||
      'traps' ||
      'middle back' =>
        'back-muscle-body',
      'shoulders' || 'delts' || 'neck' => 'shoulder',
      'biceps' || 'triceps' || 'forearms' || 'arms' => 'biceps-flexed',
      'abs' || 'core' || 'obliques' => 'body-part-six-pack',
      'glutes' || 'adductors' || 'abductors' || 'hips' => 'workout-squats',
      'quadriceps' ||
      'quads' ||
      'hamstrings' ||
      'calves' ||
      'legs' =>
        'body-part-leg',
      'cardio' => 'workout-run',
      _ => 'body-part-muscle',
    };
    return 'assets/icons/muscles/$name.svg';
  }

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        assetFor(muscle),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: muscle,
      );
}
