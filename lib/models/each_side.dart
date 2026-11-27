/// Which exercises can be logged "each side": one arm or one leg at a time,
/// or alternating sides, where the weight and reps typed are for one side.
/// Everything else is logged as a whole set and doesn't offer it.
class EachSide {
  // One arm or leg at a time, or alternating sides (reps count per side).
  static final _oneSide = RegExp(
      r'\b(one|single)[ -](arm|leg|hand|side)\b|\bunilateral\b|\balternat'
      r'|\bsplit squat\b|\bbulgarian\b|\blunges?\b|\bstep[ -]?ups?\b'
      r'|\bpistol\b|\bkickbacks?\b|\bconcentration curl\b',
      caseSensitive: false);

  // Names that match a rule above but work both sides together, or are
  // core moves where a per-side weight means nothing.
  static final _notOneSided = RegExp(
      r'\btwo[ -]arms?\b|\bheel touch|\bv[ -]?ups?\b|\bleg raises?\b'
      r'|\bcrunch|\bsit[ -]?ups?\b',
      caseSensitive: false);

  /// Whether an exercise works one side at a time, so "each side" applies.
  static bool isOneSided(String? name, {String? type}) {
    if (type == 'cardio' || type == 'timedHold') return false;
    final text = name ?? '';
    return _oneSide.hasMatch(text) && !_notOneSided.hasMatch(text);
  }

  /// Whether a new exercise starts as "each side": every one-sided exercise.
  static bool defaultFor(String? name, {String? equipment, String? type}) =>
      isOneSided(name, type: type);
}
