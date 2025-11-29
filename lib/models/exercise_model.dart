class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String icon;
  final String? instructions;
  final String? videoUrl;
  final String? difficulty;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.icon = '💪',
    this.instructions,
    this.videoUrl,
    this.difficulty,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: json['muscleGroup'],
      equipment: json['equipment'],
      icon: json['icon'] ?? '💪',
      instructions: json['instructions'],
      videoUrl: json['videoUrl'],
      difficulty: json['difficulty'],
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
    };
  }
}
