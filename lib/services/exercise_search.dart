import '../models/exercise_model.dart';

/// Forgiving exercise search shared by the library, the workout picker and
/// the catalog repository.
///
/// - Case, punctuation, hyphens and spacing don't matter: "push-up",
///   "pushup" and "push up" are the same.
/// - Words match in any order, each at the start of a word in the name,
///   muscle or equipment, so "row" finds rows but not "throw".
/// - Plurals and common gym shorthand are understood ("squats", "db curl",
///   "rdl", "ohp", "abs").
/// - Results are ranked: exercises you've logged, then exact and leading
///   name matches, then other name matches, then muscle or equipment
///   matches; shorter names first among equals.
class ExerciseSearch {
  ExerciseSearch._();

  /// Shorthand and synonyms, after normalizing and singularizing. Each entry
  /// lists phrases the word may stand for; any one phrase may match.
  static const Map<String, List<String>> _aliases = {
    'db': ['dumbbell'],
    'dbs': ['dumbbell'],
    'bb': ['barbell'],
    'kb': ['kettlebell'],
    'rdl': ['romanian deadlift'],
    'sldl': ['stiff leg deadlift'],
    'ohp': ['overhead press'],
    'bp': ['bench press'],
    'core': ['abs', 'core'],
    'ab': ['abs'],
    'abdominal': ['abs'],
    'quad': ['quadricep'],
    'ham': ['hamstring'],
    'hammy': ['hamstring'],
    'delt': ['shoulder', 'delt'],
    'pec': ['chest', 'pec'],
    'trap': ['trap'],
    'calve': ['calf', 'calve'],
    'calf': ['calf', 'calve'],
    'flye': ['fly'],
    'flie': ['fly'],
    'running': ['run', 'treadmill'],
    'run': ['run', 'treadmill'],
    'jog': ['run', 'treadmill'],
    'jogging': ['run', 'treadmill'],
    'cycling': ['bike', 'cycle'],
    'cycle': ['bike', 'cycle'],
    'rower': ['row'],
    'rowing': ['row'],
    'stairmaster': ['stair', 'step'],
    'military': ['military', 'overhead'],
    'skullcrusher': ['skull crusher', 'skullcrusher'],
  };

  // Variant markers and model labels in library names that nobody types.
  static final _noise = RegExp(r'^(v\d+|male|female)$');

  /// Lowercase words with punctuation and apostrophes removed.
  static List<String> _words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty && !_noise.hasMatch(w))
      .map(_singular)
      .toList();

  /// "squats" → "squat", "lunges" → "lunge", "biceps" → "bicep"; leaves
  /// "press", "abs" and short words alone.
  static String _singular(String word) {
    if (word.length <= 3 || !word.endsWith('s') || word.endsWith('ss')) {
      return word;
    }
    return word.substring(0, word.length - 1);
  }

  static String _joined(List<String> words) => words.join();

  /// Name words plus each adjacent pair written together, so "pushup" and
  /// "benchpress" find "Push Up" and "Bench Press".
  static List<String> _withJoins(List<String> words) => [
        ...words,
        for (var i = 0; i + 1 < words.length; i++)
          _singular(words[i] + words[i + 1]),
      ];

  /// Whether every word of [phrase] starts some token.
  static bool _phraseIn(List<String> phrase, List<String> tokens) =>
      phrase.every((word) => tokens.any((token) => token.startsWith(word)));

  /// Whether [word] (or one of its aliases) matches [tokens].
  static bool _wordIn(String word, List<String> tokens) {
    if (tokens.any((token) => token.startsWith(word))) return true;
    final alternatives = _aliases[word];
    if (alternatives == null) return false;
    return alternatives.any((alias) => _phraseIn(_words(alias), tokens));
  }

  /// Matches query words against [tokens], letting two neighbouring query
  /// words count as one ("pull down" → "pulldown", "t bar" → "tbar").
  static bool _queryIn(List<String> query, List<String> tokens) {
    bool from(int i) {
      if (i >= query.length) return true;
      if (_wordIn(query[i], tokens) && from(i + 1)) return true;
      if (i + 1 < query.length &&
          _wordIn(_singular(query[i] + query[i + 1]), tokens) &&
          from(i + 2)) {
        return true;
      }
      return false;
    }

    return from(0);
  }

  /// Ranked matches for [query]. An empty query returns [exercises] in name
  /// order with [loggedIds] first.
  static List<Exercise> search(Iterable<Exercise> exercises, String query,
      {Set<String> loggedIds = const {}}) {
    final words = _words(query);
    final scored = <(Exercise, int)>[];
    for (final exercise in exercises) {
      final score = _score(exercise, words, loggedIds.contains(exercise.id));
      if (score != null) scored.add((exercise, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0
          ? byScore
          : a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });
    return [for (final entry in scored) entry.$1];
  }

  /// Whether [exercise] matches [query] at all.
  static bool matches(Exercise exercise, String query) =>
      _score(exercise, _words(query), false) != null;

  static int? _score(Exercise exercise, List<String> query, bool logged) {
    final name = _words(exercise.name);
    var score = logged ? 1000 : 0;
    if (query.isEmpty) return score;
    final nameTokens = _withJoins(name);
    final everything = [
      ...nameTokens,
      ..._words(exercise.muscleGroup),
      ..._words(exercise.equipment),
    ];
    final inName = _queryIn(query, nameTokens);
    if (!inName && !_queryIn(query, everything)) return null;

    final typed = _joined(query);
    final full = _joined(name);
    if (full == typed) {
      score += 500;
    } else if (full.startsWith(typed)) {
      score += 300;
    } else if (inName) {
      score += 200;
      // Words in the same order as the name rank a little higher.
      final at = [
        for (final w in query) name.indexWhere((n) => n.startsWith(w))
      ];
      if (!at.contains(-1)) {
        var ordered = true;
        for (var i = 1; i < at.length; i++) {
          if (at[i] < at[i - 1]) ordered = false;
        }
        if (ordered) score += 40;
        if (at.first == 0) score += 30;
      }
    }
    // Shorter, simpler names first among equal matches.
    return score - name.length * 4;
  }
}
