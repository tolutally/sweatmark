import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../models/template_model.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import '../data/exercise_data.dart';
import '../data/seed_exercises.dart';
import '../state/template_notifier.dart';
import '../services/notification_service.dart';

/// Bottom sheet for setting up schedule, repeat, and saving as template
class ScheduleBottomSheet extends StatefulWidget {
  final String workoutName;
  final List<WorkoutExerciseLog> exercises;
  final VoidCallback? onSaved;

  const ScheduleBottomSheet({
    super.key,
    required this.workoutName,
    required this.exercises,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String workoutName,
    required List<WorkoutExerciseLog> exercises,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleBottomSheet(
        workoutName: workoutName,
        exercises: exercises,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  RepeatFrequency _selectedFrequency = RepeatFrequency.weekly;
  int _customIntervalDays = 3;
  final Set<int> _selectedWeekDays = {1, 3, 5}; // Mon, Wed, Fri default
  bool _hasReminder = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  TemplateIcon _selectedIcon = TemplateIcon.dumbbell;
  String? _selectedCollectionId;
  bool _createNewCollection = false;
  final _newCollectionNameController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.workoutName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _newCollectionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Save as Template',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template Name
                  _buildSectionTitle('Template Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter template name',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _buildSectionTitle('Description (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add a description...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Icon Selection
                  _buildSectionTitle('Choose Icon'),
                  const SizedBox(height: 12),
                  _buildIconSelector(),
                  const SizedBox(height: 20),

                  // Repeat Frequency
                  _buildSectionTitle('Repeat Frequency'),
                  const SizedBox(height: 12),
                  _buildFrequencySelector(),
                  const SizedBox(height: 20),

                  // Week Days (for weekly)
                  if (_selectedFrequency == RepeatFrequency.weekly) ...[
                    _buildSectionTitle('Repeat On'),
                    const SizedBox(height: 12),
                    _buildWeekDaySelector(),
                    const SizedBox(height: 20),
                  ],

                  // Custom Interval
                  if (_selectedFrequency == RepeatFrequency.custom) ...[
                    _buildSectionTitle('Repeat Every'),
                    const SizedBox(height: 12),
                    _buildCustomIntervalPicker(),
                    const SizedBox(height: 20),
                  ],

                  // Reminder Toggle
                  _buildReminderSection(),
                  const SizedBox(height: 20),

                  // Collection Selection
                  _buildSectionTitle('Save to Collection'),
                  const SizedBox(height: 12),
                  _buildCollectionSelector(),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveTemplate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Save Template',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
    );
  }

  Widget _buildIconSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: TemplateIcon.values.map((icon) {
        final isSelected = _selectedIcon == icon;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = icon),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                _getPhosphorIcon(icon),
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

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

  Widget _buildFrequencySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RepeatFrequency.values.map((freq) {
        final isSelected = _selectedFrequency == freq;
        return GestureDetector(
          onTap: () => setState(() => _selectedFrequency = freq),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              freq.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekDaySelector() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final dayNumber = index + 1;
        final isSelected = _selectedWeekDays.contains(dayNumber);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedWeekDays.remove(dayNumber);
              } else {
                _selectedWeekDays.add(dayNumber);
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                days[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCustomIntervalPicker() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _customIntervalDays > 1
                    ? () => setState(() => _customIntervalDays--)
                    : null,
                icon: Icon(PhosphorIcons.minus(PhosphorIconsStyle.bold)),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$_customIntervalDays',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _customIntervalDays < 30
                    ? () => setState(() => _customIntervalDays++)
                    : null,
                icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'days',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.bell(PhosphorIconsStyle.fill),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reminder Notification',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _hasReminder,
                onChanged: (value) => setState(() => _hasReminder = value),
              ),
            ],
          ),
          if (_hasReminder) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectReminderTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.clock(PhosphorIconsStyle.regular),
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _reminderTime.format(context),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionSelector() {
    final collections = context.watch<TemplateNotifier>().collections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing collections
        if (collections.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // No collection option
              _buildCollectionChip(
                'No Collection',
                null,
                Icons.folder_off_outlined,
              ),
              // Existing collections
              ...collections.map((col) => _buildCollectionChip(
                    col.name,
                    col.id,
                    _getPhosphorIcon(col.icon),
                  )),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Create new collection toggle
        GestureDetector(
          onTap: () => setState(() => _createNewCollection = !_createNewCollection),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _createNewCollection
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.folderPlus(PhosphorIconsStyle.regular),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Create New Collection',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _createNewCollection
                      ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold)
                      : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),

        // New collection input
        if (_createNewCollection) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _newCollectionNameController,
            decoration: InputDecoration(
              hintText: 'Collection name',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollectionChip(String name, String? id, dynamic icon) {
    final isSelected = _selectedCollectionId == id && !_createNewCollection;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCollectionId = id;
          _createNewCollection = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon is IconData ? icon : Icons.folder,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time != null) {
      setState(() => _reminderTime = time);
    }
  }

  /// Schedule notification reminders based on the workout schedule
  Future<void> _scheduleReminders(
    String workoutName,
    String templateId,
    WorkoutSchedule schedule,
  ) async {
    try {
      final notificationService = context.read<NotificationService>();
      
      switch (schedule.frequency) {
        case RepeatFrequency.daily:
          // Schedule daily reminders at the set time
          final now = DateTime.now();
          var scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            _reminderTime.hour,
            _reminderTime.minute,
          );
          
          // If time has passed today, schedule for tomorrow
          if (scheduledTime.isBefore(now)) {
            scheduledTime = scheduledTime.add(const Duration(days: 1));
          }
          
          // Schedule for all 7 days of the week
          await notificationService.scheduleRepeatingReminders(
            workoutName: workoutName,
            weekdays: [1, 2, 3, 4, 5, 6, 7],
            hour: _reminderTime.hour,
            minute: _reminderTime.minute,
            templateId: templateId,
          );
          print('📅 Scheduled daily reminders for "$workoutName"');
          break;
          
        case RepeatFrequency.weekly:
          // Schedule for selected weekdays
          if (_selectedWeekDays.isNotEmpty) {
            await notificationService.scheduleRepeatingReminders(
              workoutName: workoutName,
              weekdays: _selectedWeekDays.toList(),
              hour: _reminderTime.hour,
              minute: _reminderTime.minute,
              templateId: templateId,
            );
            print('📅 Scheduled weekly reminders for "$workoutName" on days $_selectedWeekDays');
          }
          break;
          
        case RepeatFrequency.everyOtherDay:
        case RepeatFrequency.everyThreeDays:
        case RepeatFrequency.biweekly:
        case RepeatFrequency.monthly:
        case RepeatFrequency.custom:
          // For fixed intervals, schedule the next occurrence
          final intervalDays = schedule.frequency == RepeatFrequency.custom
              ? _customIntervalDays
              : schedule.frequency.intervalDays;
          
          final now = DateTime.now();
          var nextOccurrence = DateTime(
            now.year,
            now.month,
            now.day,
            _reminderTime.hour,
            _reminderTime.minute,
          );
          
          // If time has passed today, start from the next interval
          if (nextOccurrence.isBefore(now)) {
            nextOccurrence = nextOccurrence.add(Duration(days: intervalDays));
          }
          
          await notificationService.scheduleWorkoutReminder(
            workoutName: workoutName,
            scheduledTime: nextOccurrence,
            templateId: templateId,
          );
          print('📅 Scheduled interval reminder for "$workoutName" at $nextOccurrence');
          break;
      }
    } catch (e) {
      print('❌ Error scheduling reminders: $e');
    }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final templateNotifier = context.read<TemplateNotifier>();
      String? collectionId = _selectedCollectionId;

      // Create new collection if needed
      if (_createNewCollection && _newCollectionNameController.text.trim().isNotEmpty) {
        final newCollection = await templateNotifier.createCollection(
          name: _newCollectionNameController.text.trim(),
          icon: _selectedIcon,
        );
        if (newCollection != null) {
          collectionId = newCollection.id;
        }
      }

      // Create schedule
      WorkoutSchedule? schedule;
      if (_selectedFrequency != RepeatFrequency.daily || _hasReminder) {
        final now = DateTime.now();
        DateTime? reminderDateTime;
        if (_hasReminder) {
          reminderDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            _reminderTime.hour,
            _reminderTime.minute,
          );
        }

        schedule = WorkoutSchedule(
          frequency: _selectedFrequency,
          customIntervalDays:
              _selectedFrequency == RepeatFrequency.custom ? _customIntervalDays : null,
          weekDays: _selectedFrequency == RepeatFrequency.weekly
              ? _selectedWeekDays.toList()
              : null,
          startDate: now,
          hasReminder: _hasReminder,
          reminderTime: reminderDateTime,
          isActive: true,
        );
      }

      // Convert exercises to template exercises
      final templateExercises = widget.exercises.map((e) {
        // Look up exercise name from database
        Map<String, dynamic>? exerciseData;
        try {
          exerciseData = EXERCISE_LIBRARY.firstWhere(
            (ex) => ex['id'] == e.exerciseId,
          );
        } catch (_) {
          exerciseData = null;
        }
        Exercise? seedData;
        try {
          seedData = seedExercises.firstWhere(
            (ex) => ex.id == e.exerciseId,
          );
        } catch (_) {
          seedData = null;
        }
        final name = exerciseData != null
            ? exerciseData['name'] as String
            : (seedData?.name ?? e.exerciseId);
        return TemplateExercise(
          id: e.exerciseId,
          name: name,
          targetSets: e.sets.length,
          targetReps: e.sets.isNotEmpty ? e.sets.first.reps : null,
          targetWeight: e.sets.isNotEmpty ? e.sets.first.weight?.toDouble() : null,
        );
      }).toList();

      print('📝 Saving template with ${templateExercises.length} exercises');
      print('📝 Template name: ${_nameController.text.trim()}');
      print('📝 Collection ID: $collectionId');
      print('📝 Schedule: ${schedule?.frequency.displayName ?? "None"}');

      // Create the template
      final result = await templateNotifier.createTemplate(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        icon: _selectedIcon,
        exercises: templateExercises,
        schedule: schedule,
        collectionId: collectionId,
      );

      if (result != null) {
        print('✅ Template saved successfully with ID: ${result.id}');
        
        // Schedule notification reminders if enabled
        if (_hasReminder && schedule != null) {
          await _scheduleReminders(result.name, result.id, schedule);
        }
      } else {
        print('⚠️ Template creation returned null - user may not be logged in');
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${_nameController.text}" saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error saving template: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
