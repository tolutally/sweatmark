import 'each_side.dart';

enum MuscleStatus { recovered, recovering, fatigued }

class WorkoutSet {
  double? weight;
  String? weightUnit;
  double? get weightKg => weight == null || weightUnit == null
      ? null
      : weightUnit == 'kg'
          ? weight
          : weight! / 2.2046226218;
  String get weightLabel => weight == null
      ? '—'
      : '${weight!.toStringAsFixed(1)} ${weightUnit ?? "unit unknown"}';
  int? reps;
  // The right side of an "each side" set; [weight] and [reps] are then the
  // left side. Null means the right side matched the left. [weightUnit]
  // applies to both.
  double? weightRight;
  int? repsRight;
  double? get weightRightKg => weightRight == null || weightUnit == null
      ? null
      : weightUnit == 'kg'
          ? weightRight
          : weightRight! / 2.2046226218;
  int? durationSeconds; // For timed exercises (plank, cardio)
  String? distanceUnit;
  double? distance; // For cardio exercises (miles or km)
  double? speed; // Speed in mph or km/h
  double? incline; // Incline percentage
  int? resistance; // Resistance level (1-20 typically)
  int? calories; // Active calories a cardio machine reported
  bool isCompleted;
  final bool isSuperSetRest;
  // Marked by the person (tap the set number); never guessed from weight.
  bool isWarmup;

  WorkoutSet({
    this.weight,
    this.weightUnit,
    this.reps,
    this.weightRight,
    this.repsRight,
    this.durationSeconds,
    this.distance,
    this.distanceUnit,
    this.speed,
    this.incline,
    this.resistance,
    this.calories,
    this.isCompleted = false,
    this.isSuperSetRest = false,
    this.isWarmup = false,
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'weightUnit': weightUnit,
        'reps': reps,
        if (weightRight != null) 'weightRight': weightRight,
        if (repsRight != null) 'repsRight': repsRight,
        'durationSeconds': durationSeconds,
        'distance': distance,
        'distanceUnit': distanceUnit,
        'speed': speed,
        'incline': incline,
        'resistance': resistance,
        'calories': calories,
        'isCompleted': isCompleted,
        'isSuperSetRest': isSuperSetRest,
        if (isWarmup) 'isWarmup': true,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit:
          ['kg', 'lb'].contains(json['weightUnit']) ? json['weightUnit'] : null,
      reps: json['reps'],
      weightRight: (json['weightRight'] as num?)?.toDouble(),
      repsRight: (json['repsRight'] as num?)?.toInt(),
      durationSeconds: json['durationSeconds'],
      distance: (json['distance'] as num?)?.toDouble(),
      distanceUnit: ['km', 'mi'].contains(json['distanceUnit'])
          ? json['distanceUnit']
          : null,
      speed: (json['speed'] as num?)?.toDouble(),
      incline: (json['incline'] as num?)?.toDouble(),
      resistance: json['resistance'],
      calories: (json['calories'] as num?)?.round(),
      isCompleted: json['isCompleted'] ?? false,
      isSuperSetRest: json['isSuperSetRest'] ?? false,
      isWarmup: json['isWarmup'] == true,
    );
  }

  WorkoutSet copyWith({
    double? weight,
    String? weightUnit,
    int? reps,
    double? weightRight,
    int? repsRight,
    bool clearRight = false,
    int? durationSeconds,
    double? distance,
    String? distanceUnit,
    double? speed,
    double? incline,
    int? resistance,
    int? calories,
    bool? isCompleted,
    bool? isSuperSetRest,
    bool? isWarmup,
  }) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      reps: reps ?? this.reps,
      weightRight: clearRight ? null : weightRight ?? this.weightRight,
      repsRight: clearRight ? null : repsRight ?? this.repsRight,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      speed: speed ?? this.speed,
      incline: incline ?? this.incline,
      resistance: resistance ?? this.resistance,
      calories: calories ?? this.calories,
      isCompleted: isCompleted ?? this.isCompleted,
      isSuperSetRest: isSuperSetRest ?? this.isSuperSetRest,
      isWarmup: isWarmup ?? this.isWarmup,
    );
  }
}

