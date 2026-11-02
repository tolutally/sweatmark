import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exercise_model.dart';

/// The bundled exercise catalog (ExerciseGymGifsDB, pinned release; see
/// docs/EXERCISE_LIBRARY_MIGRATION.md) and the mapping from older exercise IDs
/// onto it. Saved workouts are never rewritten: records, progress and "last
/// time" values resolve both sides through [canonicalId] instead.
class ExerciseCatalog {
  static const asset = 'assets/exercises/catalog_v1.json';

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
        final raw = await (bundle ?? rootBundle).loadString(asset);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final exercises = (json['exercises'] as List)
            .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
            .toList();
        use(exercises);
        return exercises;
      }();

  /// Installs a catalog directly (startup after [load], and tests).
  static void use(List<Exercise> exercises) {
    _exercises = List.unmodifiable(exercises);
    final index = <String, String>{};
    for (final exercise in exercises) {
      index.putIfAbsent(signature(exercise.name), () => exercise.id);
    }
    _bySignature = index;
  }

  static void reset() {
    _exercises = null;
    _loading = null;
    _bySignature = {};
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
    if (id.startsWith('gg:') || id.startsWith('custom_')) return id;
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
