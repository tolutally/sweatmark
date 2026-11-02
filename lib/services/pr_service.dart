import '../data/exercise_catalog.dart';
import '../models/workout_model.dart';

/// Immutable snapshot: never retain mutable draft sets in a record.
class PersonalRecord {
  final String exerciseId, exerciseName, workoutId, kind;
  final int setIndex, reps;
  final double? weightKg;
  final DateTime timestamp;
  final PersonalRecord? previous;

  /// Shared by the same movement logged under an older ID; see
  /// [ExerciseCatalog.canonicalId].
  final String? canonicalId;
  const PersonalRecord(
      {required this.exerciseId,
      required this.exerciseName,
      required this.workoutId,
      required this.kind,
      required this.setIndex,
      required this.reps,
      required this.weightKg,
      required this.timestamp,
      this.previous,
      this.canonicalId});
  String get key => '${canonicalId ?? exerciseId}/$kind';
  String get celebrationId =>
      '$workoutId/$key/${weightKg?.toStringAsFixed(5)}/$reps';
  bool get isBaseline => previous == null;
  String label(String unit) {
    if (weightKg == null) return '$reps reps';
    final weight = weightKg! * (unit == 'lb' ? 2.2046226218 : 1);
    final value = weight.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    return '$value $unit × $reps';
  }
}

class PRService {
  static int compare(double? weight, int reps, double? oldWeight, int oldReps) {
    final delta = (weight ?? 0) - (oldWeight ?? 0);
    return delta.abs() <= 0.00001
        ? reps.compareTo(oldReps)
        : delta.sign.toInt();
  }

  static WorkoutSet? bestSet(Iterable<WorkoutSet> sets) {
    final eligible = sets
        .where((s) =>
            s.isCompleted &&
            !s.isSuperSetRest &&
            s.weightKg != null &&
            s.weightKg!.isFinite &&
            s.weightKg! > 0 &&
            (s.reps ?? 0) > 0)
        .toList();
    eligible.sort((a, b) => compare(b.weightKg, b.reps!, a.weightKg, a.reps!));
    return eligible.isEmpty ? null : eligible.first;
  }

  /// One final best per exercise/type/workout, ordered chronologically.
  static List<PersonalRecord> records(Iterable<WorkoutLog> history) {
    final workouts = history.where((w) => !w.isTestData).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final best = <String, PersonalRecord>{};
    final result = <PersonalRecord>[];
    for (final workout in workouts) {
      for (final record in forWorkout(workout, best)) {
        result.add(record);
        best[record.key] = record;
      }
    }
    return result;
  }

  static Map<String, PersonalRecord> bests(Iterable<WorkoutLog> history) => {
        for (final record in records(history)) record.key: record,
      };

  static List<PersonalRecord> forWorkout(
      WorkoutLog workout, Map<String, PersonalRecord> best) {
    if (workout.isTestData) return [];
    final candidates = <String, PersonalRecord>{};
    for (final exercise in workout.exercises) {
      if (exercise.exerciseType == 'cardio' ||
          exercise.exerciseType == 'timedHold' ||
          '${exercise.exerciseName} ${exercise.equipment}'
              .toLowerCase()
              .contains('assist')) continue;
      for (var i = 0; i < exercise.sets.length; i++) {
        final set = exercise.sets[i];
        if (!set.isCompleted || set.isSuperSetRest || (set.reps ?? 0) <= 0)
          continue;
        double? kg;
        String kind;
        if (set.weight != null && (!set.weight!.isFinite || set.weight! < 0))
          continue;
        if ((set.weight ?? 0) > 0) {
          kg = set.weightKg;
          if (kg == null ||
              !kg.isFinite ||
              kg <= 0 ||
              !['kg', 'lb'].contains(set.weightUnit)) continue;
          kind = 'weighted';
        } else if (exercise.exerciseType == 'bodyweightReps') {
          kind = 'bodyweight';
        } else {
          continue;
        }
        final canonical = ExerciseCatalog.canonicalId(exercise.exerciseId,
            name: exercise.exerciseName);
        final key = '$canonical/$kind';
        final old = candidates[key] ?? best[key];
        if (old != null && compare(kg, set.reps!, old.weightKg, old.reps) <= 0)
          continue;
        candidates[key] = PersonalRecord(
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.displayName,
            workoutId: workout.id,
            kind: kind,
            setIndex: i,
            reps: set.reps!,
            weightKg: kg,
            timestamp: workout.timestamp,
            previous: best[key],
            canonicalId: canonical);
      }
    }
    return candidates.values.toList();
  }

  List<String> detectPersonalRecords(
          WorkoutLog workout, List<WorkoutLog> history) =>
      forWorkout(workout, bests(history.where((w) => w.id != workout.id)))
          .where((r) => !r.isBaseline)
          .map((r) => r.exerciseName)
          .toList();
}