/// Readable exercise name for history, stats and sharing. Some older logs kept
/// only an ID such as `free_Upright_Barbell_Row`; never show raw IDs.
String exerciseDisplayName(String id,
    {String? saved, Map<String, String> catalog = const {}}) {
  final name = saved?.trim();
  if (name != null && name.isNotEmpty && name != id) return name;
  final known = catalog[id]?.trim();
  if (known != null && known.isNotEmpty && known != id) return known;
  // free-exercise-db IDs encode the name with underscores.
  if (id.startsWith('free_') && id.length > 5) {
    return id.substring(5).replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ');
  }
  return 'Saved exercise';
}

class WorkoutExerciseLog {
  final int? averageHeartRate;
  final String? intensity;
  final String? exerciseType;
  final String exerciseId;
  final String? exerciseName;
  final String? muscleGroup;
  final String? equipment;
  final String? gifUrl;
  final List<WorkoutSet> sets;
  final String? superSetId;
  final int? orderInSuperSet;

  /// The weight and reps typed are for one side (one arm, one leg or one
  /// dumbbell) and the other side did the same, so work counts twice.
  bool eachSide;

  /// Marked one-sided when created (custom exercises), so "each side" is
  /// offered whatever its name.
  final bool oneSided;

  /// Whether [eachSide] was chosen when this was logged; older logs predate
  /// the setting, so they say nothing about it.
  final bool sideSaved;

  WorkoutExerciseLog({
    required this.exerciseId,
    this.exerciseType,
    this.averageHeartRate,
    this.intensity,
    this.exerciseName,
    this.muscleGroup,
    this.equipment,
    this.gifUrl,
    required this.sets,
    this.superSetId,
    this.orderInSuperSet,
    this.eachSide = false,
    this.oneSided = false,
    this.sideSaved = true,
  });

  String get displayName =>
      exerciseDisplayName(exerciseId, saved: exerciseName);

  /// Whether "each side" is offered: one-sided by name, or marked so when
  /// a custom exercise was created.
  bool get canEachSide =>
      oneSided || EachSide.isOneSided(displayName, type: exerciseType);

  /// Each side of a set as kg and reps: one entry for a whole set, left
  /// then right for "each side" (the right matching the left unless logged).
  List<({double? kg, int reps})> sides(WorkoutSet set) {
    final left = (kg: set.weightKg, reps: set.reps ?? 0);
    if (!eachSide) return [left];
    return [
      left,
      (kg: set.weightRightKg ?? left.kg, reps: set.repsRight ?? left.reps),
    ];
  }

  /// Reps across both sides.
  int totalReps(WorkoutSet set) =>
      sides(set).fold(0, (sum, side) => sum + side.reps);

  /// Weight × reps across both sides, in kg; null without a known weight.
  double? volumeKg(WorkoutSet set) {
    var total = 0.0;
    var known = false;
    for (final side in sides(set)) {
      if (side.kg == null || side.reps <= 0) continue;
      total += side.kg! * side.reps;
      known = true;
    }
    return known ? total : null;
  }

  /// Whether the right side differs from the left.
  bool sidesDiffer(WorkoutSet set) {
    if (!eachSide) return false;
    final s = sides(set);
    return s[0].kg != s[1].kg || s[0].reps != s[1].reps;
  }

  /// The side that counts toward a record: the weaker one when they differ.
  ({double? kg, int reps}) recordSide(WorkoutSet set) {
    final s = sides(set);
    if (s.length == 1) return s.first;
    final l = s[0], r = s[1];
    final lk = l.kg ?? 0, rk = r.kg ?? 0;
    if ((lk - rk).abs() > 0.00001) return lk < rk ? l : r;
    return l.reps <= r.reps ? l : r;
  }

