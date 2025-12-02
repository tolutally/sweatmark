import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/exercise_model.dart';
import '../theme/app_theme.dart';

class CreateExerciseScreen extends StatefulWidget {
  const CreateExerciseScreen({super.key});

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  
  final Set<String> _selectedSetTypes = {'Weight', 'Reps'};
  String? _selectedMuscleGroup;
  String? _selectedEquipment;
  
  final List<String> _setTypes = ['Weight', 'Reps', 'Distance', 'Time', 'Speed'];
  final List<String> _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio', 'Full Body'
  ];
  final List<String> _equipment = [
    'Barbell', 'Dumbbell', 'Cable', 'Machine', 'Bodyweight', 'Kettlebell', 'Bands', 'Other'
  ];

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
    );

    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        foregroundColor: AppColors.neutral900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.x, color: AppColors.neutral800),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Custom Exercise',
          style: TextStyle(
            color: AppColors.neutral900,
            fontSize: 18,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Name',
                      hintStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.black26,
                      ),
                      filled: true,
                      fillColor: AppColors.neutral100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.neutral200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.neutral200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.brandCoral),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set Types',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutral600,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandCoral.withValues(alpha: 0.12)
                                : AppColors.neutral100,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandCoral
                                  : AppColors.neutral200,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.brandCoral
                                  : AppColors.neutral800,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.user,
                        color: AppColors.info,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Muscle Group',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    Text(
                      _selectedMuscleGroup ?? 'Select',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.black38,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.barbell,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Equipment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    Text(
                      _selectedEquipment ?? 'Select',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.black38,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: const Color(0xFFD4F5E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.book,
                        color: Color(0xFF34C759),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                    Text(
                      _instructionsController.text.isEmpty ? 'Add' : 'Edit',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.black38,
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
                  backgroundColor: AppColors.brandCoral,
                  foregroundColor: AppColors.neutral0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Select Muscle Group',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _muscleGroups.map((muscle) => ListTile(
                  title: Text(
                    muscle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral900,
                    ),
                  ),
                  trailing: _selectedMuscleGroup == muscle
                      ? const Icon(PhosphorIconsBold.check, color: AppColors.brandCoral)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMuscleGroup = muscle;
                    });
                    Navigator.pop(context);
                  },
                )).toList(),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Select Equipment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral900,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _equipment.map((equip) => ListTile(
                  title: Text(
                    equip,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.neutral900,
                    ),
                  ),
                  trailing: _selectedEquipment == equip
                      ? const Icon(PhosphorIconsBold.check, color: AppColors.brandCoral)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedEquipment = equip;
                    });
                    Navigator.pop(context);
                  },
                )).toList(),
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
