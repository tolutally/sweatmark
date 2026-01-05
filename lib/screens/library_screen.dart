import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise_model.dart';
import '../theme/app_theme.dart';
import '../state/exercise_db_notifier.dart';
import '../state/auth_notifier.dart';
import '../services/recovery_service.dart';
import '../models/muscle_recovery_model.dart';
import '../services/storage_service.dart';
import 'create_exercise_screen.dart';

class LibraryScreen extends StatefulWidget {
  final bool isPicker;
  const LibraryScreen({super.key, this.isPicker = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RecoveryService _recoveryService = RecoveryService();
  final StorageService _storageService = StorageService();
  String _searchQuery = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  Map<String, MuscleRecovery> _muscleRecoveries = {};
  List<Exercise> _customExercises = [];
  List<String> _availableMuscles = [];
  List<String> _availableEquipment = [];
  bool _isLoadingCustomExercises = false;

  @override
  void initState() {
    super.initState();
    // Initialize ExerciseDB - load all exercises from cache
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final exerciseDbNotifier = context.read<ExerciseDbNotifier>();
      await exerciseDbNotifier.search(
          query: '', forceLoad: true); // Load all cached exercises
      await _loadCustomExercises();

      // Load filter options from exercises
      _loadFilterOptions();

      // Load muscle recovery data
      await _loadRecoveryData();
    });
  }

  void _loadFilterOptions() {
    final exerciseDbNotifier = context.read<ExerciseDbNotifier>();
    final exercises = [
      ...exerciseDbNotifier.exercises,
      ..._customExercises,
    ];

    // Get unique muscle groups
    final muscles = exercises
        .map((e) => e.muscleGroup)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    muscles.sort();

    // Get unique equipment
    final equipment = exercises
        .map((e) => e.equipment)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    equipment.sort();

    setState(() {
      _availableMuscles = muscles;
      _availableEquipment = equipment;
    });
  }

  Future<void> _loadRecoveryData() async {
    final authNotifier = context.read<AuthNotifier>();
    final userId = authNotifier.user?.uid;

    final recoveries = userId != null
        ? await _recoveryService.getRecoveryFirestore(userId)
        : await _recoveryService.getRecoveryLocal();

    setState(() {
      _muscleRecoveries = {
        for (var r in recoveries) r.muscleGroup: r,
      };
    });
  }

