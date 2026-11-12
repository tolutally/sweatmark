import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/data/exercise_catalog.dart';
import 'package:sweatmark/services/exercise_search.dart';
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
    final bundled = catalog.where((e) => e.id.startsWith('gg:')).toList();
    final staples = catalog.where((e) => e.id.startsWith('sm:')).toList();
    expect(bundled, hasLength(1323));
    expect(staples, hasLength(17));
    expect(catalog, hasLength(bundled.length + staples.length));
    expect(catalog.map((e) => e.id).toSet(), hasLength(catalog.length));
    expect(bundled.every((e) => e.gifUrl!.contains('@v1.1.0/')), isTrue);
    expect(catalog.every((e) => e.muscleGroup.isNotEmpty), isTrue);
    // Staples fill gaps; none repeats a bundled exercise's name.
    final names = {for (final e in bundled) e.name.toLowerCase()};
    expect(staples.where((e) => names.contains(e.name.toLowerCase())), isEmpty);
    expect(staples.every((e) => (e.instructions ?? '').isNotEmpty), isTrue);
    expect(staples.map((e) => e.name),
        containsAll(['Dead Hang', 'Active Hang', 'Sled Push', 'Wall Sit']));
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
      for (final exercise in catalog.where((e) => e.id.startsWith('gg:')))
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

  test('exercises show everyday names; library names still work', () {
    String name(String id) => catalog.singleWhere((e) => e.id == id).name;
    expect(
        name('gg:delts/cable-standing-rear-delt-row-with-rope'), 'Face Pull');
    expect(name('gg:pectorals/lever-seated-fly'), 'Pec Deck');
    expect(name('gg:triceps/barbell-lying-triceps-extension-skull-crusher'),
        'Skull Crusher');
    expect(name('gg:glutes/sled-45-leg-press'), 'Leg Press');
    // Calisthenics levers are not machines.
    expect(
        catalog.map((e) => e.name), containsAll(['Front Lever', 'Back Lever']));
    // Library jargon is gone from what people see.
    for (final e in catalog) {
      expect(
          RegExp(r'^Lever |\bMale\b|\bFemale\b|\bPov\b| v\d\b|\b\d{4}\b')
              .hasMatch(e.name),
          isFalse,
          reason: e.name);
    }
    expect(catalog.map((e) => e.name).toSet(), hasLength(catalog.length),
        reason: 'every name is unique');
    expect(
        ExerciseCatalog.libraryName(
            'gg:delts/cable-standing-rear-delt-row-with-rope'),
        'Cable Standing Rear Delt Row With Rope');
    // Workouts saved with the old name still map to the same exercise.
    expect(
        ExerciseCatalog.canonicalId('exercisedb_x',
            name: 'Barbell Lying Triceps Extension Skull Crusher'),
        'gg:triceps/barbell-lying-triceps-extension-skull-crusher');
    expect(ExerciseCatalog.canonicalId('sm:dead-hang'), 'sm:dead-hang');
  });

  test('search finds renamed exercises by either name', () {
    List<String> top(String q) =>
        ExerciseSearch.search(catalog, q).take(3).map((e) => e.name).toList();
    expect(top('face pull').first, 'Face Pull');
    expect(top('cable standing rear delt row'), contains('Face Pull'));
    expect(top('lever seated fly'), contains('Pec Deck'));
    expect(top('pec deck').first, 'Pec Deck');
    expect(top('reverse pec deck').first, 'Reverse Pec Deck');
    expect(top('machine fly'), contains('Pec Deck'));
    expect(top('suitcase deadlift').first, 'Barbell Suitcase Deadlift');
    expect(top('side plank'), contains('Side Plank'));
    expect(top('skull crusher').first, 'Skull Crusher');
    expect(top('leg press').first, 'Leg Press');
    expect(top('lat pulldown').first, 'Lat Pulldown');
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
