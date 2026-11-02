import 'package:flutter/material.dart';
import '../widgets/exercise_media.dart';
import '../models/exercise_model.dart';
import 'exercise_progress_screen.dart';

Future<void> showExerciseInfo(BuildContext context, Exercise exercise) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => FractionallySizedBox(
          heightFactor: .95, child: ExerciseInfoScreen(exercise: exercise)),
    );

class ExerciseInfoScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseInfoScreen({super.key, required this.exercise});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final steps = (exercise.instructions ?? '')
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return DefaultTabController(
        length: 3,
        initialIndex: 2,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Row(children: [
                Expanded(
                    child: TabBar(
                        isScrollable: largeText,
                        tabAlignment:
                            largeText ? TabAlignment.start : TabAlignment.fill,
                        labelColor: colors.primary,
                        labelStyle: text.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        unselectedLabelColor: colors.onSurfaceVariant,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(999)),
                        tabs: const [
                      Tab(text: 'Chart'),
                      Tab(text: 'History'),
                      Tab(text: 'How-to')
                    ])),
                IconButton.filledTonal(
                    tooltip: 'Close exercise info',
                    style: IconButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: colors.onSurface,
                        minimumSize: const Size(44, 44)),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ])),
          Expanded(
              child: TabBarView(children: [
            ExerciseProgressScreen(
                exerciseId: exercise.id, name: exercise.name, section: 'chart'),
            ExerciseProgressScreen(
                exerciseId: exercise.id,
                name: exercise.name,
                section: 'history'),
            ListView(padding: const EdgeInsets.all(20), children: [
              Text(exercise.name, style: text.headlineMedium),
              const SizedBox(height: 24),
              Container(
                  height: 240,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24)),
                  child: exercise.hasGif
                      ? ExerciseMedia(
                          imageUrl: exercise.gifUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Center(
                              child: Text('Illustration unavailable',
                                  style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant))),
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()))
                      : Center(
                          child: Icon(Icons.fitness_center,
                              size: 64, color: colors.onSurfaceVariant))),
              const SizedBox(height: 20),
              if (steps.isEmpty)
                _card(
                    context,
                    const Text(
                        'No instructions available for this exercise yet.')),
              for (var i = 0; i < steps.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _card(
                        context,
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: colors.onPrimaryContainer,
                                          fontWeight: FontWeight.w600))),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Text(
                                      steps[i].replaceFirst(
                                          RegExp(r'^\d+[.)]\s*'), ''),
                                      style: const TextStyle(
                                          fontSize: 15, height: 1.5))),
                            ]))),
              _card(
                  context,
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Muscle · ${exercise.muscleGroup.isEmpty ? 'Not specified' : exercise.muscleGroup}'),
                        const SizedBox(height: 8),
                        Text(
                            'Equipment · ${exercise.equipment.isEmpty ? 'Not specified' : exercise.equipment}'),
                      ])),
            ]),
          ])),
        ]));
  }

  Widget _card(BuildContext context, Widget child) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24)),
      child: child);
}
