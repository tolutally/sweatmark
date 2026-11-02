import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/weekly_progress.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/models/workout_result.dart';
import 'package:sweatmark/services/pr_service.dart';

WorkoutSet weighted(double weight, String? unit, int reps,
        {bool complete = true, bool rest = false}) =>
    WorkoutSet(
        weight: weight,
        weightUnit: unit,
        reps: reps,
        isCompleted: complete,
        isSuperSetRest: rest);

WorkoutExerciseLog exercise(List<WorkoutSet> sets,
        {String id = 'press',
        String? name = 'Bench Press',
        String type = 'weightedStrength',
        String? image}) =>
    WorkoutExerciseLog(
        exerciseId: id,
        exerciseName: name,
        exerciseType: type,
        gifUrl: image,
        sets: sets);

WorkoutLog workout(List<WorkoutExerciseLog> exercises,
        {DateTime? date, bool testData = false, int duration = 4200}) =>
    WorkoutLog(
        workoutName: 'Morning workout',
        timestamp: date ?? DateTime(2026, 11, 1, 9, 30),
        durationSeconds: duration,
        exercises: exercises,
        isTestData: testData);

WorkoutResultData result(WorkoutLog current,
        {List<WorkoutLog> history = const [],
        List<PersonalRecord> records = const [],
        String weightUnit = 'kg',
        String distanceUnit = 'km',
        Map<String, int> goals = const {}}) =>
    WorkoutResultData.fromWorkout(
        workout: current,
        history: history,
        records: records,
        weightUnit: weightUnit,
        distanceUnit: distanceUnit,
        weeklyGoals: goals);

