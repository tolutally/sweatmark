import 'exercise_model.dart';

/// The kind of cardio machine (or activity) an exercise is, which decides
/// what the session card asks for: what the machine's screen shows at the
/// end, never both speed and distance.
enum CardioMachine { treadmill, bike, rower, stairs, elliptical, other }

/// What a session card asks for beyond time.
enum CardioField { distance, incline, level, calories }

extension CardioMachineInfo on CardioMachine {
  /// Fields in the order the machine's screen usually shows them.
  List<CardioField> get fields => switch (this) {
        CardioMachine.treadmill => const [
            CardioField.distance,
            CardioField.incline,
            CardioField.calories
          ],
        CardioMachine.bike => const [
            CardioField.distance,
            CardioField.level,
            CardioField.calories
          ],
        CardioMachine.rower => const [
            CardioField.distance,
            CardioField.calories
          ],
        CardioMachine.stairs => const [CardioField.level, CardioField.calories],
        CardioMachine.elliptical => const [
            CardioField.level,
            CardioField.calories
          ],
        CardioMachine.other => const [
            CardioField.distance,
            CardioField.calories
          ],
      };

  /// Rowers count metres whatever the app's distance unit.
  bool get usesMetres => this == CardioMachine.rower;

  static CardioMachine of(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any(n.contains);
    if (has(['row', 'erg'])) return CardioMachine.rower;
    if (has(['stair', 'stepmill', 'step mill'])) return CardioMachine.stairs;
    if (has(['elliptical', 'cross trainer'])) return CardioMachine.elliptical;
    if (has(['bike', 'cycl'])) return CardioMachine.bike;
    if (has(['treadmill', 'run', 'jog', 'walk'])) {
      return CardioMachine.treadmill;
    }
    return CardioMachine.other;
  }
}

/// Whether an exercise is logged as one cardio session instead of sets.
bool isCardioSession(Exercise exercise, {String? loggedType}) =>
    loggedType == 'cardio' || exercise.exerciseType == ExerciseType.cardio;

/// Pace, speed or split worked out from time and distance.
class CardioPace {
  CardioPace._();

  static String _clock(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  /// A short summary like "9:40 /mi · 6.2 mph", "2:05 /500m" or
  /// "18.4 km/h". Null without both time and distance.
  static String? summary(
      {required CardioMachine machine,
      required int? seconds,
      required double? distanceKm,
      required bool miles}) {
    if (seconds == null || seconds <= 0) return null;
    if (distanceKm == null || distanceKm <= 0) return null;
    if (machine.usesMetres) {
      return '${_clock(seconds / (distanceKm * 1000 / 500))} /500m';
    }
    final distance = miles ? distanceKm / 1.609344 : distanceKm;
    final unit = miles ? 'mi' : 'km';
    final speed = distance / (seconds / 3600);
    final speedLabel = '${speed.toStringAsFixed(1)} ${miles ? 'mph' : 'km/h'}';
    if (machine == CardioMachine.bike) return speedLabel;
    return '${_clock(seconds / distance)} /$unit · $speedLabel';
  }

  /// Average speed in the person's unit per hour, for storing on the set.
  static double? speed(int? seconds, double? distanceKm,
      {required bool miles}) {
    if (seconds == null || seconds <= 0 || distanceKm == null) return null;
    if (distanceKm <= 0) return null;
    final distance = miles ? distanceKm / 1.609344 : distanceKm;
    return double.parse((distance / (seconds / 3600)).toStringAsFixed(2));
  }

  static String clock(int seconds) => _clock(seconds.toDouble());
}
