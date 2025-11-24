enum MuscleStatus { recovered, recovering, fatigued }

class WorkoutSet {
  int? weight;
  int? reps;
  bool isCompleted;

  WorkoutSet({this.weight, this.reps, this.isCompleted = false});

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'reps': reps,
        'isCompleted': isCompleted,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      weight: json['weight'],
      reps: json['reps'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

class WorkoutExerciseLog {
  final String exerciseId;
  final List<WorkoutSet> sets;

  WorkoutExerciseLog({required this.exerciseId, required this.sets});

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory WorkoutExerciseLog.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseLog(
      exerciseId: json['exerciseId'],
      sets: (json['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
    );
  }
}

class WorkoutLog {
  final String id;
  final DateTime timestamp;
  final int durationSeconds;
  final List<WorkoutExerciseLog> exercises;
  final bool isTestData;

  WorkoutLog({
    required this.id,
    required this.timestamp,
    required this.durationSeconds,
    required this.exercises,
    this.isTestData = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'isTestData': isTestData,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      durationSeconds: json['durationSeconds'],
      exercises: (json['exercises'] as List)
          .map((e) => WorkoutExerciseLog.fromJson(e))
          .toList(),
      isTestData: json['isTestData'] ?? false,
    );
  }
}
