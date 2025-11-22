import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/exercise_model.dart';

class LibraryItem extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;

  const LibraryItem({
    super.key,
    required this.exercise,
    this.onTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconData(exercise.icon),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${exercise.muscleGroup} • ${exercise.equipment}'),
        trailing: IconButton(
          icon: const Icon(PhosphorIcons.info),
          onPressed: onInfoTap,
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'ph-barbell': return PhosphorIcons.barbell;
      case 'ph-person-arms-spread': return PhosphorIcons.personArmsSpread;
      case 'ph-butterfly': return PhosphorIcons.butterfly;
      case 'ph-arrow-fat-lines-up': return PhosphorIcons.arrowFatLinesUp;
      case 'ph-arrows-down-up': return PhosphorIcons.arrowsDownUp;
      case 'ph-person-simple-walk': return PhosphorIcons.personSimpleWalk;
      case 'ph-arrows-out-line-vertical': return PhosphorIcons.arrowsOutLineVertical;
      case 'ph-circle-notch': return PhosphorIcons.circleNotch;
      case 'ph-arrow-fat-up': return PhosphorIcons.arrowFatUp;
      case 'ph-chair': return PhosphorIcons.chair;
      case 'ph-hand-fist': return PhosphorIcons.handFist;
      case 'ph-minus': return PhosphorIcons.minus;
      case 'ph-person-simple': return PhosphorIcons.personSimple;
      default: return PhosphorIcons.barbell;
    }
  }
}