  Future<void> _loadCustomExercises() async {
    setState(() => _isLoadingCustomExercises = true);
    try {
      final custom = await _storageService.getCustomExercisesMerged();
      custom.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() => _customExercises = custom);
      _loadFilterOptions();
    } catch (e) {
      print('Error loading custom exercises: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingCustomExercises = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    setState(() => _searchQuery = query);
    final exerciseDbNotifier = context.read<ExerciseDbNotifier>();
    exerciseDbNotifier.searchWithDebounce(query);
  }

  List<Exercise> _applySearchFilter(List<Exercise> exercises) {
    if (_searchQuery.isEmpty) return exercises;
    final query = _searchQuery.toLowerCase();
    return exercises
        .where((ex) =>
            ex.name.toLowerCase().contains(query) ||
            ex.muscleGroup.toLowerCase().contains(query) ||
            ex.equipment.toLowerCase().contains(query))
        .toList();
  }

  List<Exercise> _getFilteredExercises(List<Exercise> exercises) {
    var filtered = _applySearchFilter(exercises);

    if (_selectedMuscle != null) {
      filtered = filtered
          .where((ex) =>
              ex.muscleGroup.toLowerCase() == _selectedMuscle!.toLowerCase())
          .toList();
    }

    if (_selectedEquipment != null) {
      filtered = filtered
          .where((ex) =>
              ex.equipment.toLowerCase() == _selectedEquipment!.toLowerCase())
          .toList();
    }

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _selectedMuscle = null;
      _selectedEquipment = null;
    });
  }

  bool get _hasActiveFilters =>
      _selectedMuscle != null || _selectedEquipment != null;

  @override
  Widget build(BuildContext context) {
    final exerciseDbNotifier = context.watch<ExerciseDbNotifier>();
    final allExercises = exerciseDbNotifier.exercises;
    final exercises = [
      ..._getFilteredExercises(_customExercises),
      ..._getFilteredExercises(allExercises),
    ];
    final isLoading =
        (exerciseDbNotifier.isLoading || _isLoadingCustomExercises) &&
            exercises.isEmpty;

    // Update filter options when exercises change
    if ((allExercises.isNotEmpty || _customExercises.isNotEmpty) &&
        _availableMuscles.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFilterOptions());
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          title: Text(
            widget.isPicker ? 'Choose Exercise' : 'Exercise Library',
            style: const TextStyle(color: AppColors.neutral900),
          ),
          iconTheme: const IconThemeData(color: AppColors.neutral800),
          backgroundColor: AppColors.neutral50,
          elevation: 0,
          actions: widget.isPicker
              ? null
              : [
                  PopupMenuButton<String>(
                    icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
                        color: AppColors.neutral800),
                    onSelected: (value) async {
                      if (value == 'download') {
                        _showDownloadExercisesDialog(
                            context, exerciseDbNotifier);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.download, size: 20),
                            SizedBox(width: 12),
                            Text('Download More Exercises'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search ${exercises.length}+ exercises...',
                  hintStyle: const TextStyle(color: AppColors.neutral400),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.neutral500),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.neutral200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.neutral200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.brandTeal, width: 1.5),
                  ),
                ),
                onChanged: (value) => _performSearch(value),
              ),
            ),

            // Filter Dropdowns
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Muscle Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedMuscle != null
                              ? AppColors.brandTeal
                              : AppColors.neutral200,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMuscle,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          hint: const Row(
                            children: [
                              Icon(PhosphorIconsBold.personArmsSpread,
                                  size: 16, color: AppColors.neutral500),
                              SizedBox(width: 6),
                              Text('Muscle',
                                  style: TextStyle(
                                      color: AppColors.neutral500,
                                      fontSize: 13)),
                            ],
                          ),
                          icon: const Icon(PhosphorIconsBold.caretDown,
                              size: 14, color: AppColors.neutral500),
                          isExpanded: true,
                          isDense: true,
                          menuMaxHeight: 300,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Muscles',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            ..._availableMuscles
                                .map((muscle) => DropdownMenuItem(
                                      value: muscle,
                                      child: Text(
                                        _capitalizeWords(muscle),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedMuscle = value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Equipment Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedEquipment != null
                              ? AppColors.brandTeal
                              : AppColors.neutral200,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEquipment,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          hint: const Row(
                            children: [
                              Icon(PhosphorIconsBold.barbell,
                                  size: 16, color: AppColors.neutral500),
                              SizedBox(width: 6),
                              Text('Equipment',
                                  style: TextStyle(
                                      color: AppColors.neutral500,
                                      fontSize: 13)),
                            ],
                          ),
                          icon: const Icon(PhosphorIconsBold.caretDown,
                              size: 14, color: AppColors.neutral500),
                          isExpanded: true,
                          isDense: true,
                          menuMaxHeight: 300,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Equipment',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            ..._availableEquipment
                                .map((equipment) => DropdownMenuItem(
                                      value: equipment,
                                      child: Text(
                                        _capitalizeWords(equipment),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedEquipment = value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Clear Filters Button (shown when filters are active)
            if (_hasActiveFilters)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Row(
                  children: [
                    Text(
                      '${exercises.length} results',
                      style: const TextStyle(
                        color: AppColors.neutral600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brandTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIconsBold.x,
                                size: 14, color: AppColors.brandTeal),
                            SizedBox(width: 4),
                            Text(
                              'Clear Filters',
                              style: TextStyle(
                                color: AppColors.brandTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Exercise List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : exercises.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            return _buildExerciseCard(exercise);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final Exercise? newExercise = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateExerciseScreen(),
              ),
            );
            if (newExercise != null) {
              final Exercise customExercise =
                  newExercise.copyWith(source: 'custom');
              try {
                await _storageService.saveCustomExercise(customExercise);
                await _loadCustomExercises();
                if (!context.mounted) return;
                if (widget.isPicker) {
                  Navigator.pop(context, customExercise);
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to save custom exercise'),
                  ),
                );
              }
            }
          },
          backgroundColor: AppColors.brandTeal,
          icon: const Icon(PhosphorIconsBold.plus, color: Colors.white),
          label: const Text(
            'Create Exercise',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsBold.magnifyingGlass,
              size: 64, color: AppColors.neutral400),
          SizedBox(height: 16),
          Text(
            'No exercises found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: AppColors.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final recovery = _muscleRecoveries[exercise.muscleGroup];

    return GestureDetector(
      onTap: widget.isPicker ? () => Navigator.pop(context, exercise) : null,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: recovery != null && recovery.shouldWarn
              ? Border.all(
                  color: Color(
                      int.parse('0xFF${recovery.statusColor.substring(1)}')),
                  width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Exercise Image/GIF
            if (exercise.gifUrl != null && exercise.gifUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: exercise.gifUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.neutral100,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.neutral100,
                    child: const Icon(PhosphorIconsBold.barbell,
                        size: 32, color: AppColors.neutral400),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIconsBold.barbell,
                    size: 32, color: AppColors.brandTeal),
              ),
            const SizedBox(width: 16),
            // Exercise Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        exercise.muscleGroup,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.neutral600,
                        ),
                      ),
                      if (recovery != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(int.parse(
                                    '0xFF${recovery.statusColor.substring(1)}'))
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                recovery.statusEmoji,
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                recovery.timeSinceLastTrained,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(int.parse(
                                      '0xFF${recovery.statusColor.substring(1)}')),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (exercise.equipment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(PhosphorIconsBold.barbell,
                            size: 14, color: AppColors.neutral500),
                        const SizedBox(width: 4),
                        Text(
                          exercise.equipment,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isPicker)
              const Icon(PhosphorIconsBold.caretRight,
                  size: 20, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showDownloadExercisesDialog(
      BuildContext context, ExerciseDbNotifier notifier) {
    String currentTerm = '';
    int progress = 0;
    int total = 0;
    bool isDownloading = false;
    bool isComplete = false;
    Map<String, dynamic>? result;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(PhosphorIconsBold.download,
                  color: AppColors.brandTeal),
              const SizedBox(width: 12),
              const Expanded(child: Text('Download All Exercises')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDownloading && !isComplete) ...[
                const Text(
                  'This will download ALL exercises from the ExerciseDB database. This may take several minutes.',
                ),
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: notifier.getExerciseCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Text(
                      'Current exercises: $count',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral800,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚠️ Keep the app open during download',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral600,
                  ),
                ),
              ],
              if (isDownloading && !isComplete) ...[
                const LinearProgressIndicator(
                  backgroundColor: AppColors.neutral200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandTeal),
                ),
                const SizedBox(height: 16),
                Text(
                  currentTerm,
                  style: const TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait, this may take a few minutes...',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral800,
                  ),
                ),
              ],
              if (isComplete && result != null) ...[
                const Icon(
                  PhosphorIconsBold.checkCircle,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Download Complete!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Exercises before: ${result!['totalBefore']}'),
                Text('Exercises after: ${result!['totalAfter']}'),
                Text(
                  'New exercises added: ${result!['totalAdded']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandTeal,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!isDownloading && !isComplete)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            if (!isDownloading && !isComplete)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  setDialogState(() {
                    isDownloading = true;
                  });

                  try {
                    final downloadResult =
                        await notifier.populateExerciseDatabase(
                      onProgress: (term, p, t) {
                        setDialogState(() {
                          currentTerm = term;
                          progress = p;
                          total = t;
                        });
                      },
                    );

                    setDialogState(() {
                      isDownloading = false;
                      isComplete = true;
                      result = downloadResult;
                    });

                    // Refresh the exercise list
                    notifier.clearCache();
                    await notifier.search(forceLoad: true);
                    if (mounted) {
                      _loadFilterOptions();
                    }
                  } catch (e) {
                    setDialogState(() {
                      isDownloading = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error downloading exercises: $e')),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Start Download'),
              ),
            if (isComplete)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}
