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
  int? durationSeconds; // For timed exercises (plank, cardio)
  String? distanceUnit;
  double? distance; // For cardio exercises (miles or km)
  double? speed; // Speed in mph or km/h
  double? incline; // Incline percentage
  int? resistance; // Resistance level (1-20 typically)
  bool isCompleted;
  final bool isSuperSetRest;

  WorkoutSet({
    this.weight,
    this.weightUnit,
    this.reps,
    this.durationSeconds,
    this.distance,
    this.distanceUnit,
    this.speed,
    this.incline,
    this.resistance,
    this.isCompleted = false,
    this.isSuperSetRest = false,
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'weightUnit': weightUnit,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'distance': distance,
        'distanceUnit': distanceUnit,
        'speed': speed,
        'incline': incline,
        'resistance': resistance,
        'isCompleted': isCompleted,
        'isSuperSetRest': isSuperSetRest,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: (json['weight'] as num?)?.toDouble(),
      weightUnit:
          ['kg', 'lb'].contains(json['weightUnit']) ? json['weightUnit'] : null,
      reps: json['reps'],
      durationSeconds: json['durationSeconds'],
      distance: (json['distance'] as num?)?.toDouble(),
      distanceUnit: ['km', 'mi'].contains(json['distanceUnit'])
          ? json['distanceUnit']
          : null,
      speed: (json['speed'] as num?)?.toDouble(),
      incline: (json['incline'] as num?)?.toDouble(),
      resistance: json['resistance'],
      isCompleted: json['isCompleted'] ?? false,
      isSuperSetRest: json['isSuperSetRest'] ?? false,
    );
  }

  WorkoutSet copyWith({
    double? weight,
    String? weightUnit,
    int? reps,
    int? durationSeconds,
    double? distance,
    String? distanceUnit,
    double? speed,
    double? incline,
    int? resistance,
    bool? isCompleted,
    bool? isSuperSetRest,
  }) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      speed: speed ?? this.speed,
      incline: incline ?? this.incline,
      resistance: resistance ?? this.resistance,
      isCompleted: isCompleted ?? this.isCompleted,
      isSuperSetRest: isSuperSetRest ?? this.isSuperSetRest,
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
  });

  String get displayName =>
      exerciseDisplayName(exerciseId, saved: exerciseName);

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