  /// A set as logged, with [weight] formatting one side's weight (in the
  /// set's own unit): "20 kg × 10", "20 kg × 10 each side" or
  /// "L 20 kg × 10 / R 15 kg × 8".
  String setText(WorkoutSet set, String Function(double weight) weight) {
    String one(double? w, int reps) =>
        w != null && w > 0 ? '${weight(w)} × $reps' : '$reps reps';
    final reps = set.reps ?? 0;
    if (!eachSide) return one(set.weight, reps);
    if (!sidesDiffer(set)) return '${one(set.weight, reps)} each side';
    return 'L ${one(set.weight, reps)} / '
        'R ${one(set.weightRight ?? set.weight, set.repsRight ?? reps)}';
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseType': exerciseType,
        'averageHeartRate': averageHeartRate,
        'intensity': intensity,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'equipment': equipment,
        'gifUrl': gifUrl,
        'sets': sets.map((s) => s.toJson()).toList(),
        'superSetId': superSetId,
        'orderInSuperSet': orderInSuperSet,
        if (sideSaved) 'eachSide': eachSide,
        if (oneSided) 'oneSided': true,
      };

  factory WorkoutExerciseLog.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseLog(
      exerciseId: json['exerciseId'],
      exerciseType: json['exerciseType'],
      averageHeartRate: (json['averageHeartRate'] as num?)?.toInt(),
      intensity: ['Low', 'Moderate', 'High'].contains(json['intensity'])
          ? json['intensity']
          : null,
      exerciseName: json['exerciseName'],
      muscleGroup: json['muscleGroup'],
      equipment: json['equipment'],
      gifUrl: json['gifUrl'],
      sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
      superSetId: json['superSetId'],
      orderInSuperSet: json['orderInSuperSet'],
      eachSide: json['eachSide'] == true,
      oneSided: json['oneSided'] == true,
      sideSaved: json.containsKey('eachSide'),
    );
  }
}

class SuperSet {
  final String id;
  final List<String> exerciseIds;
  final int currentExerciseIndex;
  final int currentRound;
  final int totalRounds;
  final bool isCompleted;

  SuperSet({
    required this.id,
    required this.exerciseIds,
    this.currentExerciseIndex = 0,
    this.currentRound = 1,
    this.totalRounds = 1,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseIds': exerciseIds,
        'currentExerciseIndex': currentExerciseIndex,
        'currentRound': currentRound,
        'totalRounds': totalRounds,
        'isCompleted': isCompleted,
      };

  factory SuperSet.fromJson(Map<String, dynamic> json) {
    return SuperSet(
      id: json['id'],
      exerciseIds: List<String>.from(json['exerciseIds']),
      currentExerciseIndex: json['currentExerciseIndex'] ?? 0,
      currentRound: json['currentRound'] ?? 1,
      totalRounds: json['totalRounds'] ?? 1,
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  SuperSet copyWith({
    String? id,
    List<String>? exerciseIds,
    int? currentExerciseIndex,
    int? currentRound,
    int? totalRounds,
    bool? isCompleted,
  }) {
    return SuperSet(
      id: id ?? this.id,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class WorkoutLog {
  final String workoutName; // Changed from id to workoutName
  final DateTime timestamp;
  final int durationSeconds;
  final List<WorkoutExerciseLog> exercises;
  final List<SuperSet> superSets;
  final String? notes; // Added notes field
  final bool isTestData;

  WorkoutLog({
    required this.workoutName,
    required this.timestamp,
    required this.durationSeconds,
    required this.exercises,
    List<SuperSet>? superSets,
    this.notes,
    this.isTestData = false,
  }) : superSets = superSets ?? [];

  // Keep backward compatibility
  String get id => timestamp.millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'workoutName': workoutName,
        'id': workoutName, // Keep for backward compatibility
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'superSets': superSets.map((s) => s.toJson()).toList(),
        'notes': notes,
        'isTestData': isTestData,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      workoutName: json['workoutName'] ?? json['id'] ?? 'Workout',
      timestamp: DateTime.parse(json['timestamp']),
      durationSeconds: json['durationSeconds'],
      exercises: (json['exercises'] as List)
          .map((e) => WorkoutExerciseLog.fromJson(e))
          .toList(),
      superSets: (json['superSets'] as List? ?? [])
          .map((s) => SuperSet.fromJson(s))
          .toList(),
      notes: json['notes'],
      isTestData: json['isTestData'] ?? false,
    );
  }
}
