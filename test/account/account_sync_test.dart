import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:sweatmark/services/account_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/firebase_service.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';

class _User implements User {
  @override
  final String uid;
  _User(this.uid);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cloud implements FirebaseService {
  @override
  User? currentUser = _User('a');
  final writes = <String>[];
  final deletes = <String>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<List<WorkoutLog>> getWorkouts(String userId) async => [];
  @override
  Future<void> saveWorkout(String userId, WorkoutLog workout) async {
    writes.add(userId);
    if (fail) throw StateError('offline');
    if (gate != null) await gate!.future;
  }

  @override
  Future<void> deleteWorkout(String userId, WorkoutLog workout) async =>
      deletes.add(userId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkoutLog workout({String name = 'Workout', int day = 1}) => WorkoutLog(
    workoutName: name,
    timestamp: DateTime(2026, 1, day),
    durationSeconds: 60,
    exercises: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  StorageService local([String uid = 'a']) => StorageService(
      account: AccountStorage(uid, documentsDirectory: () async => root));
  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-workouts-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('offline save survives restart and retries beyond three failures',
      () async {
    final cloud = _Cloud()..fail = true;
    var sync = SyncService(cloud, local());
    await sync.syncWorkout('a', workout());
    for (var i = 0; i < 5; i++) {
      await sync.flushPending();
    }
    expect((await local().pendingWorkouts()).length, 1);
    sync.dispose();
    sync = SyncService(cloud, local());
    cloud.fail = false;
    await sync.flushPending();
    expect(await local().pendingWorkouts(), isEmpty);
    expect((await local().getWorkouts()).length, 1);
    sync.dispose();
  });

  test('pending local edits beat stale cloud and delete survives restart',
      () async {
    final store = local();
    await store.saveWorkout(workout(name: 'edited'));
    await store.mergeCloudWorkouts([workout(name: 'stale'), workout(day: 2)]);
    expect((await store.getWorkouts()).last.workoutName, 'edited');
    await store.deleteWorkout(workout());
    final cloud = _Cloud();
    final sync = SyncService(cloud, local());
    await sync.flushPending();
    await local().mergeCloudWorkouts([workout(name: 'stale')]);
    expect(
        (await local().getWorkouts()).map((w) => w.id), [workout(day: 2).id]);
    expect(cloud.deletes, ['a']);
    sync.dispose();
  });

  test('late acknowledgement cannot discard a newer edit', () async {
    final store = local();
    await store.saveWorkout(workout());
    final old = (await store.pendingWorkouts()).values.single;
    await store.saveWorkout(workout(name: 'newer'));
    await store.acknowledgeWorkout(workout().id, old['revision']);
    expect((await store.pendingWorkouts()).length, 1);
    expect((await store.getWorkouts()).single.workoutName, 'newer');
  });

  test('concurrent instances preserve writes and same ID upserts', () async {
    await Future.wait(
        List.generate(20, (i) => local().saveWorkout(workout(day: i + 1))));
    await local().saveWorkout(workout(name: 'updated'));
    expect((await local().getWorkouts()).length, 20);
    expect((await local().pendingWorkouts()).length, 20);
  });

  test('account changes and disposal prevent further uploads', () async {
    final cloud = _Cloud()..currentUser = _User('b');
    final sync = SyncService(cloud, local());
    await sync.syncWorkout('a', workout());
    await sync.flushPending();
    expect(cloud.writes, isEmpty);
    expect(await local('b').getWorkouts(), isEmpty);
    sync.dispose();
    cloud.currentUser = _User('a');
    await sync.flushPending();
    expect(cloud.writes, isEmpty);
    expect((await local().pendingWorkouts()).length, 1);
  });

  test('mismatched account is rejected', () async {
    final cloud = _Cloud();
    final sync = SyncService(cloud, local());
    await sync.syncWorkout('b', workout());
    await sync.flushPending();
    expect(await local().getWorkouts(), isEmpty);
    sync.dispose();
  });

  test('save finishes locally while cloud acknowledgement is stalled',
      () async {
    final cloud = _Cloud()..gate = Completer<void>();
    final sync = SyncService(cloud, local());
    await sync.syncWorkout('a', workout()).timeout(const Duration(seconds: 1));
    expect((await local().getWorkouts()).length, 1);
    expect((await sync.getWorkouts('a')).length, 1);
    cloud.gate!.complete();
    await sync.flushPending();
    sync.dispose();
  });

  test('owned legacy history is migrated into durable retry state', () async {
    final account = AccountStorage('a', documentsDirectory: () async => root);
    await File(await account.filePath('workout_logs.json'))
        .writeAsString(jsonEncode([workout().toJson()]));
    expect((await local().pendingWorkouts()).length, 1);
    expect((await local().getWorkouts()).single.id, workout().id);
  });

  test('completion atomically removes draft and ignores late autosave',
      () async {
    final draft = {
      'timestamp': workout().timestamp.toIso8601String(),
      'exercises': []
    };
    await local().saveDraftWorkout(draft);
    await local().saveWorkout(workout());
    await local().saveDraftWorkout(draft);
    expect(await local().getDraftWorkout(), isNull);
    expect((await local().pendingWorkouts()).length, 1);
  });

  test('cloud response begun before an edit cannot overwrite it', () async {
    final revision = await local().workoutRevision();
    await local().saveWorkout(workout(name: 'new'));
    final pending = (await local().pendingWorkouts()).values.single;
    await local().acknowledgeWorkout(workout().id, pending['revision']);
    await local()
        .mergeCloudWorkouts([workout(name: 'old')], expectedRevision: revision);
    expect((await local().getWorkouts()).single.workoutName, 'new');
  });

  test('corrupt history fails closed instead of overwriting saved data',
      () async {
    final account = AccountStorage('a', documentsDirectory: () async => root);
    final file = File(await account.filePath('workout_state.json'));
    await file.writeAsString('damaged data');
    await expectLater(local().saveWorkout(workout()), throwsFormatException);
    expect(await file.readAsString(), 'damaged data');
  });
}
