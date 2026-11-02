import '../data/exercise_catalog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/exercise_media.dart';
import '../models/exercise_model.dart';
import '../state/exercise_db_notifier.dart';
import '../services/storage_service.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import 'create_exercise_screen.dart';
import 'exercise_info_screen.dart';

class LibraryScreen extends StatefulWidget {
  final bool isPicker;
  const LibraryScreen({super.key, this.isPicker = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _panel =>
      _dark ? _colors.surfaceContainer : AppColors.referencePanel;
  final TextEditingController _searchController = TextEditingController();
  final StorageService _storageService = StorageService();
  // A search response is a subset of the catalog. Keep already loaded items so
  // short queries and filter choices remain useful while another search loads.
  final Map<String, Exercise> _catalog = {};
  String _searchQuery = '';
  String? _selectedMuscle;
  String? _selectedEquipment;
  List<Exercise> _customExercises = [];
  bool _isLoadingCustomExercises = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final exerciseDbNotifier = context.read<ExerciseDbNotifier>();
      await exerciseDbNotifier.search(query: '', forceLoad: true);
      if (!mounted) return;
      await _loadCustomExercises();
    });
  }

  Future<void> _loadCustomExercises() async {
    if (!mounted) return;
    setState(() => _isLoadingCustomExercises = true);
    try {
      final custom = await _storageService.getCustomExercisesMerged();
      custom.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() => _customExercises = custom);
    } catch (error) {
      debugPrint('Error loading custom exercises: $error');
    } finally {
      if (mounted) setState(() => _isLoadingCustomExercises = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final normalized = query.trim();
    setState(() => _searchQuery = normalized);
    final exerciseDbNotifier = context.read<ExerciseDbNotifier>();
    if (normalized.length < 2) {
      // This also cancels a pending remote search. The one-letter filter stays
      // local, while clearing search restores the complete cached library.
      exerciseDbNotifier.search(query: '', forceLoad: true);
    } else {
      exerciseDbNotifier.searchWithDebounce(normalized);
    }
  }

  List<Exercise> _getFilteredExercises(Iterable<Exercise> exercises) {
    final query = _searchQuery.toLowerCase();
    return exercises.where((exercise) {
      final matchesQuery = query.isEmpty ||
          exercise.name.toLowerCase().contains(query) ||
          exercise.muscleGroup.toLowerCase().contains(query) ||
          exercise.equipment.toLowerCase().contains(query);
      return matchesQuery &&
          (_selectedMuscle == null ||
              exercise.muscleGroup.toLowerCase() ==
                  _selectedMuscle!.toLowerCase()) &&
          (_selectedEquipment == null ||
              exercise.equipment.toLowerCase() ==
                  _selectedEquipment!.toLowerCase());
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _clearFilters() => setState(() {
        _selectedMuscle = null;
        _selectedEquipment = null;
      });

  bool get _hasActiveFilters =>
      _selectedMuscle != null || _selectedEquipment != null;

  @override
  Widget build(BuildContext context) {
    final exerciseDbNotifier = context.watch<ExerciseDbNotifier>();
    for (final exercise in exerciseDbNotifier.exercises) {
      _catalog[exercise.id] = exercise;
    }
    final logged = context
        .watch<WorkoutNotifier>()
        .workoutHistory
        .expand((w) => w.exercises);
    final byId = <String, Exercise>{
      // Older logged movements that map onto the catalog appear once, as the
      // catalog entry; their history is matched by canonical ID.
      for (final exercise in logged)
        if (ExerciseCatalog.canonicalId(exercise.exerciseId,
                name: exercise.exerciseName) ==
            exercise.exerciseId)
          exercise.exerciseId: Exercise(
              id: exercise.exerciseId,
              name: exercise.displayName,
              muscleGroup: exercise.muscleGroup ?? '',
              equipment: exercise.equipment ?? '',
              icon: '💪'),
      ..._catalog,
      for (final exercise in _customExercises) exercise.id: exercise,
    };
    final muscles = byId.values
        .map((e) => e.muscleGroup)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final equipment = byId.values
        .map((e) => e.equipment)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final exercises = _getFilteredExercises(byId.values);
    final isLoading =
        (exerciseDbNotifier.isLoading || _isLoadingCustomExercises) &&
            exercises.isEmpty;

    return Scaffold(
        backgroundColor: _panel,
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              if (widget.isPicker)
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(children: [
                      IconButton(
                          tooltip: 'Close exercise picker',
                          style: IconButton.styleFrom(
                              backgroundColor: _colors.surface,
                              foregroundColor: _colors.onSurface,
                              minimumSize: const Size(44, 44)),
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.close_rounded, size: 22)),
                      const SizedBox(width: 6),
                      const Expanded(
                          child: Text('Choose exercises',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w500))),
                      const SizedBox(width: 50)
                    ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: TextField(
                      controller: _searchController,
                      onChanged: _performSearch,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w400),
                      decoration: InputDecoration(
                          hintText: 'Search Exercises',
                          hintStyle: TextStyle(
                              color: _colors.onSurfaceVariant, fontSize: 16),
                          filled: true,
                          fillColor: _colors.surface,
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 25, color: _colors.onSurface),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon:
                                      const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _performSearch('');
                                  }),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide:
                                  BorderSide(color: _colors.outlineVariant)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                              borderSide: const BorderSide(
                                  color: AppColors.lavender, width: 1.5))))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(builder: (_, constraints) {
                    final filters = [
                      _filter(
                          'Any Muscle',
                          'Muscle group',
                          _selectedMuscle,
                          muscles,
                          Icons.accessibility_new_rounded,
                          (value) => setState(() => _selectedMuscle = value)),
                      _filter(
                          'Any Equipment',
                          'Equipment',
                          _selectedEquipment,
                          equipment,
                          Icons.fitness_center_outlined,
                          (value) => setState(() => _selectedEquipment = value))
                    ];
                    if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                        constraints.maxWidth < 280) {
                      return Column(children: [
                        filters[0],
                        const SizedBox(height: 8),
                        filters[1]
                      ]);
                    }
                    return Row(children: [
                      Expanded(child: filters[0]),
                      const SizedBox(width: 10),
                      Expanded(child: filters[1])
                    ]);
                  })),
              if (_hasActiveFilters)
                Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear filters')))),
              const SizedBox(height: 16),
              Expanded(
                  child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: exercises.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(children: [
                            _customRow(),
                            if (isLoading)
                              const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                      color: AppColors.lavender)),
                            if (!isLoading && exercises.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      'No exercises found. Try another search or filter.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(fontSize: 14, height: 1.5)))
                          ]);
                        }
                        return _buildExerciseRow(exercises[index - 1]);
                      }))
            ])));
  }

  Widget _filter(
          String anyLabel,
          String title,
          String? selected,
          List<String> values,
          IconData icon,
          ValueChanged<String?> onChanged) =>
      Material(
          color: selected == null
              ? _colors.surface
              : (_dark ? _colors.primaryContainer : AppColors.paleLavender),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                  color: selected == null
                      ? _colors.outlineVariant
                      : AppColors.lavender)),
          child: Semantics(
              button: true,
              selected: selected != null,
              child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _chooseFilter(
                      anyLabel, title, selected, values, onChanged),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
                            const SizedBox(width: 1),
                            Icon(icon,
                                size: 20,
                                color: _dark
                                    ? AppColors.paleLavender
                                    : AppColors.lavender),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    selected == null
                                        ? anyLabel
                                        : _capitalizeWords(selected),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)))
                          ]))))));

  Future<void> _chooseFilter(String anyLabel, String title, String? selected,
      List<String> values, ValueChanged<String?> onChanged) async {
    // Index zero explicitly means "Any"; dismissing the sheet keeps selection.
    final index = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: _panel,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (sheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .62,
            minChildSize: .3,
            maxChildSize: .9,
            builder: (_, controller) => Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(children: [
                        const SizedBox(width: 44),
                        Expanded(
                            child: Text(title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500))),
                        IconButton(
                            tooltip: 'Close filters',
                            style: IconButton.styleFrom(
                                backgroundColor: _colors.surface,
                                foregroundColor: _colors.onSurface),
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close_rounded, size: 21))
                      ])),
                  Expanded(
                      child: ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: values.length + 1,
                          itemBuilder: (_, index) {
                            final value = index == 0 ? null : values[index - 1];
                            final chosen = selected == value;
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                    color: chosen
                                        ? (_dark
                                            ? _colors.primaryContainer
                                            : AppColors.paleLavender)
                                        : _colors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Semantics(
                                        selected: chosen,
                                        button: true,
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: () =>
                                                Navigator.pop(sheet, index),
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16),
                                                child: Row(children: [
                                                  Expanded(
                                                      child: Text(
                                                          value == null
                                                              ? anyLabel
                                                              : _capitalizeWords(
                                                                  value),
                                                          style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                  if (chosen) ...[
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.check_rounded,
                                                        size: 21,
                                                        color:
                                                            _colors.onSurface)
                                                  ]
                                                ]))))));
                          }))
                ])));
    if (!mounted || index == null) return;
    onChanged(index == 0 ? null : values[index - 1]);
  }

  Future<void> _createExercise() async {
    final exercise = await Navigator.push<Exercise>(context,
        MaterialPageRoute(builder: (_) => const CreateExerciseScreen()));
    if (exercise == null || !mounted) return;
    final custom = exercise.copyWith(source: 'custom');
    try {
      await _storageService.saveCustomExercise(custom);
      if (!mounted) return;
      await _loadCustomExercises();
      if (mounted && widget.isPicker) Navigator.pop(context, custom);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save custom exercise')));
      }
    }
  }

  Widget _customRow() => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: _createExercise,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: _dark
                            ? _colors.primaryContainer
                            : AppColors.paleLavender,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.lavender, size: 30)),
                const SizedBox(width: 14),
                const Expanded(
                    child: Text('Create Custom Exercise…',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)))
              ]))));

  Widget _buildExerciseRow(Exercise exercise) => Material(
      color: Colors.transparent,
      child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.isPicker
              ? () => Navigator.pop(context, exercise)
              : () => showExerciseInfo(context, exercise),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                    width: 56,
                    height: 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: _colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: _colors.shadow.withValues(alpha: .025),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]),
                    child: exercise.hasGif
                        ? ExerciseMedia(
                            imageUrl: exercise.gifUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Icon(
                                Icons.fitness_center_outlined,
                                color: _colors.onSurfaceVariant,
                                size: 22),
                            errorWidget: (_, __, ___) => Icon(
                                Icons.fitness_center_outlined,
                                color: _colors.onSurfaceVariant,
                                size: 22))
                        : Icon(Icons.fitness_center_outlined,
                            color: _colors.onSurfaceVariant, size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(exercise.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.35))),
                const SizedBox(width: 3),
                IconButton(
                    tooltip: 'Info for ${exercise.name}',
                    padding: const EdgeInsets.all(10),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.info_outline_rounded,
                        color: AppColors.lavender, size: 24),
                    onPressed: () => showExerciseInfo(context, exercise))
              ]))));

  String _capitalizeWords(String text) => text
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
