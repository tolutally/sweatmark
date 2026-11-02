import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise_model.dart';
import '../models/template_model.dart';
import '../state/template_notifier.dart';
import 'library_screen.dart';

class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key});
  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  final _name = TextEditingController();
  final List<Exercise> _exercises = [];
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty || _exercises.isEmpty) return;
    setState(() => _saving = true);
    try {
      final routine = await context.read<TemplateNotifier>().createTemplate(
            name: _name.text.trim(),
            exercises: _exercises
                .map((e) => TemplateExercise(
                      id: e.id,
                      name: e.name,
                      targetSets: 3,
                    ))
                .toList(),
          );
      if (!mounted) return;
      if (routine != null) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save routine. Please try again.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save routine. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('New routine'),
          leading: Navigator.of(context).canPop()
              ? BackButton(
                  style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder()))
              : null,
        ),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(
              controller: _name,
              enabled: !_saving,
              maxLength: 80,
              decoration: const InputDecoration(
                  labelText: 'Routine name', hintText: 'e.g. Upper body'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          Text(
              'Saved exercises, ready for your next workout. Start with 3 sets per exercise and adjust while logging.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final exercise in _exercises)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(exercise.name),
                  subtitle: const Text('3 sets'),
                  trailing: IconButton(
                      tooltip: 'Remove ${exercise.name}',
                      icon: const Icon(Icons.close),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _exercises.remove(exercise)))),
            ),
          OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
              onPressed: _saving
                  ? null
                  : () async {
                      final exercise = await Navigator.push<Exercise>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LibraryScreen(isPicker: true)));
                      if (mounted &&
                          exercise != null &&
                          !_exercises.any((e) => e.id == exercise.id)) {
                        setState(() => _exercises.add(exercise));
                      }
                    }),
          const SizedBox(height: 24),
          FilledButton(
              onPressed:
                  _saving || _name.text.trim().isEmpty || _exercises.isEmpty
                      ? null
                      : _save,
              child: Text(_saving ? 'Saving…' : 'Save routine')),
        ]),
      );
}
