import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/data/exercise_catalog.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/pr_service.dart';
import 'package:sweatmark/widgets/exercise_media.dart';

WorkoutLog _log(String id, String? name, double kg, DateTime when) =>
    WorkoutLog(
      workoutName: 'Push',
      timestamp: when,
      durationSeconds: 1800,
      exercises: [
        WorkoutExerciseLog(
            exerciseId: id,
            exerciseName: name,
            exerciseType: 'weightedStrength',
            sets: [
              WorkoutSet(
                  weight: kg, weightUnit: 'kg', reps: 8, isCompleted: true)
            ]),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Exercise> catalog;
  setUpAll(() async => catalog = await ExerciseCatalog.load());

  test('bundled catalog is complete, unique and pinned', () {
    expect(catalog, hasLength(1323));
    expect(catalog.map((e) => e.id).toSet(), hasLength(catalog.length));
    expect(catalog.every((e) => e.id.startsWith('gg:')), isTrue);
    expect(catalog.every((e) => e.gifUrl!.contains('@v1.1.0/')), isTrue);
    expect(catalog.every((e) => e.muscleGroup.isNotEmpty), isTrue);
    // Inner-thigh adduction and outer-thigh abduction stay separate.
    final adduction = catalog
        .singleWhere((e) => e.id == 'gg:adductors/lever-seated-hip-adduction');
    final abduction = catalog
        .singleWhere((e) => e.id == 'gg:abductors/lever-seated-hip-abduction');
    expect(adduction.muscleGroup, 'Adductors');
    expect(abduction.muscleGroup, 'Abductors');
  });

  test('every catalog exercise has bundled media', () {
    final missing = [
      for (final exercise in catalog)
        if (!File(ExerciseMedia.assetFor(exercise.gifUrl!)!).existsSync())
          exercise.id
    ];
    expect(missing, isEmpty,
        reason: 'Run scripts/build_exercise_media.py to bundle media.');
    expect(
        ExerciseMedia.assetFor('https://cdn.jsdelivr.net/gh/JahelCuadrado/'
            'ExerciseGymGifsDB@v1.1.0/biceps/barbell-curl.gif'),
        'assets/exercises/media/biceps__barbell-curl.webp');
    // Other sources keep loading from the network.
    expect(ExerciseMedia.assetFor('https://example.com/curl.gif'), isNull);
  });

  test('older IDs map onto the catalog; custom IDs never do', () {
    expect(ExerciseCatalog.canonicalId('free_Upright_Barbell_Row'),
        'gg:delts/barbell-upright-row');
    expect(
        ExerciseCatalog.canonicalId('exercisedb_0042',
            name: 'Barbell Bench Press'),
        'gg:pectorals/barbell-bench-press');
    expect(ExerciseCatalog.canonicalId('ex_hip_adduction_machine'),
        'gg:adductors/lever-seated-hip-adduction');
    expect(ExerciseCatalog.canonicalId('ex_hip_abduction_machine'),
        'gg:abductors/lever-seated-hip-abduction');
    expect(ExerciseCatalog.canonicalId('custom_1', name: 'Barbell Bench Press'),
        'custom_1');
    // No exact word match: keep the original ID rather than guess.
    expect(ExerciseCatalog.canonicalId('ex_bench_press', name: 'Bench Press'),
        'ex_bench_press');
  });

  test('every reviewed alias points at a catalog exercise', () {
    final ids = catalog.map((e) => e.id).toSet();
    expect(ExerciseCatalog.manualAliases, hasLength(23));
    for (final MapEntry(:key, :value)
        in ExerciseCatalog.manualAliases.entries) {
      expect(ids, contains(value), reason: key);
      expect(ExerciseCatalog.canonicalId(key), value);
    }
    // Approved review rows, including a merged pair.
    expect(ExerciseCatalog.canonicalId('ex_stationary_bike'),
        ExerciseCatalog.canonicalId('free_Bicycling_Stationary'));
  });

  test('records continue across an old ID and its catalog entry', () {
    final records = PRService.records([
      _log('free_Barbell_Bench_Press', null, 60, DateTime(2026, 2, 1)),
      _log('gg:pectorals/barbell-bench-press', 'Barbell Bench Press', 65,
          DateTime(2026, 11, 1)),
    ]);
    expect(records, hasLength(2));
    expect(records.first.isBaseline, isTrue);
    expect(records.last.isBaseline, isFalse);
    expect(records.last.previous!.weightKg, 60);
    expect(records.first.key, records.last.key);
  });
}
