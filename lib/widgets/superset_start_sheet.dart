import 'package:flutter/material.dart';

import '../ai/ai_workers.dart';
import '../data/exercise_catalog.dart';
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../theme/app_theme.dart';

/// What the person chose to superset with.
sealed class SupersetChoice {
  const SupersetChoice();
}

/// Open the full exercise library and pick there.
class SupersetFromLibrary extends SupersetChoice {
  const SupersetFromLibrary();
}

/// An exercise already in this workout.
class SupersetWithLogged extends SupersetChoice {
  final String exerciseId;
  const SupersetWithLogged(this.exerciseId);
}

/// A library exercise, e.g. one suggested by AI.
class SupersetWithExercise extends SupersetChoice {
  final Exercise exercise;
  const SupersetWithExercise(this.exercise);
}

/// Asks what to superset [current] with: the exercise library first, then
/// an exercise already in the workout, then AI suggestions for opposite or
/// the same muscles.
Future<SupersetChoice?> showSupersetStartSheet(
  BuildContext context, {
  required WorkoutExerciseLog current,
  required List<WorkoutExerciseLog> inWorkout,
  AiWorkers? ai,
}) =>
    showModalBottomSheet<SupersetChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF6F4FC),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SupersetStartSheet(
          current: current, inWorkout: inWorkout, ai: ai ?? AiWorkers.instance),
    );

class SupersetStartSheet extends StatefulWidget {
  final WorkoutExerciseLog current;
  final List<WorkoutExerciseLog> inWorkout;
  final AiWorkers ai;
  const SupersetStartSheet(
      {super.key,
      required this.current,
      required this.inWorkout,
      required this.ai});

  @override
  State<SupersetStartSheet> createState() => _SupersetStartSheetState();
}

class _SupersetStartSheetState extends State<SupersetStartSheet> {
  static const _purple = Color(0xFF6741B2);

  bool? _sameMuscle; // null until a kind is picked
  bool _loading = false;
  String? _error;
  List<(Exercise, String)> _suggestions = const [];

  Future<void> _suggest(bool sameMuscle) async {
    setState(() {
      _sameMuscle = sameMuscle;
      _loading = true;
      _error = null;
      _suggestions = const [];
    });
    try {
      final current = widget.current;
      final result = await widget.ai.supersetPartners(current.displayName,
          muscle: current.muscleGroup,
          equipment: current.equipment,
          sameMuscle: sameMuscle,
          exclude: [
            current.exerciseId,
            for (final log in widget.inWorkout) log.exerciseId,
          ]);
      final byId = {
        for (final e in await ExerciseCatalog.load()) e.id: e,
      };
      if (!mounted || _sameMuscle != sameMuscle) return;
      setState(() => _suggestions = [
            for (final match in result.matches)
              if (byId[match.id] != null) (byId[match.id]!, match.reason)
          ]);
      if (_suggestions.isEmpty) {
        setState(() => _error = 'No suggestions this time. Try the library.');
      }
    } on AiUnavailable catch (error) {
      if (mounted && _sameMuscle == sameMuscle) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && _sameMuscle == sameMuscle) {
        setState(() => _error = 'Suggestions aren’t available right now.');
      }
    } finally {
      if (mounted && _sameMuscle == sameMuscle) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _section(String title, {String? note}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.referenceMuted)),
          ],
        ]),
      );

  Widget _row(
          {required String name,
          String? detail,
          required VoidCallback onTap,
          Key? key,
          Color dot = _purple}) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      if (detail != null && detail.isNotEmpty)
                        Text(detail,
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: AppColors.referenceMuted)),
                    ]),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: AppColors.paleLavender, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, size: 18, color: _purple),
              ),
            ]),
          ),
        ),
      );

  Widget _kind(String label, String hint, bool sameMuscle, IconData icon) {
    final on = _sameMuscle == sameMuscle;
    return Expanded(
      child: Material(
        color: on ? AppColors.lavender : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey(sameMuscle ? 'ai-same' : 'ai-alternate'),
          borderRadius: BorderRadius.circular(18),
          onTap: _loading && on ? null : () => _suggest(sameMuscle),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: on ? AppColors.ink : _purple),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(hint,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: on ? AppColors.ink : AppColors.referenceMuted)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.inWorkout;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          const Text('Superset with…',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(widget.current.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.referenceMuted)),
          const SizedBox(height: 16),
          // First choice: the whole library, with its search and Ask AI.
          FilledButton.icon(
            key: const ValueKey('superset-library'),
            onPressed: () =>
                Navigator.pop(context, const SupersetFromLibrary()),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.lavender,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99))),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Choose from library',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          ),
          if (others.isNotEmpty) ...[
            _section('In this workout'),
            for (final log in others) ...[
              _row(
                  key: ValueKey('superset-logged-${log.exerciseId}'),
                  name: log.displayName,
                  detail: log.muscleGroup,
                  onTap: () => Navigator.pop(
                      context, SupersetWithLogged(log.exerciseId))),
              const SizedBox(height: 8),
            ],
          ],
          _section('Suggest with AI',
              note: 'Pick a kind and AI suggests partners from the library.'),
          // Both cards stay the same height whatever their text.
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _kind('Opposite muscles', 'One rests while the other works',
                    false, Icons.swap_horiz_rounded),
                const SizedBox(width: 8),
                _kind('Same muscle group', 'Push one muscle harder', true,
                    Icons.local_fire_department_rounded),
              ])),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.referenceMuted)),
            ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final (exercise, reason) in _suggestions) ...[
              _row(
                  key: ValueKey('superset-ai-${exercise.id}'),
                  name: exercise.name,
                  detail: reason,
                  dot: AppColors.coral,
                  onTap: () =>
                      Navigator.pop(context, SupersetWithExercise(exercise))),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
