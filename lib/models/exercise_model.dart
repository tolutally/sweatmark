/// Individual field types that can be tracked during a workout set
enum SetFieldType {
  weight,
  reps,
  time,
  distance,
  speed,
  incline,
  resistance,
}

extension SetFieldTypeExtension on SetFieldType {
  String get displayName {
    switch (this) {
      case SetFieldType.weight:
        return 'Weight';
      case SetFieldType.reps:
        return 'Reps';
      case SetFieldType.time:
        return 'Time';
      case SetFieldType.distance:
        return 'Distance';
      case SetFieldType.speed:
        return 'Speed';
      case SetFieldType.incline:
        return 'Incline';
      case SetFieldType.resistance:
        return 'Resistance';
    }
  }

  String get icon {
    switch (this) {
      case SetFieldType.weight:
        return '🏋️';
      case SetFieldType.reps:
        return '🔄';
      case SetFieldType.time:
        return '⏱️';
      case SetFieldType.distance:
        return '📏';
      case SetFieldType.speed:
        return '⚡';
      case SetFieldType.incline:
        return '📐';
      case SetFieldType.resistance:
        return '🎚️';
    }
  }

  String getSuffix(bool isMetric) {
    switch (this) {
      case SetFieldType.weight:
        return isMetric ? 'kg' : 'lb';
      case SetFieldType.reps:
        return '';
      case SetFieldType.time:
        return '';
      case SetFieldType.distance:
        return isMetric ? 'km' : 'mi';
      case SetFieldType.speed:
        return isMetric ? 'km/h' : 'mph';
      case SetFieldType.incline:
        return '%';
      case SetFieldType.resistance:
        return 'lvl';
    }
  }
}

/// Exercise type determines what input fields to show during workout tracking
enum ExerciseType {
  /// Weight + Reps (barbell, dumbbell, cable, machine, kettlebell)
  weightedStrength,
  
  /// Reps only with optional +weight toggle (push-ups, pull-ups, dips)
  bodyweightReps,
  
  /// Duration only in mm:ss (plank, wall sit, dead hang)
  timedHold,
  
  /// Time + Distance with auto-calculated pace (treadmill, bike, rowing)
  cardio,
}

extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.weightedStrength:
        return 'Weighted';
      case ExerciseType.bodyweightReps:
        return 'Bodyweight';
      case ExerciseType.timedHold:
        return 'Timed';
      case ExerciseType.cardio:
        return 'Cardio';
    }
  }

  String get icon {
    switch (this) {
      case ExerciseType.weightedStrength:
        return '🏋️';
      case ExerciseType.bodyweightReps:
        return '💪';
      case ExerciseType.timedHold:
        return '⏱️';
      case ExerciseType.cardio:
        return '🏃';
    }
  }

  /// Default fields for this exercise type
  List<SetFieldType> get defaultFields {
    switch (this) {
      case ExerciseType.weightedStrength:
        return [SetFieldType.weight, SetFieldType.reps];
      case ExerciseType.bodyweightReps:
        return [SetFieldType.reps];
      case ExerciseType.timedHold:
        return [SetFieldType.time];
      case ExerciseType.cardio:
        return [SetFieldType.time, SetFieldType.distance];
    }
  }
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String icon;
  final String? instructions;
  final String? videoUrl;
  final String? difficulty;
  
  // ExerciseDB integration fields
  final String? gifUrl;       // ExerciseDB animated GIF URL
  final String? externalId;   // ExerciseDB ID for deduplication
  final String source;        // 'local' | 'exercisedb' | 'custom'
  final List<String>? secondaryMuscles; // Additional muscles targeted
  
  // Exercise type for determining input fields
  final ExerciseType exerciseType;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.icon = '💪',
    this.instructions,
    this.videoUrl,
    this.difficulty,
    // ExerciseDB fields with backward-compatible defaults
    this.gifUrl,
    this.externalId,
    this.source = 'local',
    this.secondaryMuscles,
    this.exerciseType = ExerciseType.weightedStrength,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      muscleGroup: json['muscleGroup'] ?? json['category'] ?? '',
      equipment: json['equipment'] ?? '',
      icon: json['icon'] ?? '💪',
      instructions: json['instructions'] ?? json['description'],
      videoUrl: json['videoUrl'],
      difficulty: json['difficulty'],
      // ExerciseDB fields
      gifUrl: json['gifUrl'],
      externalId: json['externalId'],
      source: json['source'] ?? 'local',
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      exerciseType: ExerciseType.values.firstWhere(
        (e) => e.name == json['exerciseType'],
        orElse: () => ExerciseType.weightedStrength,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'icon': icon,
      'instructions': instructions,
      'videoUrl': videoUrl,
      'difficulty': difficulty,
      // ExerciseDB fields
      'gifUrl': gifUrl,
      'externalId': externalId,
      'source': source,
      'secondaryMuscles': secondaryMuscles,
      'exerciseType': exerciseType.name,
    };
  }

  /// Create a copy with modified fields
  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? icon,
    String? instructions,
    String? videoUrl,
    String? difficulty,
    String? gifUrl,
    String? externalId,
    String? source,
    List<String>? secondaryMuscles,
    ExerciseType? exerciseType,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      icon: icon ?? this.icon,
      instructions: instructions ?? this.instructions,
      videoUrl: videoUrl ?? this.videoUrl,
      difficulty: difficulty ?? this.difficulty,
      gifUrl: gifUrl ?? this.gifUrl,
      externalId: externalId ?? this.externalId,
      source: source ?? this.source,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      exerciseType: exerciseType ?? this.exerciseType,
    );
  }

  /// Check if this exercise is from ExerciseDB
  bool get isFromExerciseDb => source == 'exercisedb';

  /// Check if this exercise has a GIF
  bool get hasGif => gifUrl != null && gifUrl!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
