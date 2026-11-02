import 'dart:convert';
import 'dart:io';
import 'account_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/exercise_model.dart';
import 'firebase_service.dart';

class StorageService {
  static const String _fileName = 'workout_logs.json';
  static const String _customExercisesFileName = 'custom_exercises.json';
  static const String _draftWorkoutFileName = 'draft_workout.json';

  late final FirebaseService _firebaseService = FirebaseService();
  final AccountStorage _account;
  String? get userId => _account.userId;

  StorageService({AccountStorage? account})
      : _account =
            account ?? AccountStorage(FirebaseAuth.instance.currentUser?.uid);

  bool get _canSync =>
      userId != null && FirebaseAuth.instance.currentUser?.uid == userId;

  Future<String> _getFilePath() => _account.filePath(_fileName);

  Future<String> _getCustomExercisesFilePath() =>
      _account.filePath(_customExercisesFileName);

  Future<String> _getDraftWorkoutFilePath() =>
      _account.filePath(_draftWorkoutFileName);

  // One atomic snapshot contains both history and the durable outbox. Locks
  // are shared across service instances, including overlapping login sessions.
  static final Map<String, Future<void>> _locks = {};

  Future<T> _withWorkouts<T>(
      Future<T> Function(Map<String, dynamic>, String) action) async {
    final path = await _account.filePath('workout_state.json');
    final previous = _locks[path] ?? Future<void>.value();
    final next = previous.then((_) async {
      final file = File(path);
      Map<String, dynamic> state;
      if (await file.exists()) {
        state = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } else {
        final legacy = File(await _getFilePath());
        final logs = await legacy.exists()
            ? (jsonDecode(await legacy.readAsString()) as List)
            : <dynamic>[];
        state = {
          'revision': 0,
          'workouts': <String, dynamic>{},
          'pending': <String, dynamic>{}
        };
        for (final json in logs) {
          final workout = WorkoutLog.fromJson(Map<String, dynamic>.from(json));
          state['workouts'][workout.id] = workout.toJson();
          state['pending'][workout.id] = {
            'revision': 0,
            'delete': false,
            'workout': workout.toJson()
          };
        }
      }
      if (!state.containsKey('draft')) {
        final legacyDraft = File(await _getDraftWorkoutFilePath());
        state['draft'] = await legacyDraft.exists()
            ? jsonDecode(await legacyDraft.readAsString())
            : null;
      }
      return action(state, path);
    });
    final tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _locks[path] = tail;
    try {
      return await next;
    } finally {
      if (identical(_locks[path], tail)) _locks.remove(path);
    }
  }

  Future<void> _writeState(Map<String, dynamic> state, String path) async {
    final temporary = File('$path.tmp');
    await temporary.writeAsString(jsonEncode(state), flush: true);
    await temporary.rename(path);
  }

  Future<void> saveWorkout(WorkoutLog log) => _changeWorkout(log, false);
  Future<void> deleteWorkout(WorkoutLog log) => _changeWorkout(log, true);

  Future<void> _changeWorkout(WorkoutLog log, bool delete) =>
      _withWorkouts((state, path) async {
        final revision = (state['revision'] as int) + 1;
        state['revision'] = revision;
        state['deleted'] ??= <String, dynamic>{};
        if (delete) {
          state['deleted'][log.id] = true;
          state['workouts'].remove(log.id);
        } else {
          state['deleted'].remove(log.id);
          state['workouts'][log.id] = log.toJson();
        }
        if (!delete &&
            state['draft']?['timestamp'] == log.timestamp.toIso8601String()) {
          state['draft'] = null;
        }
        state['pending'][log.id] = {
          'revision': revision,
          'delete': delete,
          'workout': log.toJson()
        };
        await _writeState(state, path);
      });

