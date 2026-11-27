import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exercise_model.dart';

/// The bundled exercise catalog (ExerciseGymGifsDB, pinned release; see
/// docs/EXERCISE_LIBRARY_MIGRATION.md) and the mapping from older exercise IDs
/// onto it. Saved workouts are never rewritten: records, progress and "last
/// time" values resolve both sides through [canonicalId] instead.
class ExerciseCatalog {
  static const asset = 'assets/exercises/catalog_v1.json';

  /// Everyday exercises the bundled catalog lacks (dead hang, sled push…),
  /// written by SweatMark. IDs start with `sm:`; there are no GIFs.
  static const staplesAsset = 'assets/exercises/sweatmark_staples.json';

  /// Everyday names shown instead of technical library names ("Face Pull"
  /// for "Cable Standing Rear Delt Row With Rope"), keyed by exercise ID.
  static const namesAsset = 'assets/exercises/everyday_names.json';

  // Library names replaced by everyday names, by ID; still searchable.
  static Map<String, String> _libraryNames = {};

  /// The original library name of a renamed exercise, or null.
  static String? libraryName(String id) => _libraryNames[id];

  /// Reviewed mappings for older IDs whose names do not match exactly.
  static const _manualAliases = {
    'ex_hip_adduction_machine': 'gg:adductors/lever-seated-hip-adduction',
    'ex_hip_abduction_machine': 'gg:abductors/lever-seated-hip-abduction',
    // Approved by the owner from docs/EXERCISE_ALIAS_REVIEW.md (Nov 1, 2026).
    'exercisedb_exr_41n2hRH4aTB379Tp': 'gg:spine/hyperextension',
    'exercisedb_exr_41n2hMRXm49mM62z': 'gg:delts/dumbbell-arnold-press',
    'free_Dips_-_Triceps_Version': 'gg:triceps/triceps-dip',
    'free_Dumbbell_Bench_Press_with_Neutral_Grip':
        'gg:triceps/dumbbell-neutral-grip-bench-press',
    'exercisedb_exr_41n2hjuGpcex14w7': 'gg:delts/dumbbell-lateral-raise',
    'ex_lateral_raise': 'gg:delts/dumbbell-lateral-raise',
    'free_Seated_Side_Lateral_Raise': 'gg:delts/dumbbell-seated-lateral-raise',
    'ex_single_arm_db_row': 'gg:upper-back/dumbbell-one-arm-bent-over-row',
    'exercisedb_exr_41n2hXYRxFHnQAD4': 'gg:cardio/stationary-bike-run-v-3',
    'exercisedb_exr_41n2hxnFMotsXTj3': 'gg:pectorals/barbell-bench-press',
    'free_Dumbbell_Shoulder_Press': 'gg:delts/dumbbell-seated-shoulder-press',
    'exercisedb_exr_41n2hs6camM22yBG':
        'gg:delts/dumbbell-seated-shoulder-press',
    'exercisedb_exr_41n2howQHvcrcrW6': 'gg:delts/dumbbell-front-raise',
    'ex_tricep_pushdown': 'gg:triceps/cable-pushdown',
    'ex_lat_pulldown': 'gg:lats/cable-lat-pulldown-full-range-of-motion',
    'free_Leg_Press': 'gg:glutes/sled-45-leg-press',
    'free_Jogging_Treadmill': 'gg:cardio/run',
    'ex_stationary_bike': 'gg:cardio/stationary-bike-walk',
    'free_Bicycling_Stationary': 'gg:cardio/stationary-bike-walk',
    'exercisedb_exr_41n2hupxPcdnktBC': 'gg:cardio/jack-jump-male',
    'ex_jumping_jacks': 'gg:cardio/jack-jump-male',
  };

  static Map<String, String> get manualAliases => _manualAliases;

  static List<Exercise>? _exercises;
  static Future<List<Exercise>>? _loading;
  static Map<String, String> _bySignature = {};

  static List<Exercise> get loaded => _exercises ?? const [];

  static Future<List<Exercise>> load({AssetBundle? bundle}) =>
      _loading ??= () async {
        final source = bundle ?? rootBundle;
        final everyday = Map<String, String>.from(
            (jsonDecode(await source.loadString(namesAsset))
                as Map<String, dynamic>)['names'] as Map);
        final libraryNames = <String, String>{};
        final exercises = <Exercise>[];
        for (final file in [asset, staplesAsset]) {
          final json =
              jsonDecode(await source.loadString(file)) as Map<String, dynamic>;
          for (final item in json['exercises'] as List) {
            final row = Map<String, dynamic>.from(item as Map);
            final name = everyday[row['id']];
            if (name != null) {
              libraryNames[row['id'] as String] = row['name'] as String;
              row['name'] = name;
            }
            exercises.add(Exercise.fromJson(row));
          }
        }
        _libraryNames = libraryNames;
        use(exercises);
        return exercises;
      }();

  /// Installs a catalog directly (startup after [load], and tests).
  static void use(List<Exercise> exercises) {
    _exercises = List.unmodifiable(exercises);
    final index = <String, String>{};
    for (final exercise in exercises) {
      index.putIfAbsent(signature(exercise.name), () => exercise.id);
      // Older workouts saved the library name; keep it resolving.
      final library = _libraryNames[exercise.id];
      if (library != null) {
        index.putIfAbsent(signature(library), () => exercise.id);
      }
    }
    _bySignature = index;
  }

  static void reset() {
    _exercises = null;
    _loading = null;
    _bySignature = {};
    _libraryNames = {};
  }

  /// Word-order-insensitive name key: "Upright Barbell Row" and "Barbell
  /// Upright Row" match; "Bench Press" and "Barbell Bench Press" do not.
  static String signature(String name) {
    final words = name
        .toLowerCase()
        .replaceAll('&', ' and ')
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty && word != 'male' && word != 'female')
        .toList()
      ..sort();
    return words.join(' ');
  }

  /// The ID that PRs, progress and history comparisons use. Custom exercises
  /// keep their own stable IDs even when their names match the catalog.
  static String canonicalId(String id, {String? name}) {
    if (id.startsWith('gg:') ||
        id.startsWith('sm:') ||
        id.startsWith('custom_')) {
      return id;
    }
    final manual = _manualAliases[id];
    if (manual != null) return manual;
    var key = name?.trim() ?? '';
    if (key.isEmpty && id.startsWith('free_')) key = id.substring(5);
    if (key.isEmpty) return id;
    return _bySignature[signature(key)] ?? id;
  }

  static bool sameExercise(String a, String b,
          {String? nameA, String? nameB}) =>
      a == b || canonicalId(a, name: nameA) == canonicalId(b, name: nameB);
}
