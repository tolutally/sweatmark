import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/monthly_stats.dart';
import 'package:sweatmark/models/workout_model.dart';

WorkoutLog workout(int day, List<WorkoutExerciseLog> exercises,
        {int seconds = 600, bool test = false, int month = 2}) =>
    WorkoutLog(
        workoutName: 'Workout',
        timestamp: DateTime(2024, month, day, 12),
        durationSeconds: seconds,
        exercises: exercises,
        isTestData: test);
WorkoutExerciseLog strength(List<WorkoutSet> sets, {String muscle = 'Chest'}) =>
    WorkoutExerciseLog(
        exerciseId: 'press',
        muscleGroup: muscle,
        exerciseType: 'weightedStrength',
        sets: sets);
WorkoutSet set(
        {double? weight, String? unit, int reps = 10, bool done = true}) =>
    WorkoutSet(weight: weight, weightUnit: unit, reps: reps, isCompleted: done);
void main() {
  final now = DateTime(2024, 3, 1);
  test(
      'counts unique completed sessions, excludes drafts, future and test data',
      () {
    final first = workout(1, [
      strength([set()])
    ]);
    final data = MonthlyStats.calculate([
      first,
      first,
      workout(2, [
        strength([set(done: false)])
      ]),
      workout(
          3,
          [
            strength([set()])
          ],
          test: true),
      workout(
          4,
          [
            strength([set()])
          ],
          seconds: 0),
      workout(
          5,
          [
            strength([set()])
          ],
          month: 3)
    ], DateTime(2024, 2), now: now);
    expect(data.workouts, 2);
    expect(data.activeDays, 2);
    expect(data.dailyWorkouts.length, 29);
    expect(data.totalSeconds, 600);
    expect(data.averageSeconds, 600);
    expect(data.timedWorkouts, 1);
  });
  test(
      'normalizes weight units and muscles without counting unknown volume or rest rows',
      () {
    final data = MonthlyStats.calculate([
      workout(1, [
        strength([
          set(weight: 10, unit: 'kg'),
          set(weight: 22.046226218, unit: 'lb'),
          set(weight: 99),
          set(weight: 100, unit: 'kg', done: false),
          WorkoutSet(isCompleted: true, isSuperSetRest: true, reps: 100)
        ], muscle: 'abs')
      ])
    ], DateTime(2024, 2), now: now);
    expect(data.strengthSets, 3);
    expect(data.reps, 30);
    expect(data.volumeKg, closeTo(200, 0.0001));
    expect(data.unknownWeightSets, 1);
    expect(data.muscleSets, {'Core': 3});
  });
  test('cardio uses recorded duration and converts distances, not session time',
      () {
    final data = MonthlyStats.calculate([
      workout(
          1,
          [
            WorkoutExerciseLog(
                exerciseId: 'run',
                exerciseType: 'cardio',
                sets: [
                  WorkoutSet(
                      isCompleted: true,
                      durationSeconds: 300,
                      distance: 1,
                      distanceUnit: 'mi'),
                  WorkoutSet(
                      isCompleted: true,
                      durationSeconds: 120,
                      distance: 1,
                      distanceUnit: 'km'),
                  WorkoutSet(isCompleted: true, distance: 20),
                  WorkoutSet(
                      isCompleted: false,
                      durationSeconds: 900,
                      distance: 99,
                      distanceUnit: 'km'),
                ]),
            WorkoutExerciseLog(
                exerciseId: 'plank',
                exerciseType: 'timedHold',
                muscleGroup: 'Core',
                sets: [WorkoutSet(isCompleted: true, durationSeconds: 60)])
          ],
          seconds: 3600)
    ], DateTime(2024, 2), now: now);
    expect(data.cardioSessions, 1);
    expect(data.cardioSeconds, 420);
    expect(data.distanceKm, closeTo(2.609344, 0.000001));
    expect(data.unknownDistanceSets, 1);
    expect(data.strengthSets, 1);
    expect(data.muscleSets, {'Core': 1});
  });
  test(
      'distance units and exercise classification survive serialization and copying',
      () {
    final entry =
        WorkoutSet(isCompleted: true, distance: 2, distanceUnit: 'mi');
    expect(
        WorkoutSet.fromJson(entry.toJson())
            .copyWith(isCompleted: false)
            .distanceUnit,
        'mi');
    final exercise = WorkoutExerciseLog(
        exerciseId: 'run', exerciseType: 'cardio', sets: [entry]);
    expect(
        WorkoutExerciseLog.fromJson(exercise.toJson()).exerciseType, 'cardio');
    expect(WorkoutSet.fromJson({'distance': 2}).distanceUnit, isNull);
  });
  test('empty month has no invented duration or volume', () {
    final data = MonthlyStats.calculate([], DateTime(2024, 2), now: now);
    expect(data.averageSeconds, isNull);
    expect(data.workouts, 0);
    expect(data.weightedSets, 0);
    expect(data.distanceSets, 0);
  });
  test('year totals span months and retain dated logs, including leap day', () {
    final jan = workout(
        1,
        [
          strength([set()])
        ],
        month: 1);
    final feb = workout(29, [
      strength([set()])
    ]);
    final dec = workout(
        31,
        [
          strength([set()])
        ],
        month: 12);
    final data = MonthlyStats.calculate([jan, feb, dec, jan], DateTime(2024),
        year: true, now: DateTime(2025));
    expect(data.workouts, 3);
    expect(data.dailyWorkouts.length, 366);
    expect(data.activeDays, 3);
    expect(data.monthlyWorkouts[0], 1);
    expect(data.monthlyWorkouts[1], 1);
    expect(data.monthlyWorkouts[11], 1);
    expect(data.loggedWorkouts.first.timestamp, dec.timestamp);
    final partial = MonthlyStats.calculate([jan, feb, dec], DateTime(2024),
        year: true, now: DateTime(2024, 3));
    expect(partial.workouts, 2);
  });
  test('optional cardio observations round-trip without filling older records',
      () {
    final log = WorkoutExerciseLog(
        exerciseId: 'run',
        sets: [],
        averageHeartRate: 145,
        intensity: 'Moderate');
    final decoded = WorkoutExerciseLog.fromJson(log.toJson());
    expect(decoded.averageHeartRate, 145);
    expect(decoded.intensity, 'Moderate');
    final legacy =
        WorkoutExerciseLog.fromJson({'exerciseId': 'run', 'sets': []});
    expect(legacy.averageHeartRate, isNull);
    expect(legacy.intensity, isNull);
  });
}
