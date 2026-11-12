import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/cardio_machine.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/services/account_storage.dart';
import 'package:sweatmark/services/firebase_service.dart';
import 'package:sweatmark/services/storage_service.dart';
import 'package:sweatmark/services/sync_service.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/cardio_session_card.dart';
import 'settings_screen_test.dart' show Preferences;

class OfflineCloud implements FirebaseService {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Exercise cardio(String id, String name) => Exercise(
    id: id,
    name: name,
    muscleGroup: 'Cardio',
    equipment: 'Machine',
    exerciseType: ExerciseType.cardio);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WorkoutNotifier> setUp(DateTime Function() clock) async {
    final directory = await Directory.systemTemp.createTemp('cardio-');
    final storage = StorageService(
        account:
            AccountStorage('test', documentsDirectory: () async => directory));
    final notifier = WorkoutNotifier(SyncService(OfflineCloud(), storage),
        storageService: storage);
    notifier.remind = (_) async {};
    notifier.clock = clock;
    await notifier.ready;
    return notifier;
  }

  test('machines are recognised from exercise names', () {
    CardioMachine of(String name) => CardioMachineInfo.of(name);
    expect(of('Treadmill Run'), CardioMachine.treadmill);
    expect(of('Incline Treadmill Walk'), CardioMachine.treadmill);
    expect(of('Running'), CardioMachine.treadmill);
    expect(of('Stationary Bike (Fast)'), CardioMachine.bike);
    expect(of('Assault Bike'), CardioMachine.bike);
    expect(of('Rowing Machine'), CardioMachine.rower);
    expect(of('Ski Erg'), CardioMachine.rower);
    expect(of('StairMaster (Stepmill)'), CardioMachine.stairs);
    expect(of('Elliptical'), CardioMachine.elliptical);
    expect(of('Jumping Jacks'), CardioMachine.other);
    expect(CardioMachine.treadmill.fields,
        [CardioField.distance, CardioField.incline, CardioField.calories]);
    expect(CardioMachine.stairs.fields, isNot(contains(CardioField.distance)));
  });

  test('pace, speed and split are worked out, never typed', () {
    expect(
        CardioPace.summary(
            machine: CardioMachine.treadmill,
            seconds: 30 * 60,
            distanceKm: 3 * 1.609344,
            miles: true),
        '10:00 /mi · 6.0 mph');
    expect(
        CardioPace.summary(
            machine: CardioMachine.rower,
            seconds: 8 * 60,
            distanceKm: 2,
            miles: true),
        '2:00 /500m',
        reason: 'rowers use metres whatever the unit setting');
    expect(
        CardioPace.summary(
            machine: CardioMachine.bike,
            seconds: 30 * 60,
            distanceKm: 15,
            miles: false),
        '30.0 km/h');
    expect(
        CardioPace.summary(
            machine: CardioMachine.treadmill,
            seconds: 0,
            distanceKm: 5,
            miles: false),
        isNull);
    expect(CardioPace.clock(3725), '1:02:05');
  });

  test('a cardio exercise is one session with a stopwatch', () async {
    var now = DateTime(2026, 11, 12, 7);
    final notifier = await setUp(() => now);
    notifier.startWorkout();
    notifier.addExercise(cardio('sm:rowing-machine', 'Rowing Machine'));
    final log = notifier.currentWorkout!.exercises.single;
    expect(log.sets, hasLength(1), reason: 'no sets for cardio');

    notifier.startCardio('sm:rowing-machine');
    expect(notifier.isCardioRunning('sm:rowing-machine'), isTrue);
    now = now.add(const Duration(minutes: 40));
    expect(notifier.cardioSeconds('sm:rowing-machine'), 40 * 60);
    notifier.onAppResumed();
    expect(notifier.isTimerPaused, isFalse,
        reason: 'a long session is not idle time');

    notifier.stopCardio('sm:rowing-machine');
    expect(log.sets.single.durationSeconds, 40 * 60);
    expect(log.sets.single.isCompleted, isTrue);

    // Resume adds to the time.
    notifier.startCardio('sm:rowing-machine');
    now = now.add(const Duration(minutes: 5));
    notifier.stopAllCardio();
    expect(log.sets.single.durationSeconds, 45 * 60);

    notifier.updateCardio('sm:rowing-machine', (set) {
      set.durationSeconds = null;
      set.distance = null;
    });
    expect(log.sets.single.isCompleted, isFalse,
        reason: 'nothing logged until there is a time or distance');
    notifier.resetWorkout();
    notifier.dispose();
  });

  Future<WorkoutNotifier> pumpCard(
      WidgetTester tester, Exercise exercise, DateTime Function() clock) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late WorkoutNotifier notifier;
    await tester.runAsync(() async => notifier = await setUp(clock));
    notifier.startWorkout();
    notifier.addExercise(exercise);
    final prefs = Preferences()
      ..value = const UserSettings(distanceUnit: DistanceUnit.miles);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutNotifier>.value(value: notifier),
        ChangeNotifierProvider<SettingsNotifier>.value(value: prefs),
      ],
      child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
              body: Consumer<WorkoutNotifier>(
                  builder: (_, w, __) => SingleChildScrollView(
                      child: CardioSessionCard(
                          exercise: exercise,
                          log: w.currentWorkout!.exercises.single,
                          exerciseIndex: 0))))),
    ));
    await tester.pump();
    return notifier;
  }

  testWidgets('treadmill card: start, stop, then what the machine shows',
      (tester) async {
    var now = DateTime(2026, 11, 12, 7);
    final notifier = await pumpCard(
        tester, cardio('gg:cardio/run-equipment', 'Treadmill Run'), () => now);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Add Set'), findsNothing);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Incline'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('mi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cardio-start-stop')));
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);
    now = now.add(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30:00'), findsOneWidget, reason: 'stopwatch runs');
    await tester.tap(find.byKey(const ValueKey('cardio-start-stop')));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Logged'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('cardio-distance')), '3');
    await tester.enterText(
        find.byKey(const ValueKey('cardio-calories')), '320');
    await tester.pump();
    expect(find.text('10:00 /mi · 6.0 mph'), findsOneWidget);
    final set = notifier.currentWorkout!.exercises.single.sets.single;
    expect((set.distance, set.distanceUnit, set.calories, set.speed),
        (3.0, 'mi', 320, 6.0));
    expect(tester.takeException(), isNull);
    notifier.resetWorkout();
  });

  testWidgets('rower card counts metres and shows the split', (tester) async {
    final now = DateTime(2026, 11, 12, 7);
    final notifier = await pumpCard(
        tester, cardio('sm:rowing-machine', 'Rowing Machine'), () => now);
    expect(find.text('m'), findsOneWidget);
    expect(find.text('Incline'), findsNothing);
    notifier.updateCardio('sm:rowing-machine', (s) => s.durationSeconds = 480);
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('cardio-distance')), '2000');
    await tester.pump();
    expect(find.text('2:00 /500m'), findsOneWidget);
    final set = notifier.currentWorkout!.exercises.single.sets.single;
    expect((set.distance, set.distanceUnit), (2.0, 'km'));
    notifier.resetWorkout();
  });

  test('calories are saved and read back', () {
    final set = WorkoutSet.fromJson(
        WorkoutSet(durationSeconds: 60, calories: 120).toJson());
    expect(set.calories, 120);
  });
}