void main() {
  test(
      'summary groups saved exercise snapshots and counts completed non-rest sets only',
      () {
    final current = workout([
      exercise([
        weighted(50, 'kg', 8),
        weighted(100, 'kg', 20, complete: false),
        weighted(150, 'kg', 30, rest: true)
      ], image: 'https://example.com/bench.gif'),
      exercise([weighted(55, 'kg', 6)], name: 'Bench renamed'),
      exercise([weighted(10, 'kg', 12, complete: false)], id: 'unfinished'),
      exercise([weighted(10, 'kg', 12, rest: true)], id: 'rest-only'),
    ]);
    final data = result(current);
    expect(data.completedSets, 2);
    expect(data.exerciseCount, 1);
    expect(data.exercises.single.name, 'Bench Press');
    expect(data.exercises.single.imageUrl, 'https://example.com/bench.gif');
    expect(data.exercises.single.resultLabel, '55 kg × 6');
    expect(data.volumeLabel, '730 kg');
    expect(data.durationLabel, '1h 10m');
    expect(data.dateLabel, 'Nov 1, 2026 · 9:30 AM');
  });

  test(
      'volume and best sets normalize kg/lb and reject invalid or unknown weights',
      () {
    final current = workout([
      exercise([
        weighted(10, 'kg', 10),
        weighted(22.046226218, 'lb', 5),
        weighted(999, null, 99),
        weighted(999, 'stone', 99),
        weighted(double.nan, 'kg', 99),
        weighted(double.infinity, 'kg', 99),
        weighted(-50, 'kg', 99),
        weighted(100, 'kg', 0),
        weighted(1000, 'kg', 10, complete: false),
        weighted(1000, 'kg', 10, rest: true),
      ])
    ]);
    final kg = result(current);
    final lb = result(current, weightUnit: 'lb');
    expect(kg.volumeLabel, '150 kg');
    expect(lb.volumeLabel, '331 lb');
    expect(kg.exercises.single.resultLabel, '10 kg × 10');
    expect(lb.exercises.single.resultLabel, '22 lb × 10');
  });

  test(
      'cardio totals completed set metrics and distinguishes missing distance units',
      () {
    final current = workout([
      exercise([
        WorkoutSet(
            isCompleted: true,
            durationSeconds: 300,
            distance: 1,
            distanceUnit: 'mi',
            weight: 99,
            weightUnit: 'kg',
            reps: 99),
        WorkoutSet(
            isCompleted: true,
            durationSeconds: 120,
            distance: 1.609344,
            distanceUnit: 'km'),
        WorkoutSet(isCompleted: true, durationSeconds: 60, distance: 4),
        WorkoutSet(
            isCompleted: true,
            durationSeconds: -20,
            distance: double.nan,
            distanceUnit: 'km'),
        WorkoutSet(
            isCompleted: false,
            durationSeconds: 900,
            distance: 9,
            distanceUnit: 'km'),
        WorkoutSet(
            isCompleted: true,
            isSuperSetRest: true,
            durationSeconds: 900,
            distance: 9,
            distanceUnit: 'km'),
      ], id: 'run', name: 'Running', type: 'cardio'),
      exercise([weighted(99, 'kg', 99)],
          id: 'hold', name: 'Hold', type: 'timedHold'),
    ]);
    final data = result(current, distanceUnit: 'mi');
    expect(data.volumeLabel, '—');
    expect(data.exercises.first.resultLabel,
        '2 mi · 8 min · Distance unit not recorded');
    expect(data.exercises.last.resultLabel, 'Time not recorded');
    expect(result(current).exercises.first.resultLabel,
        '3.2 km · 8 min · Distance unit not recorded');
  });

  test('timed exercise result preserves seconds in the longest completed hold',
      () {
    final current = workout([
      exercise([
        WorkoutSet(isCompleted: true, durationSeconds: 30),
        WorkoutSet(isCompleted: true, durationSeconds: 90),
        WorkoutSet(isCompleted: false, durationSeconds: 300),
        WorkoutSet(
            isCompleted: true, isSuperSetRest: true, durationSeconds: 900),
      ], id: 'plank', type: 'timedHold')
    ]);
    expect(result(current).exercises.single.resultLabel, '1m 30s');
  });

  test(
      'a bodyweight PR label takes precedence over a separate weighted baseline',
      () {
    final previous = workout([
      exercise([
        WorkoutSet(isCompleted: true, reps: 10),
      ], id: 'pullup', type: 'bodyweightReps')
    ], date: DateTime(2026, 10, 31, 9));
    final current = workout([
      exercise([
        WorkoutSet(isCompleted: true, reps: 12),
        weighted(5, 'kg', 5),
      ], id: 'pullup', type: 'bodyweightReps')
    ]);
    final records = PRService.records([previous, current]);
    final data = result(current, history: [previous], records: records);
    expect(data.newRecordCount, 1);
    expect(data.exercises.single.resultLabel, '12 reps');
    expect(data.exercises.single.isNewRecord, isTrue);
    expect(data.exercises.single.isBaseline, isFalse);
  });

  test('baseline-only labels include the recorded types and are never new PRs',
      () {
    final current = workout([
      exercise([
        WorkoutSet(isCompleted: true, reps: 10),
        weighted(5, 'kg', 5),
      ], id: 'pullup', type: 'bodyweightReps')
    ]);
    final data = result(current,
        records: PRService.records([current]), weightUnit: 'lb');
    expect(data.newRecordCount, 0);
    expect(data.exercises.single.isNewRecord, isFalse);
    expect(data.exercises.single.isBaseline, isTrue);
    expect(data.exercises.single.resultLabel, '10 reps · 11 lb × 5');
  });

  test(
      'PR count deduplicates each record type and ignores other workout records',
      () {
    final previous = workout([
      exercise([
        WorkoutSet(isCompleted: true, reps: 10),
        weighted(5, 'kg', 5),
      ], id: 'pullup', type: 'bodyweightReps')
    ], date: DateTime(2026, 10, 31, 9));
    final current = workout([
      exercise([
        WorkoutSet(isCompleted: true, reps: 12),
        weighted(6, 'kg', 6),
      ], id: 'pullup', type: 'bodyweightReps')
    ]);
    final records = PRService.records([previous, current]);
    final data =
        result(current, history: [previous], records: [...records, ...records]);
    expect(data.newRecordCount, 2);
    expect(data.exercises.single.resultLabel, '12 reps · 6 kg × 6');
    expect(data.exercises.single.isNewRecord, isTrue);
    final testCopy = workout(current.exercises, testData: true);
    expect(result(testCopy, records: records).newRecordCount, 0);
    expect(result(testCopy, records: records).exercises.single.isBaseline,
        isFalse);
  });

  test(
      'streak deduplicates current workout and excludes test, rest-only, and future logs',
      () {
    WorkoutLog entry(DateTime date,
            {bool testData = false, bool rest = false}) =>
        workout([
          exercise([weighted(10, 'kg', 10, rest: rest)])
        ], date: date, testData: testData);
    final current = entry(DateTime(2026, 11, 1, 9, 30));
    final history = [
      entry(DateTime(2026, 10, 19, 9)),
      entry(DateTime(2026, 10, 21, 9)),
      current,
      current,
      entry(DateTime(2026, 10, 27, 9), testData: true),
      entry(DateTime(2026, 10, 28, 9), rest: true),
      entry(DateTime(2026, 11, 1, 15)),
    ];
    final goals = {weekKey(DateTime(2026, 10, 19)): 2};
    expect(result(current, history: history, goals: goals).streakWeeks, 1);
    expect(
        result(current,
                history: [...history, entry(DateTime(2026, 10, 30, 9))],
                goals: goals)
            .streakWeeks,
        2);
  });

  test(
      'missing units and invalid measurements never become invented performances',
      () {
    final current = workout([
      exercise([weighted(100, null, 8), weighted(200, 'stone', 6)],
          id: 'unknown'),
      exercise([weighted(double.nan, 'kg', 8), weighted(-2, 'kg', 8)],
          id: 'invalid'),
      exercise([
        WorkoutSet(isCompleted: true, reps: 15),
        WorkoutSet(isCompleted: true, reps: 20)
      ], id: 'pushup', type: 'bodyweightReps'),
    ], duration: 0);
    final data = result(current);
    expect(data.durationLabel, 'Duration not recorded');
    expect(data.volumeLabel, '—');
    expect(data.exercises[0].resultLabel, '8 reps · weight unit not recorded');
    expect(data.exercises[1].resultLabel, 'Performance not recorded');
    expect(data.exercises[2].resultLabel, '20 reps');
  });
}
