/// User preference settings for units and display
class UserSettings {
  final DistanceUnit distanceUnit;
  final WeightUnit weightUnit;

  const UserSettings({
    this.distanceUnit = DistanceUnit.miles,
    this.weightUnit = WeightUnit.lb,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      distanceUnit: DistanceUnit.values.firstWhere(
        (e) => e.name == json['distanceUnit'],
        orElse: () => DistanceUnit.miles,
      ),
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == json['weightUnit'],
        orElse: () => WeightUnit.lb,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'distanceUnit': distanceUnit.name,
        'weightUnit': weightUnit.name,
      };

  UserSettings copyWith({
    DistanceUnit? distanceUnit,
    WeightUnit? weightUnit,
  }) {
    return UserSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      weightUnit: weightUnit ?? this.weightUnit,
    );
  }

  /// Format distance with unit suffix
  String formatDistance(double? distance) {
    if (distance == null) return '--';
    final suffix = distanceUnit == DistanceUnit.miles ? 'mi' : 'km';
    return '${distance.toStringAsFixed(2)} $suffix';
  }

  /// Format weight with unit suffix
  String formatWeight(double? weight) {
    if (weight == null) return '--';
    final suffix = weightUnit == WeightUnit.lb ? 'lb' : 'kg';
    return '${weight.toStringAsFixed(1)} $suffix';
  }

  /// Format pace as min:sec per unit (e.g., "8:30/mi")
  String formatPace(int? durationSeconds, double? distance) {
    if (durationSeconds == null || distance == null || distance == 0) {
      return '--';
    }
    
    // Calculate pace in seconds per unit
    final paceSeconds = durationSeconds / distance;
    final minutes = (paceSeconds / 60).floor();
    final seconds = (paceSeconds % 60).round();
    
    final suffix = distanceUnit == DistanceUnit.miles ? '/mi' : '/km';
    return '$minutes:${seconds.toString().padLeft(2, '0')}$suffix';
  }

  /// Format duration as mm:ss or h:mm:ss
  static String formatDuration(int? seconds) {
    if (seconds == null) return '--';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Parse duration string (mm:ss or h:mm:ss) to seconds
  static int? parseDuration(String input) {
    final parts = input.split(':').map((p) => int.tryParse(p)).toList();
    
    if (parts.any((p) => p == null)) return null;
    
    if (parts.length == 2) {
      // mm:ss
      return parts[0]! * 60 + parts[1]!;
    } else if (parts.length == 3) {
      // h:mm:ss
      return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    }
    
    return null;
  }
}

enum DistanceUnit {
  miles,
  kilometers,
}

enum WeightUnit {
  lb,
  kg,
}
