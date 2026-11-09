import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/services/exercise_search.dart';

void main() {
  final library = [
    for (final json in (jsonDecode(
            File('assets/exercises/catalog_v1.json').readAsStringSync())
        as Map<String, dynamic>)['exercises'] as List)
      Exercise.fromJson(Map<String, dynamic>.from(json as Map))
  ];
  List<String> names(String query, {int take = 5}) =>
      ExerciseSearch.search(library, query)
          .take(take)
          .map((e) => e.name)
          .toList();

  // Real searches that found nothing or the wrong thing before.
  const mustFind = {
    'pushup': 'Push Up',
    'push-up': 'Push Up',
    'pullup': 'Pull Up',
    'situp': 'Sit Up',
    'benchpress': 'Bench Press',
    'press bench': 'Bench Press',
    'hipthrust': 'Hip Thrust',
    'tbar row': 'T Bar Row',
    'dumbbell curl': 'Dumbbell',
    'db curl': 'Dumbbell',
    'lunges': 'Lunge',
    'deadlifts': 'Deadlift',
    'squats': 'Squat',
    'rdl': 'Romanian Deadlift',
    'ohp': 'Overhead Press',
    'lat pull down': 'Pulldown',
    'cable crossover': 'Cross Over',
    "farmer's walk": 'Farmers Walk',
    'curls': 'Curl',
    'bicep curl': 'Curl',
    'running': 'Run',
    'skull crusher': 'Skull',
  };

  for (final entry in mustFind.entries) {
    test('"${entry.key}" finds ${entry.value}', () {
      final top = names(entry.key);
      expect(top, isNotEmpty, reason: 'no results');
      expect(top.any((n) => n.contains(entry.value)), isTrue,
          reason: 'top results: $top');
    });
  }

  test('"row" finds rows first, never "throw"', () {
    final top = names('row', take: 10);
    expect(top.every((n) => n.toLowerCase().contains('row')), isTrue);
    expect(top.any((n) => n.toLowerCase().contains('throw')), isFalse,
        reason: '$top');
  });

  test('exact names come first', () {
    expect(names('squat').first, startsWith('Squat'));
    expect(names('smith squat').first, 'Smith Squat');
    expect(names('burpee').first, 'Burpee');
    expect(names('kettlebell swing').first, 'Kettlebell Swing');
    expect(names('barbell bench press').first, 'Barbell Bench Press');
  });

  test('name matches rank above muscle-only matches', () {
    final top = names('glute', take: 3);
    expect(top.every((n) => n.toLowerCase().contains('glute')), isTrue,
        reason: '$top');
  });

  test('exercises you have logged come first', () {
    final logged =
        library.firstWhere((e) => e.name == 'Dumbbell Incline Bench Press').id;
    final ranked =
        ExerciseSearch.search(library, 'bench press', loggedIds: {logged});
    expect(ranked.first.id, logged);
  });

  test('muscle shorthand works', () {
    expect(ExerciseSearch.search(library, 'abs'), isNotEmpty);
    expect(ExerciseSearch.search(library, 'core').length,
        greaterThanOrEqualTo(ExerciseSearch.search(library, 'abs').length));
    expect(ExerciseSearch.search(library, 'quads'), isNotEmpty);
  });

  test('nonsense finds nothing', () {
    expect(ExerciseSearch.search(library, 'zzqx'), isEmpty);
  });
}
