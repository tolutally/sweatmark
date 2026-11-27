import 'workout_model.dart';

/// The time span of one workout another app or device, such as an Apple
/// Watch, saved to Apple Health. It is never shown as its own entry: it only
/// replaces a logged workout's time when both fall on the same day.
class HealthActivity {
  final String id;
  final DateTime start;
  final DateTime end;
  final String sourceName;

  const HealthActivity({
    required this.id,
    required this.start,
    required this.end,
    required this.sourceName,
  });

  int get seconds => end.isAfter(start) ? end.difference(start).inSeconds : 0;
}

/// Movement from Apple Health for one period, kept apart from logged lifts.
class HealthSummary {
  /// Null when Health had no value or could not be read.
  final int? steps;
  final double? distanceMeters;
  final double? activeKcal;

  /// Days in the period with any steps, distance or active energy. Null
  /// when Health could not say, in which case averages use every day.
  final int? daysWithData;

  /// Workouts from other apps and devices, used only for [watchTimes].
  final List<HealthActivity> sessions;

  HealthSummary(
      {this.steps,
      this.distanceMeters,
      this.activeKcal,
      this.daysWithData,
      List<HealthActivity> sessions = const []})
      : sessions = [...sessions]..sort((a, b) => a.start.compareTo(b.start));

  double get distanceKm => (distanceMeters ?? 0) / 1000;

  /// Daily average of [total] over the days that have data, or over
  /// [periodDays] when that isn't known. Null with no total.
  double? perDay(num? total, int periodDays) {
    if (total == null || total <= 0) return null;
    final known = daysWithData;
    final days =
        known != null && known > 0 && known < periodDays ? known : periodDays;
    return days > 0 ? total / days : null;
  }

  bool get isEmpty =>
      (steps ?? 0) == 0 && (distanceMeters ?? 0) <= 0 && (activeKcal ?? 0) <= 0;

  /// For each logged workout that shares a day with a Health workout, the
  /// Health workout whose time should be used instead of the in-app timer.
  ///
  /// On a day with several of either, the Health workout that overlaps a
  /// logged one most wins, then the one starting closest to it. Each Health
  /// workout replaces at most one logged workout.
  Map<String, HealthActivity> watchTimes(Iterable<WorkoutLog> logged) {
    final result = <String, HealthActivity>{};
    if (sessions.isEmpty) return result;
    final used = <String>{};
    final workouts = logged.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final workout in workouts) {
      final start = workout.timestamp.toLocal();
      final end = start.add(Duration(
          seconds: workout.durationSeconds > 0 ? workout.durationSeconds : 0));
      HealthActivity? best;
      var bestOverlap = -1;
      var bestGap = 0;
      for (final session in sessions) {
        if (used.contains(session.id) || session.seconds <= 0) continue;
        final from = session.start.toLocal();
        if (!_sameDay(from, start)) continue;
        final to = session.end.toLocal();
        final overlapStart = from.isAfter(start) ? from : start;
        final overlapEnd = to.isBefore(end) ? to : end;
        // A logged workout with no time still overlaps a session it falls in.
        final inside = !start.isBefore(from) && !start.isAfter(to);
        final overlap = overlapEnd.isAfter(overlapStart)
            ? overlapEnd.difference(overlapStart).inSeconds
            : (inside ? 0 : -1);
        final gap = from.difference(start).inSeconds.abs();
        if (best == null ||
            overlap > bestOverlap ||
            (overlap == bestOverlap && gap < bestGap)) {
          best = session;
          bestOverlap = overlap;
          bestGap = gap;
        }
      }
      if (best != null) {
        used.add(best.id);
        result[workout.id] = best;
      }
    }
    return result;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
