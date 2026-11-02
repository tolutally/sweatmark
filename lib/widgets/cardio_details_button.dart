import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout_model.dart';
import '../state/workout_notifier.dart';

class CardioDetailsButton extends StatelessWidget {
  final WorkoutExerciseLog exercise;
  const CardioDetailsButton({super.key, required this.exercise});
  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(44, 44),
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        icon: const Icon(Icons.favorite_outline, size: 18),
        label: Text(exercise.averageHeartRate == null &&
                exercise.intensity == null
            ? 'Add heart rate & effort'
            : '${exercise.averageHeartRate == null ? 'HR not recorded' : '${exercise.averageHeartRate} bpm'} · ${exercise.intensity ?? 'Effort not recorded'}'),
        onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _CardioDetailsDialog(exercise: exercise)),
      );
}

class _CardioDetailsDialog extends StatefulWidget {
  final WorkoutExerciseLog exercise;
  const _CardioDetailsDialog({required this.exercise});
  @override
  State<_CardioDetailsDialog> createState() => _CardioDetailsDialogState();
}

class _CardioDetailsDialogState extends State<_CardioDetailsDialog> {
  late final _rate = TextEditingController(
      text: widget.exercise.averageHeartRate?.toString() ?? '');
  late String? _effort = widget.exercise.intensity;
  String? _error;
  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Cardio details',
            style: Theme.of(context).textTheme.headlineMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Optional, for this exercise in this workout.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Average heart rate',
                      suffixText: 'bpm',
                      errorText: _error)),
              const SizedBox(height: 20),
              const Text('How hard did it feel?'),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Low', 'Moderate', 'High']
                      .map((e) => ChoiceChip(
                          label: Text(e),
                          selected: _effort == e,
                          onSelected: (selected) =>
                              setState(() => _effort = selected ? e : null)))
                      .toList()),
              const SizedBox(height: 8),
              Text(
                  'Effort is your own rating, not a calculated heart-rate zone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final text = _rate.text.trim();
                final rate = int.tryParse(text);
                if (text.isNotEmpty &&
                    (rate == null || rate < 1 || rate > 300)) {
                  setState(() => _error =
                      'Enter a whole number from 1 to 300, or leave blank.');
                  return;
                }
                context.read<WorkoutNotifier>().updateCardioDetails(
                    widget.exercise.exerciseId,
                    averageHeartRate: rate,
                    intensity: _effort);
                Navigator.pop(context);
              },
              child: const Text('Save'))
        ],
      );
}
