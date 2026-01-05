enum MuscleStatus { recovered, recovering, fatigued }

class WorkoutSet {
  double? weight;
  int? reps;
  int? durationSeconds;  // For timed exercises (plank, cardio)
  double? distance;      // For cardio exercises (miles or km)
  double? speed;         // Speed in mph or km/h
  double? incline;       // Incline percentage
  int? resistance;       // Resistance level (1-20 typically)
  bool isCompleted;
  final bool isSuperSetRest;

  WorkoutSet({
    this.weight,
    this.reps,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
    this.resistance,
    this.isCompleted = false,
    this.isSuperSetRest = false,
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'distance': distance,
        'speed': speed,
        'incline': incline,
        'resistance': resistance,
        'isCompleted': isCompleted,
        'isSuperSetRest': isSuperSetRest,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: (json['weight'] as num?)?.toDouble(),
      reps: json['reps'],
      durationSeconds: json['durationSeconds'],
      distance: (json['distance'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      incline: (json['incline'] as num?)?.toDouble(),
      resistance: json['resistance'],
      isCompleted: json['isCompleted'] ?? false,
      isSuperSetRest: json['isSuperSetRest'] ?? false,
    );
  }

  WorkoutSet copyWith({
    double? weight,
    int? reps,
    int? durationSeconds,
    double? distance,
    double? speed,
    double? incline,
    int? resistance,
    bool? isCompleted,
    bool? isSuperSetRest,
  }) {
    return WorkoutSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distance: distance ?? this.distance,
      speed: speed ?? this.speed,
      incline: incline ?? this.incline,
      resistance: resistance ?? this.resistance,
      isCompleted: isCompleted ?? this.isCompleted,
      isSuperSetRest: isSuperSetRest ?? this.isSuperSetRest,
    );
  }
}

class WorkoutExerciseLog {
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
    this.exerciseName,
    this.muscleGroup,
    this.equipment,
    this.gifUrl,
    required this.sets,
    this.superSetId,
    this.orderInSuperSet,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
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
