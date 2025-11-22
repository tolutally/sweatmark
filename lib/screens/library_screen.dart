import 'package:flutter/material.dart';
import '../data/exercise_data.dart';
import '../models/exercise_model.dart';
import '../widgets/library_item.dart';

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

  @override
  void initState() {
    super.initState();
    _allExercises = EXERCISE_LIBRARY.map((e) => Exercise.fromJson(e)).toList();
    _filteredExercises = _allExercises;
  }

  void _filter() {
    setState(() {
      _filteredExercises = _allExercises.where((ex) {
        final matchesSearch = ex.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesMuscle = _selectedMuscle == null || ex.muscleGroup == _selectedMuscle;
        final matchesEquipment = _selectedEquipment == null || ex.equipment == _selectedEquipment;
        return matchesSearch && matchesMuscle && matchesEquipment;
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
                      // Cycle through a few for demo
                      setState(() {
                        _selectedMuscle = 'Chest';
                        _filter();
                      });
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
                      setState(() {
                        _selectedEquipment = 'Barbell';
                        _filter();
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
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
          ),
        ],
      ),
    );
  }
}
