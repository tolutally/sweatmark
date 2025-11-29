enum MuscleStatus { recovered, recovering, fatigued }

class WorkoutSet {
  int? weight;
  int? reps;
  bool isCompleted;
  final bool isSuperSetRest;

  WorkoutSet({
    this.weight, 
    this.reps, 
    this.isCompleted = false, 
    this.isSuperSetRest = false
  });

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
        'isSuperSetRest': isSuperSetRest,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: json['weight'],
      reps: json['reps'],
      isCompleted: json['isCompleted'] ?? false,
      isSuperSetRest: json['isSuperSetRest'] ?? false,
    );
  }
}

class WorkoutExerciseLog {
  final String exerciseId;
  final List<WorkoutSet> sets;
  final String? superSetId;
  final int? orderInSuperSet;

  WorkoutExerciseLog({
    required this.exerciseId, 
    required this.sets,
    this.superSetId,
    this.orderInSuperSet,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
        'superSetId': superSetId,
        'orderInSuperSet': orderInSuperSet,
      };

  factory WorkoutExerciseLog.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseLog(
      exerciseId: json['exerciseId'],
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
    this.superSets = const [],
    this.notes,
    this.isTestData = false,
  });

  // Keep backward compatibility 
  String get id => workoutName;

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
