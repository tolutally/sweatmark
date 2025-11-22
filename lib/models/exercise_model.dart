class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String icon;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.icon,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: json['muscleGroup'],
      equipment: json['equipment'],
      icon: json['icon'],
    );
  }
}
