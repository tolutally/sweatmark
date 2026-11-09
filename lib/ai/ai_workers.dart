import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Calls SweatMark's AI workers through the `runAiWorker` Cloud Function.
///
/// Each worker is one job (exercise search today; program building and
/// others later). The Claude API key stays on the server; the app only sends
/// the worker's input. AI is always an extra: callers get [AiUnavailable]
/// when it can't answer and keep working without it.
class AiWorkers {
  AiWorkers(
      {Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          call})
      : _call = call;

  static final instance = AiWorkers();

  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
      _call;
  final Map<String, ExerciseSearchSuggestions> _searches = {};

  Future<Map<String, dynamic>> _run(
      String worker, Map<String, dynamic> input) async {
    final call = _call;
    if (call != null) return call(worker, input);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable('runAiWorker',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 40)));
      final response =
          await callable.call<dynamic>({'worker': worker, 'input': input});
      final data = Map<String, dynamic>.from(response.data as Map);
      return Map<String, dynamic>.from(data['result'] as Map);
    } on FirebaseFunctionsException catch (error) {
      throw AiUnavailable(switch (error.code) {
        'resource-exhausted' =>
          'You’ve used today’s AI searches. Try again tomorrow.',
        'unauthenticated' => 'Sign in to use AI search.',
        _ => 'AI search isn’t available right now.',
      });
    } catch (error) {
      debugPrint('AI worker $worker failed: $error');
      throw const AiUnavailable('AI search isn’t available right now.');
    }
  }

  /// Exercises from the library that match what the person meant, with a
  /// short reason each, or a custom exercise to create when none fit.
  /// Repeated searches in this session are answered from memory.
  Future<ExerciseSearchSuggestions> searchExercises(String query,
      {String? muscle, String? equipment}) async {
    final key =
        [query.trim().toLowerCase(), muscle ?? '', equipment ?? ''].join('|');
    final cached = _searches[key];
    if (cached != null) return cached;
    final result =
        ExerciseSearchSuggestions.fromJson(await _run('exerciseSearch', {
      'query': query.trim(),
      if (muscle != null) 'muscle': muscle,
      if (equipment != null) 'equipment': equipment,
    }));
    _searches[key] = result;
    return result;
  }
}

/// AI couldn't answer; [message] is safe to show.
class AiUnavailable implements Exception {
  final String message;
  const AiUnavailable(this.message);
  @override
  String toString() => message;
}

class AiExerciseMatch {
  final String id;
  final String reason;
  const AiExerciseMatch(this.id, this.reason);
}

class AiCustomExercise {
  final String name;
  final String muscleGroup;
  final String equipment;
  const AiCustomExercise(this.name, this.muscleGroup, this.equipment);
}

class ExerciseSearchSuggestions {
  final List<AiExerciseMatch> matches;
  final AiCustomExercise? customExercise;
  const ExerciseSearchSuggestions(this.matches, this.customExercise);

  factory ExerciseSearchSuggestions.fromJson(Map<String, dynamic> json) {
    final matches = [
      for (final item in (json['matches'] as List? ?? const []))
        if (item is Map && item['id'] is String)
          AiExerciseMatch(item['id'] as String, '${item['reason'] ?? ''}'),
    ];
    final custom = json['customExercise'];
    return ExerciseSearchSuggestions(
        matches,
        custom is Map && custom['name'] is String
            ? AiCustomExercise(
                custom['name'] as String,
                '${custom['muscleGroup'] ?? ''}',
                '${custom['equipment'] ?? ''}')
            : null);
  }
}
