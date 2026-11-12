import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/services/exercise_search.dart';

void main() {
  final library = [
    for (final file in [
      'assets/exercises/catalog_v1.json',
      'assets/exercises/sweatmark_staples.json'
    ])
      for (final json in (jsonDecode(File(file).readAsStringSync())
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

  test('common gym names find the library exercise they mean', () {
    const commonNames = {
      'face pull': 'Rear Delt Row With Rope',
      'face pulls': 'Rear Delt Row With Rope',
      'face pu': 'Rear Delt Row With Rope',
      'pec deck': 'Lever Seated Fly',
      'bulgarian split squat': 'Single Leg Split Squat',
      'farmer carry': 'Farmers Walk',
      'stairmaster': 'Walking On Stepmill',
      'reverse lunge': 'Rear Lunge',
      'single leg rdl': 'Single Leg Deadlift',
      'z press': 'Barbell Seated Overhead Press',
      'back squat': 'Barbell',
      'ab wheel': 'Wheel Rollerout',
    };
    for (final entry in commonNames.entries) {
      expect(
          names(entry.key, take: 3).any((n) => n.contains(entry.value)), isTrue,
          reason: '"${entry.key}" should find ${entry.value}, '
              'got ${names(entry.key, take: 3)}');
    }
  });

  test('everyday staples missing from the bundled library are found', () {
    const staples = {
      'dead hang': 'Dead Hang',
      'deadhang': 'Dead Hang',
      'bar hang': 'Dead Hang',
      'active hang': 'Active Hang',
      'sled push': 'Sled Push',
      'wall sit': 'Wall Sit',
      'hip thrust': 'Barbell Hip Thrust',
      'rowing machine': 'Rowing Machine',
      'rower': 'Rowing Machine',
      'assault bike': 'Assault Bike',
      'glute kickback': 'Cable Glute Kickback',
      'toes to bar': 'Toes to Bar',
    };
    for (final entry in staples.entries) {
      expect(names(entry.key, take: 3), contains(entry.value),
          reason: '"${entry.key}" got ${names(entry.key, take: 3)}');
    }
  });

  test('short words do not trigger common names', () {
    expect(names('face').every((n) => !n.contains('Rear Delt Row')), isTrue);
  });
}
