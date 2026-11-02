import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/services/firebase_service.dart';

class TestUser implements User {
  @override
  String get uid => 'a';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExerciseCloud implements FirebaseService {
  bool offline = true;
  final saved = <String, Map<String, dynamic>>{};
  @override
  User? get currentUser => TestUser();
  @override
  Future<void> saveCustomExercise(
      String uid, Map<String, dynamic> exercise) async {
    if (offline) throw StateError('offline');
    saved[exercise['id']] = exercise;
  }

  @override
  Future<void> deleteCustomExercise(String uid, String id) async {
    if (offline) throw StateError('offline');
    saved.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Exercise exercise(String id, [String name = 'Press']) => Exercise(
    id: id,
    name: name,
    muscleGroup: 'chest',
    equipment: 'barbell',
    instructions: '',
    videoUrl: '',
    difficulty: 'Intermediate',
    source: 'custom');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  StorageService storage([String uid = 'a']) => StorageService(
      account: AccountStorage(uid, documentsDirectory: () async => directory));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('custom-sync-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('existing local exercises migrate into the durable queue', () async {
    final account =
        AccountStorage('a', documentsDirectory: () async => directory);
    final legacy = File(await account.filePath('custom_exercises.json'));
    await legacy.writeAsString(jsonEncode([exercise('legacy').toJson()]));
    expect((await storage().getCustomExercises()).single.id, 'legacy');
    expect(await storage().pendingExercises(), contains('legacy'));
    expect((await storage().getCustomExercises()).length, 1);
  });
  test('local saves survive restart, concurrent saves and account separation',
      () async {
    await Future.wait([
      storage().saveCustomExercise(exercise('one')),
      storage().saveCustomExercise(exercise('two'))
    ]);
    expect((await storage().getCustomExercises()).length, 2);
    expect((await storage().pendingExercises()).length, 2);
    expect(await storage('b').getCustomExercises(), isEmpty);
  });
  test(
      'cloud cache persists and stale fetches or acknowledgements cannot erase edits',
      () async {
    final s = storage();
    await s.mergeCloudExercises([exercise('cloud').toJson()],
        expectedRevision: await s.exerciseRevision());
    expect((await storage().getCustomExercises()).single.id, 'cloud');
    final revision = await s.exerciseRevision();
    await s.saveCustomExercise(exercise('cloud', 'Edited'));
    final old = (await s.pendingExercises())['cloud']['revision'] as int;
    await s.saveCustomExercise(exercise('cloud', 'Newest'));
    await s.acknowledgeExercise('cloud', old);
    await s.mergeCloudExercises([exercise('cloud').toJson()],
        expectedRevision: revision);
    expect((await s.getCustomExercises()).single.name, 'Newest');
    expect(await s.pendingExercises(), contains('cloud'));
    await s.deleteCustomExercise('cloud');
    await s.mergeCloudExercises([exercise('cloud').toJson()],
        expectedRevision: await s.exerciseRevision());
    expect(await s.getCustomExercises(), isEmpty);
  });
  test('failed uploads and deletes retry successfully after restart', () async {
    final cloud = ExerciseCloud();
    await storage().saveCustomExercise(exercise('one'));
    var sync = SyncService(cloud, storage());
    await sync.flushPending();
    expect(await storage().pendingExercises(), contains('one'));
    sync.dispose();
    cloud.offline = false;
    sync = SyncService(cloud, storage());
    await sync.flushPending();
    expect(cloud.saved, contains('one'));
    expect(await storage().pendingExercises(), isEmpty);
    cloud.offline = true;
    await storage().deleteCustomExercise('one');
    await sync.flushPending();
    expect(await storage().pendingExercises(), contains('one'));
    cloud.offline = false;
    await sync.flushPending();
    expect(cloud.saved, isEmpty);
    expect(await storage().pendingExercises(), isEmpty);
    sync.dispose();
  });
}