  Future<List<WorkoutLog>> getWorkouts() => userId == null
      ? Future.value([])
      : _withWorkouts((state, _) async {
          final logs = (state['workouts'] as Map)
              .values
              .map((json) =>
                  WorkoutLog.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return logs;
        });

  Future<Map<String, dynamic>> pendingWorkouts() =>
      _withWorkouts((state, path) async {
        // Persist migration even when there are no subsequent user edits.
        await _writeState(state, path);
        return Map<String, dynamic>.from(state['pending']);
      });

  Future<void> acknowledgeWorkout(String id, int revision) =>
      _withWorkouts((state, path) async {
        if (state['pending'][id]?['revision'] == revision) {
          state['pending'].remove(id);
          state['revision'] = (state['revision'] as int) + 1;
          await _writeState(state, path);
        }
      });

  Future<int> workoutRevision() =>
      _withWorkouts((state, _) async => state['revision'] as int);

  Future<void> mergeCloudWorkouts(List<WorkoutLog> cloud,
          {int? expectedRevision}) =>
      _withWorkouts((state, path) async {
        if (expectedRevision != null && state['revision'] != expectedRevision) {
          return;
        }
        for (final workout in cloud) {
          if (!state['pending'].containsKey(workout.id) &&
              !(state['deleted'] as Map? ?? {}).containsKey(workout.id)) {
            state['workouts'][workout.id] = workout.toJson();
          }
        }
        await _writeState(state, path);
      });

  Future<void> clearWorkouts() async {
    for (final workout in await getWorkouts()) {
      await deleteWorkout(workout);
    }
  }

  // Custom exercises use an atomic account-scoped snapshot and durable outbox.
  Future<T> _withExercises<T>(
      Future<T> Function(Map<String, dynamic>, String) action) async {
    final path = await _account.filePath('exercise_state.json');
    final previous = _locks[path] ?? Future<void>.value();
    final next = previous.then((_) async {
      final file = File(path);
      final state = await file.exists()
          ? Map<String, dynamic>.from(jsonDecode(await file.readAsString()))
          : <String, dynamic>{
              'revision': 0,
              'items': <String, dynamic>{},
              'pending': <String, dynamic>{},
              'deleted': <String, dynamic>{}
            };
      if (!await file.exists()) {
        final legacy = File(await _getCustomExercisesFilePath());
        if (await legacy.exists()) {
          for (final json in jsonDecode(await legacy.readAsString()) as List) {
            final exercise = Exercise.fromJson(Map<String, dynamic>.from(json));
            state['items'][exercise.id] = exercise.toJson();
            state['pending'][exercise.id] = {
              'revision': 0,
              'delete': false,
              'exercise': exercise.toJson()
            };
          }
        }
        await _writeState(state, path);
      }
      return action(state, path);
    });
    final tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _locks[path] = tail;
    try {
      return await next;
    } finally {
      if (identical(_locks[path], tail)) _locks.remove(path);
    }
  }

  Future<void> saveCustomExercise(Exercise exercise) =>
      _changeExercise(exercise.id, exercise);

  Future<void> deleteCustomExercise(String id) => _changeExercise(id, null);

  Future<void> _changeExercise(String id, Exercise? exercise) =>
      _withExercises((state, path) async {
        final revision = (state['revision'] as int) + 1;
        state['revision'] = revision;
        if (exercise == null) {
          state['items'].remove(id);
          state['deleted'][id] = true;
        } else {
          state['items'][id] = exercise.toJson();
          state['deleted'].remove(id);
        }
        state['pending'][id] = {
          'revision': revision,
          'delete': exercise == null,
          'exercise': exercise?.toJson()
        };
        await _writeState(state, path);
      });

  Future<List<Exercise>> getCustomExercises() => userId == null
      ? Future.value([])
      : _withExercises((state, _) async => (state['items'] as Map)
          .values
          .map((json) => Exercise.fromJson(Map<String, dynamic>.from(json)))
          .toList());

  Future<Map<String, dynamic>> pendingExercises() => _withExercises(
      (state, _) async => Map<String, dynamic>.from(state['pending']));

  Future<void> acknowledgeExercise(String id, int revision) =>
      _withExercises((state, path) async {
        if (state['pending'][id]?['revision'] == revision) {
          state['pending'].remove(id);
          state['revision'] = (state['revision'] as int) + 1;
          await _writeState(state, path);
        }
      });

  Future<int> exerciseRevision() =>
      _withExercises((state, _) async => state['revision'] as int);

  Future<void> mergeCloudExercises(List<Map<String, dynamic>> cloud,
          {required int expectedRevision}) =>
      _withExercises((state, path) async {
        if (state['revision'] != expectedRevision) return;
        for (final json in cloud) {
          final exercise = Exercise.fromJson(json);
          if (!state['pending'].containsKey(exercise.id) &&
              !state['deleted'].containsKey(exercise.id)) {
            state['items'][exercise.id] = exercise.toJson();
          }
        }
        await _writeState(state, path);
      });

  Future<List<Exercise>> getCustomExercisesMerged() async {
    if (_canSync) {
      try {
        final revision = await exerciseRevision();
        final cloud = await _firebaseService
            .getCustomExercises(userId!)
            .timeout(const Duration(seconds: 3));
        if (!_canSync) return [];
        await mergeCloudExercises(cloud, expectedRevision: revision);
      } catch (_) {
        // Offline reads preserve the cached library and pending local edits.
      }
    }
    return getCustomExercises();
  }

  // Draft and completion share a commit, preventing completed drafts from
  // returning after a crash between saving history and clearing the draft.
  Future<void> saveDraftWorkout(Map<String, dynamic> draftData) =>
      _withWorkouts((state, path) async {
        final timestamp = draftData['timestamp'] as String?;
        if (timestamp != null) {
          final id =
              DateTime.parse(timestamp).millisecondsSinceEpoch.toString();
          if (state['workouts'].containsKey(id) ||
              (state['deleted'] as Map? ?? {}).containsKey(id)) {
            return;
          }
        }
        state['draft'] = draftData;
        await _writeState(state, path);
      });

  Future<Map<String, dynamic>?> getDraftWorkout() async {
    if (userId == null) return null;
    return _withWorkouts((state, _) async => state['draft'] == null
        ? null
        : Map<String, dynamic>.from(state['draft']));
  }

  Future<void> deleteDraftWorkout() => _withWorkouts((state, path) async {
        state['draft'] = null;
        await _writeState(state, path);
      });

  Future<bool> hasDraftWorkout() async => await getDraftWorkout() != null;
}
