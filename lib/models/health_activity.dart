/// One workout read from Apple Health that another app or device recorded.
class HealthActivity {
  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
  final String sourceName;

  /// Null when Health has no distance for this workout.
  final double? distanceMeters;

  const HealthActivity({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.sourceName,
    this.distanceMeters,
  });

  int get seconds => end.isAfter(start) ? end.difference(start).inSeconds : 0;
}

/// Movement from Apple Health for one period, kept apart from logged lifts.
class HealthSummary {
  final List<HealthActivity> activities;

  /// Null when steps could not be read (no permission or no data).
  final int? steps;

  HealthSummary(List<HealthActivity> activities, {this.steps})
      : activities = [...activities]
          ..sort((a, b) => b.start.compareTo(a.start));

  int get totalSeconds => activities.fold(0, (sum, a) => sum + a.seconds);

  double get distanceKm =>
      activities.fold(0.0, (sum, a) => sum + (a.distanceMeters ?? 0)) / 1000;

  bool get isEmpty => activities.isEmpty && (steps ?? 0) == 0;

  /// Readable name for a Health workout type such as `RUNNING` or
  /// `HIGH_INTENSITY_INTERVAL_TRAINING`.
  static String labelFor(String type) {
    const names = {
      'RUNNING': 'Run',
      'RUNNING_TREADMILL': 'Treadmill run',
      'WALKING': 'Walk',
      'BIKING': 'Ride',
      'BIKING_STATIONARY': 'Indoor ride',
      'HIKING': 'Hike',
      'SWIMMING': 'Swim',
      'ROWING': 'Row',
      'ELLIPTICAL': 'Elliptical',
      'STAIR_CLIMBING': 'Stair climb',
      'HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
      'YOGA': 'Yoga',
      'DANCING': 'Dance',
      'TRADITIONAL_STRENGTH_TRAINING': 'Strength',
      'FUNCTIONAL_STRENGTH_TRAINING': 'Functional strength',
      'CROSS_TRAINING': 'Cross training',
    };
    final known = names[type];
    if (known != null) return known;
    final words = type.toLowerCase().split('_').where((w) => w.isNotEmpty);
    if (words.isEmpty) return 'Workout';
    final text = words.join(' ');
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// Distance in meters from a Health value and unit name, or null if the
  /// unit is unknown.
  static double? meters(num? value, String? unit) {
    if (value == null || value <= 0 || !value.isFinite) return null;
    switch (unit) {
      case 'METER':
        return value.toDouble();
      case 'KILOMETER':
        return value * 1000.0;
      case 'MILE':
        return value * 1609.344;
      case 'YARD':
        return value * .9144;
      case 'FOOT':
        return value * .3048;
      default:
        return null;
    }
  }
}
