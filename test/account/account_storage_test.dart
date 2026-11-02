import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/models/workout_model.dart';

void main() {
  late Directory root;
  setUp(() async =>
      root = await Directory.systemTemp.createTemp('sweatmark-accounts-'));
  tearDown(() async => root.delete(recursive: true));

  test('workouts, drafts, custom exercises and recovery stay with their owner',
      () async {
    final a = AccountStorage('account-a', documentsDirectory: () async => root);
    final b = AccountStorage('account-b', documentsDirectory: () async => root);
    for (final name in [
      'workout_logs.json',
      'draft_workout.json',
      'custom_exercises.json',
      'muscle_recovery.json'
    ]) {
      final aFile = File(await a.filePath(name));
      await aFile.writeAsString('account-a private data');
      final bFile = File(await b.filePath(name));
      expect(await bFile.exists(), isFalse);
      await bFile.writeAsString('account-b private data');
      final returningA =
          AccountStorage('account-a', documentsDirectory: () async => root);
      expect(await File(await returningA.filePath(name)).readAsString(),
          'account-a private data');
    }
  });

  test('storage service cannot read or delete another account workout or draft',
      () async {
    final a = StorageService(
        account: AccountStorage('a', documentsDirectory: () async => root));
    final b = StorageService(
        account: AccountStorage('b', documentsDirectory: () async => root));
    final workout = WorkoutLog(
        workoutName: 'A private workout',
        timestamp: DateTime(2026, 1, 1),
        durationSeconds: 60,
        exercises: []);
    await a.saveWorkout(workout);
    await a.saveDraftWorkout({'workoutName': 'A private draft'});
    expect(await b.getWorkouts(), isEmpty);
    expect(await b.getDraftWorkout(), isNull);
    await b.clearWorkouts();
    await b.deleteDraftWorkout();
    expect((await a.getWorkouts()).single.workoutName, 'A private workout');
    expect((await a.getDraftWorkout())!['workoutName'], 'A private draft');
  });

  test('legacy unowned data is preserved but never adopted by a new account',
      () async {
    final legacy = File('${root.path}/draft_workout.json');
    await legacy.writeAsString('unknown owner');
    final account =
        AccountStorage('new-user', documentsDirectory: () async => root);
    expect(await File(await account.filePath('draft_workout.json')).exists(),
        isFalse);
    expect(await legacy.readAsString(), 'unknown owner');
  });

  test('an in-flight path lookup stays bound to its original account',
      () async {
    final directory = Completer<Directory>();
    final original =
        AccountStorage('original', documentsDirectory: () => directory.future);
    final pendingPath = original.filePath('workout_logs.json');
    final next = AccountStorage('next', documentsDirectory: () async => root);
    final nextPath = await next.filePath('workout_logs.json');
    directory.complete(root);
    expect(await pendingPath, isNot(nextPath));
    expect(
        await pendingPath,
        await AccountStorage('original', documentsDirectory: () async => root)
            .filePath('workout_logs.json'));
  });

  test('signed-out access and filename traversal are rejected', () async {
    final signedOut =
        AccountStorage(null, documentsDirectory: () async => root);
    await expectLater(
        signedOut.filePath('draft_workout.json'), throwsStateError);
    final account = AccountStorage('user/../strange-id',
        documentsDirectory: () async => root);
    await expectLater(
        account.filePath('../draft_workout.json'), throwsArgumentError);
    final path = await account.filePath('draft_workout.json');
    expect(path, startsWith('${root.path}/accounts/'));
    expect(path, isNot(contains('strange-id')));
  });
}
