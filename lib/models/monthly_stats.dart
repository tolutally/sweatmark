import 'exercise_model.dart';
import 'workout_model.dart';

/// A local, read-only summary of completed work. Missing units are never guessed.
/// [durations] replaces a workout's own time, by id, with Apple Watch time.
class MonthlyStats {
  final List<int> dailyWorkouts;
  final List<int> monthlyWorkouts = List.filled(12, 0);
  final List<WorkoutLog> loggedWorkouts = [];
  int workouts = 0;
  int timedWorkouts = 0;
  int totalSeconds = 0;

  /// Workouts whose time came from a same-day Apple Health workout.
  int watchTimedWorkouts = 0;
  int strengthSets = 0;
  int reps = 0;
  double volumeKg = 0;
  int weightedSets = 0;
  int unknownWeightSets = 0;
  int cardioSessions = 0;
  int cardioSeconds = 0;
  int timedCardioSets = 0;
  double distanceKm = 0;
  int distanceSets = 0;
  int unknownDistanceSets = 0;
  final Map<String, int> muscleSets = {};
  int get activeDays => dailyWorkouts.where((n) => n > 0).length;
  int? get averageSeconds =>
      timedWorkouts == 0 ? null : (totalSeconds / timedWorkouts).round();

  MonthlyStats._(int days) : dailyWorkouts = List.filled(days, 0);

  factory MonthlyStats.calculate(Iterable<WorkoutLog> history, DateTime month,
      {Map<String, Exercise> catalog = const {},
      DateTime? now,
      bool year = false,
      Map<String, int> durations = const {}}) {
    final result = MonthlyStats._(year
        ? DateTime.utc(month.year + 1)
            .difference(DateTime.utc(month.year))
            .inDays
        : DateTime(month.year, month.month + 1, 0).day);
    final seen = <String>{};
    final cutoff = now ?? DateTime.now();
    for (final workout in history) {
      final date = workout.timestamp.toLocal();
      if (workout.isTestData ||
          date.year != month.year ||
          (!year && date.month != month.month) ||
          workout.timestamp.isAfter(cutoff) ||
          !seen.add(workout.id)) continue;
      final entries = workout.exercises
          .where((e) => e.sets.any((s) => s.isCompleted && !s.isSuperSetRest))
          .toList();
      if (entries.isEmpty) continue;
      result.workouts++;
      result.loggedWorkouts.add(workout);
      result.monthlyWorkouts[date.month - 1]++;
      result.dailyWorkouts[year
          ? DateTime.utc(date.year, date.month, date.day)
              .difference(DateTime.utc(date.year))
              .inDays
          : date.day - 1]++;
      final watch = durations[workout.id];
      final seconds =
          watch != null && watch > 0 ? watch : workout.durationSeconds;
      if (watch != null && watch > 0) result.watchTimedWorkouts++;
      if (seconds > 0) {
        result.timedWorkouts++;
        result.totalSeconds += seconds;
      }
      var hasCardio = false;
      for (final exercise in entries) {
        final sets = exercise.sets
            .where((s) => s.isCompleted && !s.isSuperSetRest)
            .toList();
        final definition = catalog[exercise.exerciseId];
        final group = (exercise.muscleGroup?.trim().isNotEmpty == true
                ? exercise.muscleGroup
                : definition?.muscleGroup) ??
            '';
        final cardio = isCardio(exercise, definition);
        if (cardio) {
          hasCardio = true;
          for (final set in sets) {
            if ((set.durationSeconds ?? 0) > 0) {
              result.cardioSeconds += set.durationSeconds!;
              result.timedCardioSets++;
            }
            if (set.distance != null &&
                set.distance!.isFinite &&
                set.distance! > 0) {
              if (set.distanceUnit == 'km' || set.distanceUnit == 'mi') {
                result.distanceKm +=
                    set.distance! * (set.distanceUnit == 'mi' ? 1.609344 : 1);
                result.distanceSets++;
              } else {
                result.unknownDistanceSets++;
              }
            }
          }
        } else {
          result.strengthSets += sets.length;
          final muscle = normalizeMuscle(group);
          result.muscleSets[muscle] =
              (result.muscleSets[muscle] ?? 0) + sets.length;
          for (final set in sets) {
            if ((set.reps ?? 0) > 0) result.reps += set.reps!;
            if (set.weight != null &&
                set.weight!.isFinite &&
                set.weight! > 0 &&
                (set.reps ?? 0) > 0) {
              if (set.weightUnit == 'kg' || set.weightUnit == 'lb') {
                result.volumeKg += set.weightKg! * set.reps!;
                result.weightedSets++;
              } else {
                result.unknownWeightSets++;
              }
            }
          }
        }
      }
      if (hasCardio) result.cardioSessions++;
    }
    result.loggedWorkouts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  static bool isCardio(WorkoutExerciseLog exercise, Exercise? definition) {
    final type = exercise.exerciseType ?? definition?.exerciseType.name;
    final group = exercise.muscleGroup ?? definition?.muscleGroup ?? '';
    return type == 'cardio' ||
        group.toLowerCase() == 'cardio' ||
        (type == null &&
            exercise.sets.any((s) =>
                s.isCompleted &&
                !s.isSuperSetRest &&
                ((s.distance ?? 0) > 0 || (s.speed ?? 0) > 0)));
  }

  static String normalizeMuscle(String value) {
    final key = value.trim().toLowerCase();
    const aliases = {
      'abs': 'Core',
      'abdominals': 'Core',
      'abdominal': 'Core',
      'core': 'Core',
      'quads': 'Quadriceps',
      'quadriceps': 'Quadriceps',
      'pecs': 'Chest',
      'pectorals': 'Chest',
      'lats': 'Back',
      'middle back': 'Back',
      'upper back': 'Back',
      'lower back': 'Lower back',
      'delts': 'Shoulders',
      'deltoids': 'Shoulders',
      'gluteus': 'Glutes'
    };
    if (key.isEmpty || key == 'general' || key == 'unknown')
      return 'Unspecified';
    return aliases[key] ?? '${key[0].toUpperCase()}${key.substring(1)}';
  }
}
