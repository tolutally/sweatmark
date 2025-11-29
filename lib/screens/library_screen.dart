import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/exercise_data.dart';
import '../models/exercise_model.dart';
import '../widgets/library_item.dart';
import '../services/storage_service.dart';
import 'create_exercise_screen.dart';

class LibraryScreen extends StatefulWidget {
  final bool isPicker;
  const LibraryScreen({super.key, this.isPicker = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  String _searchQuery = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  String? _selectedDifficulty;
  final StorageService _storageService = StorageService();

  // Filter options extracted from exercise library
  final List<String> _muscleGroups = [
    'Chest', 'Lats', 'Lower Back', 'Quads', 'Hamstrings', 'Calves',
    'Shoulders', 'Biceps', 'Triceps', 'Forearms', 'Abs'
  ];
  final List<String> _equipment = [
    'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight', 'Kettlebell', 'Bands', 'Other'
  ];
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final builtInExercises = EXERCISE_LIBRARY.map((e) => Exercise.fromJson(e)).toList();
    final customExercises = await _storageService.getCustomExercises();
    
    setState(() {
      _allExercises = [...customExercises, ...builtInExercises];
      _filteredExercises = _allExercises;
    });
  }

  void _filter() {
    setState(() {
      _filteredExercises = _allExercises.where((ex) {
        final matchesSearch = ex.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesMuscle = _selectedMuscle == null || ex.muscleGroup == _selectedMuscle;
        final matchesEquipment = _selectedEquipment == null || ex.equipment == _selectedEquipment;
        final matchesDifficulty = _selectedDifficulty == null || ex.difficulty == _selectedDifficulty;
        return matchesSearch && matchesMuscle && matchesEquipment && matchesDifficulty;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filter();
              },
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(_selectedMuscle ?? 'Any Muscle'),
                  selected: _selectedMuscle != null,
                  onSelected: (selected) {
                    if (_selectedMuscle != null) {
                      setState(() {
                        _selectedMuscle = null;
                        _filter();
                      });
                    } else {
                      _showMuscleGroupPicker();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(_selectedEquipment ?? 'Any Equipment'),
                  selected: _selectedEquipment != null,
                  onSelected: (selected) {
                    if (_selectedEquipment != null) {
                      setState(() {
                        _selectedEquipment = null;
                        _filter();
                      });
                    } else {
                      _showEquipmentPicker();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(_selectedDifficulty ?? 'Any Difficulty'),
                  selected: _selectedDifficulty != null,
                  onSelected: (selected) {
                    if (_selectedDifficulty != null) {
                      setState(() {
                        _selectedDifficulty = null;
                        _filter();
                      });
                    } else {
                      _showDifficultyPicker();
                    }
                  },
                ),
                const SizedBox(width: 8),
                if (_selectedMuscle != null || _selectedEquipment != null || _selectedDifficulty != null)
                  FilterChip(
                    label: const Text('Clear All'),
                    selected: false,
                    onSelected: (selected) {
                      setState(() {
                        _selectedMuscle = null;
                        _selectedEquipment = null;
                        _selectedDifficulty = null;
                        _filter();
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredExercises.length + 1, // +1 for Create button
              itemBuilder: (context, index) {
                // Create Exercise Button
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onTap: () async {
                        final Exercise? newExercise = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateExerciseScreen(),
                          ),
                        );
                        if (newExercise != null) {
                          await _storageService.saveCustomExercise(newExercise);
                          await _loadExercises();
                          if (widget.isPicker) {
                            Navigator.pop(context, newExercise);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2BD4BD), Color(0xFF8EC5FC)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2BD4BD).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIconsBold.plus, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Create Custom Exercise',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final exercise = _filteredExercises[index - 1];
                return LibraryItem(
                  exercise: exercise,
                  onTap: widget.isPicker ? () {
                    Navigator.pop(context, exercise);
                  } : null,
                  onInfoTap: () {
                    // Show info dialog
                  },
                );
              },
            ),
          )
        ],
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _muscleGroups.map((muscle) => ListTile(
                  title: Text(
                    muscle,
                    style: const TextStyle(fontSize: 17),
                  ),
                  trailing: _selectedMuscle == muscle
                      ? const Icon(PhosphorIconsBold.check, color: Color(0xFF007AFF))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedMuscle = muscle;
                      _filter();
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _equipment.map((equipment) => ListTile(
                  title: Text(
                    equipment,
                    style: const TextStyle(fontSize: 17),
                  ),
                  trailing: _selectedEquipment == equipment
                      ? const Icon(PhosphorIconsBold.check, color: Color(0xFF007AFF))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedEquipment = equipment;
                      _filter();
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

  void _showDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Select Difficulty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _difficulties.map((difficulty) => ListTile(
                  title: Text(
                    difficulty,
                    style: const TextStyle(fontSize: 17),
                  ),
                  trailing: _selectedDifficulty == difficulty
                      ? const Icon(PhosphorIconsBold.check, color: Color(0xFF007AFF))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedDifficulty = difficulty;
                      _filter();
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
}
