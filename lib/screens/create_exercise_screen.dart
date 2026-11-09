import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../models/exercise_model.dart';
import '../theme/app_theme.dart';

class CreateExerciseScreen extends StatefulWidget {
  /// Optional starting values, e.g. from an AI search suggestion.
  final String? initialName;
  final String? initialMuscleGroup;
  final String? initialEquipment;

  const CreateExerciseScreen(
      {super.key,
      this.initialName,
      this.initialMuscleGroup,
      this.initialEquipment});

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  AppDesign get _design => AppDesign.of(context);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  final Set<String> _selectedSetTypes = {'Weight', 'Reps'};
  String? _selectedMuscleGroup;
  String? _selectedEquipment;

  final List<String> _setTypes = [
    'Weight',
    'Reps',
    'Distance',
    'Time',
    'Speed'
  ];
  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Abs / Core',
    'Legs',
  ];
  final List<String> _equipment = [
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Bodyweight',
    'Kettlebell',
    'Bands',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName?.trim() ?? '';
    _selectedMuscleGroup = _matchMuscle(widget.initialMuscleGroup);
    _selectedEquipment = _matchEquipment(widget.initialEquipment);
  }

  /// Library muscle names map onto this screen's broader groups.
  String? _matchMuscle(String? muscle) {
    final key = muscle?.trim().toLowerCase() ?? '';
    if (key.isEmpty) return null;
    for (final group in _muscleGroups) {
      if (group.toLowerCase() == key) return group;
    }
    if (['abs', 'core', 'obliques', 'serratus'].contains(key)) {
      return 'Abs / Core';
    }
    if (['lats', 'upper back', 'lower back', 'traps'].contains(key)) {
      return 'Back';
    }
    if ([
      'quadriceps',
      'hamstrings',
      'glutes',
      'calves',
      'adductors',
      'abductors'
    ].contains(key)) {
      return 'Legs';
    }
    return null;
  }

  String? _matchEquipment(String? equipment) {
    final key = equipment?.trim().toLowerCase() ?? '';
    if (key.isEmpty) return null;
    for (final option in _equipment) {
      if (option.toLowerCase() == key) return option;
    }
    if (key.contains('band')) return 'Bands';
    if (key.contains('body')) return 'Bodyweight';
    if (key.contains('lever') ||
        key.contains('smith') ||
        key.contains('sled')) {
      return 'Machine';
    }
    return 'Other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _createExercise() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }

    if (_selectedMuscleGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a muscle group')),
      );
      return;
    }

    if (_selectedEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select equipment')),
      );
      return;
    }

    final exercise = Exercise(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      muscleGroup: _selectedMuscleGroup!,
      equipment: _selectedEquipment!,
      instructions: _instructionsController.text.isNotEmpty
          ? _instructionsController.text
          : 'No instructions provided',
      videoUrl: '',
      difficulty: 'Intermediate',
      source: 'custom',
    );

    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      child: Scaffold(
        backgroundColor: _colors.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: _colors.surfaceContainerLow,
          foregroundColor: _colors.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(PhosphorIconsRegular.x, color: _colors.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Create Custom Exercise',
            style: TextStyle(
              color: _colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 13,
                        color: _colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Name',
                        hintStyle: TextStyle(
                          fontSize: 17,
                          color: _colors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: _colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _colors.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _colors.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _colors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Set Types Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _colors.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Types',
                      style: TextStyle(
                        fontSize: 13,
                        color: _colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _setTypes.map((type) {
                        final isSelected = _selectedSetTypes.contains(type);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedSetTypes.remove(type);
                              } else {
                                _selectedSetTypes.add(type);
                              }
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _colors.primaryContainer
                                  : _colors.surfaceContainerHighest,
                              border: Border.all(
                                color: isSelected
                                    ? _colors.primary
                                    : _colors.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? _colors.onPrimaryContainer
                                    : _colors.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Muscle Group
              GestureDetector(
                onTap: () => _showMuscleGroupPicker(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _colors.shadow.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsBold.user,
                          color: _colors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Muscle Group',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _selectedMuscleGroup ?? 'Select',
                        style: TextStyle(
                          fontSize: 15,
                          color: _colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        color: _colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Equipment
              GestureDetector(
                onTap: () => _showEquipmentPicker(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _colors.shadow.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _design.warningContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsBold.barbell,
                          color: _design.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Equipment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _selectedEquipment ?? 'Select',
                        style: TextStyle(
                          fontSize: 15,
                          color: _colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        color: _colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              GestureDetector(
                onTap: () => _showInstructionsDialog(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _colors.shadow.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsBold.book,
                          color: _colors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _instructionsController.text.isEmpty ? 'Add' : 'Edit',
                        style: TextStyle(
                          fontSize: 15,
                          color: _colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        color: _colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createExercise,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showMuscleGroupPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Select Muscle Group',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _colors.onSurface,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _muscleGroups
                    .map((muscle) => ListTile(
                          title: Text(
                            muscle,
                            style: TextStyle(
                              fontSize: 15,
                              color: _colors.onSurface,
                            ),
                          ),
                          trailing: _selectedMuscleGroup == muscle
                              ? Icon(PhosphorIconsBold.check,
                                  color: _colors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedMuscleGroup = muscle;
                            });
                            Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Select Equipment',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _colors.onSurface,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _equipment
                    .map((equip) => ListTile(
                          title: Text(
                            equip,
                            style: TextStyle(
                              fontSize: 15,
                              color: _colors.onSurface,
                            ),
                          ),
                          trailing: _selectedEquipment == equip
                              ? Icon(PhosphorIconsBold.check,
                                  color: _colors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedEquipment = equip;
                            });
                            Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instructions'),
        content: TextField(
          controller: _instructionsController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter exercise instructions...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
