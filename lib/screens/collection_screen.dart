import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/template_notifier.dart';
import '../state/workout_notifier.dart';
import '../models/template_model.dart';
import '../theme/app_theme.dart';
import 'active_workout_screen.dart';

/// Screen to view templates within a collection
class CollectionScreen extends StatelessWidget {
  final String? collectionId;
  final String collectionName;

  const CollectionScreen({
    super.key,
    required this.collectionId,
    required this.collectionName,
  });

  @override
  Widget build(BuildContext context) {
    final templateNotifier = context.watch<TemplateNotifier>();

    final templates = collectionId == null
        ? templateNotifier.uncategorizedTemplates
        : templateNotifier.getTemplatesInCollection(collectionId!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          collectionName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (collectionId != null)
            IconButton(
              icon: Icon(PhosphorIcons.dotsThree(PhosphorIconsStyle.bold)),
              onPressed: () => _showCollectionOptions(context, templateNotifier),
            ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.folder(PhosphorIconsStyle.regular),
                    size: 64,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No templates in this collection',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save workouts as templates to add them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black26,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return _TemplateCard(
                  template: template,
                  onTap: () => _showTemplateOptions(context, template),
                  onStartWorkout: () => _startWorkoutFromTemplate(context, template),
                );
              },
            ),
    );
  }

  void _showCollectionOptions(BuildContext context, TemplateNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(PhosphorIcons.pencil(PhosphorIconsStyle.regular)),
                title: const Text('Edit Collection'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCollectionDialog(context, notifier);
                },
              ),
              ListTile(
                leading: Icon(
                  PhosphorIcons.trash(PhosphorIconsStyle.regular),
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete Collection',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, notifier);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCollectionDialog(BuildContext context, TemplateNotifier notifier) {
    final collection = notifier.getCollectionById(collectionId!);
    if (collection == null) return;

    final nameController = TextEditingController(text: collection.name);
    final descController = TextEditingController(text: collection.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await notifier.updateCollection(
                  collection.copyWith(
                    name: nameController.text.trim(),
                    description: descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TemplateNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: const Text(
          'This will delete the collection. Templates will be moved to Uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await notifier.deleteCollection(collectionId!, deleteTemplates: false);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTemplateOptions(BuildContext context, WorkoutTemplate template) {
    final templateNotifier = context.read<TemplateNotifier>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill)),
                title: const Text('Start Workout'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startWorkoutFromTemplate(context, template);
                },
              ),
              ListTile(
                leading: Icon(PhosphorIcons.pencil(PhosphorIconsStyle.regular)),
                title: const Text('Edit Template'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditTemplateDialog(context, template, templateNotifier);
                },
              ),
              ListTile(
                leading: Icon(PhosphorIcons.folderSimple(PhosphorIconsStyle.regular)),
                title: const Text('Move to Collection'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveToCollectionDialog(context, template, templateNotifier);
                },
              ),
              ListTile(
                leading: Icon(
                  PhosphorIcons.trash(PhosphorIconsStyle.regular),
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete Template',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteTemplate(context, template, templateNotifier);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTemplateDialog(
      BuildContext context, WorkoutTemplate template, TemplateNotifier notifier) {
    final nameController = TextEditingController(text: template.name);
    final descController = TextEditingController(text: template.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await notifier.updateTemplate(
                  template.copyWith(
                    name: nameController.text.trim(),
                    description: descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMoveToCollectionDialog(
      BuildContext context, WorkoutTemplate template, TemplateNotifier notifier) {
    final collections = notifier.collections;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Collection'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(PhosphorIcons.folder(PhosphorIconsStyle.regular)),
                title: const Text('Uncategorized'),
                selected: template.collectionId == null,
                onTap: () async {
                  await notifier.moveTemplateToCollection(
                    template.id,
                    template.collectionId,
                    null,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ...collections.map((col) => ListTile(
                    leading: Icon(PhosphorIcons.folder(PhosphorIconsStyle.fill)),
                    title: Text(col.name),
                    selected: template.collectionId == col.id,
                    onTap: () async {
                      await notifier.moveTemplateToCollection(
                        template.id,
                        template.collectionId,
                        col.id,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTemplate(
      BuildContext context, WorkoutTemplate template, TemplateNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await notifier.deleteTemplate(template.id, template.collectionId);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _startWorkoutFromTemplate(BuildContext context, WorkoutTemplate template) {
    final workoutNotifier = context.read<WorkoutNotifier>();
    final templateNotifier = context.read<TemplateNotifier>();

    // Start a new workout
    workoutNotifier.startWorkout();
    
    // Rename to template name
    workoutNotifier.updateWorkoutName(template.name);

    // Add exercises from template
    for (final templateExercise in template.exercises) {
      workoutNotifier.addExerciseFromTemplate(
        name: templateExercise.name,
        targetSets: templateExercise.targetSets,
        targetReps: templateExercise.targetReps,
        targetWeight: templateExercise.targetWeight,
      );
    }

    // Increment usage counter
    templateNotifier.useTemplate(template.id);

    // Navigate to active workout
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onTap;
  final VoidCallback onStartWorkout;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onStartWorkout,
  });

  IconData _getPhosphorIcon(TemplateIcon icon) {
    switch (icon) {
      case TemplateIcon.dumbbell:
        return PhosphorIcons.barbell(PhosphorIconsStyle.fill);
      case TemplateIcon.barbell:
        return PhosphorIcons.barbell(PhosphorIconsStyle.bold);
      case TemplateIcon.kettlebell:
        return PhosphorIcons.personSimpleRun(PhosphorIconsStyle.fill);
      case TemplateIcon.running:
        return PhosphorIcons.personSimpleRun(PhosphorIconsStyle.fill);
      case TemplateIcon.heart:
        return PhosphorIcons.heart(PhosphorIconsStyle.fill);
      case TemplateIcon.fire:
        return PhosphorIcons.fire(PhosphorIconsStyle.fill);
      case TemplateIcon.lightning:
        return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
      case TemplateIcon.target:
        return PhosphorIcons.target(PhosphorIconsStyle.fill);
      case TemplateIcon.trophy:
        return PhosphorIcons.trophy(PhosphorIconsStyle.fill);
      case TemplateIcon.star:
        return PhosphorIcons.star(PhosphorIconsStyle.fill);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandCoral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPhosphorIcon(template.icon),
                    color: AppColors.brandCoral,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${template.exercises.length} exercises • Used ${template.timesUsed}x',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black45,
                        ),
                      ),
                      if (template.schedule?.isActive == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.repeat(PhosphorIconsStyle.regular),
                              size: 14,
                              color: AppColors.brandCoral,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              template.schedule!.frequency.displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.brandCoral,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onStartWorkout,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandCoral,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      PhosphorIcons.play(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
