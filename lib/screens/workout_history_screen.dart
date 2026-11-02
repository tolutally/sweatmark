import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../models/workout_model.dart';
import '../state/workout_notifier.dart';
import '../theme/app_theme.dart';
import 'workout_detail_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  // History is already loaded in WorkoutNotifier constructor.
  final _search = TextEditingController();
  String _query = '';
  _HistorySort _sort = _HistorySort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _navigateToWorkoutDetail(BuildContext context, WorkoutLog workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailScreen(workout: workout),
      ),
    );
  }

  void _deleteWorkout(WorkoutLog workout) async {
    final notifier = context.read<WorkoutNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Workout'),
        content: const Text(
            'Are you sure you want to delete this workout? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      notifier.deleteWorkout(workout);
    }
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        appBar: AppBar(
          leading: Navigator.of(context).canPop()
              ? BackButton(
                  style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder()))
              : null,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          iconTheme:
              IconThemeData(color: Theme.of(context).colorScheme.onSurface),
          title: Text(
            'Workout History',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          elevation: 0,
        ),
        body: Consumer<WorkoutNotifier>(
          builder: (context, workoutNotifier, child) {
            final workouts = workoutNotifier.workoutHistory;

            if (workouts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsBold.clock,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No workout history yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your completed workouts will appear here',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            final visible = _visible(workouts);
            final colors = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Row(children: [
                  Expanded(child: _searchField(colors)),
                  const SizedBox(width: 10),
                  _sortButton(colors),
                ]),
                const SizedBox(height: 18),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Text('No workouts match “${_query.trim()}”',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: colors.onSurfaceVariant)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(children: [
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom: i == visible.length - 1 ? 0 : 8),
                          child: _WorkoutCard(
                            workout: visible[i],
                            accent: _accents[i % _accents.length],
                            onTap: () =>
                                _navigateToWorkoutDetail(context, visible[i]),
                            onDelete: () => _deleteWorkout(visible[i]),
                          ),
                        ),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Decorative rhythm only; rows never rely on these colors for meaning.
  static const _accents = [AppColors.lavender, AppColors.lime, AppColors.coral];

  List<WorkoutLog> _visible(List<WorkoutLog> workouts) {
    final query = _query.trim().toLowerCase();
    final matches = workouts
        .where((workout) =>
            query.isEmpty ||
            workout.workoutName.toLowerCase().contains(query) ||
            workout.exercises.any((exercise) =>
                exercise.displayName.toLowerCase().contains(query)))
        .toList();
    switch (_sort) {
      case _HistorySort.newest:
        matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      case _HistorySort.oldest:
        matches.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      case _HistorySort.longest:
        matches.sort((a, b) {
          final byDuration = b.durationSeconds.compareTo(a.durationSeconds);
          return byDuration != 0
              ? byDuration
              : b.timestamp.compareTo(a.timestamp);
        });
      case _HistorySort.name:
        matches.sort((a, b) {
          final byName = a.workoutName
              .toLowerCase()
              .compareTo(b.workoutName.toLowerCase());
          return byName != 0 ? byName : b.timestamp.compareTo(a.timestamp);
        });
    }
    return matches;
  }

  Widget _searchField(ColorScheme colors) => TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search workouts or exercises',
          hintStyle: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
          prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass,
              size: 20, color: colors.onSurfaceVariant),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(PhosphorIconsRegular.x,
                      size: 18, color: colors.onSurfaceVariant),
                ),
          filled: true,
          fillColor: colors.primaryContainer.withValues(alpha: .45),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: colors.primaryContainer),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: colors.primaryContainer),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      );

  Widget _sortButton(ColorScheme colors) => PopupMenuButton<_HistorySort>(
        tooltip: 'Sort workouts',
        initialValue: _sort,
        onSelected: (sort) => setState(() => _sort = sort),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        itemBuilder: (_) => [
          for (final sort in _HistorySort.values)
            CheckedPopupMenuItem(
                value: sort, checked: sort == _sort, child: Text(sort.label)),
        ],
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Icon(PhosphorIconsRegular.sortDescending,
              size: 21, color: colors.onSurface),
        ),
      );
}

enum _HistorySort {
  newest('Newest first'),
  oldest('Oldest first'),
  longest('Longest duration'),
  name('Name (A–Z)');

  const _HistorySort(this.label);
  final String label;
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutLog workout;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(date.year, date.month, date.day);

    if (workoutDate == today) {
      return 'Today';
    } else if (workoutDate == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final day = '${monthNames[date.month - 1]} ${date.day}';
      return date.year == now.year ? day : '$day, ${date.year}';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = workout.exercises.length;
    // Missing duration stays out of the summary instead of reading "0m".
    final details = [
      _formatDate(workout.timestamp),
      '$count ${count == 1 ? 'exercise' : 'exercises'}',
      if (workout.durationSeconds > 0) _formatDuration(workout.durationSeconds),
    ].join(' · ');
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsBold.barbell,
                    size: 21, color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.workoutName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(PhosphorIconsRegular.caretRight,
                    size: 17, color: colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
