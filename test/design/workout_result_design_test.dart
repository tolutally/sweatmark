import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// SharePlus exposes share data publicly, but its native test hook lives here.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/workout_summary_screen.dart';
import 'package:sweatmark/state/auth_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/home_test.dart' show Settings, Workouts;

const _privateEmail = 'private-account@example.com';
const _privateNotes = 'Private workout note that must never be exported.';
const _workoutName = 'Upper body strength and accessory conditioning session';

class _User implements User {
  @override
  String get displayName => 'Tolu Test';
  @override
  String get email => _privateEmail;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthNotifier {
  @override
  User get user => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends Settings {
  @override
  String get distanceSuffix => 'km';
  @override
  UserSettings get userSettings => const UserSettings(
      weightUnit: WeightUnit.kg, distanceUnit: DistanceUnit.kilometers);
}

class _SavedWorkouts extends Workouts {
  _SavedWorkouts(this.workout);
  final WorkoutLog workout;
  @override
  List<WorkoutLog> get workoutHistory => [
        WorkoutLog(
            workoutName: 'Previous session',
            timestamp: workout.timestamp.subtract(const Duration(days: 7)),
            durationSeconds: 1800,
            exercises: [
              WorkoutExerciseLog(
                  exerciseId: 'exercise-0',
                  exerciseName: workout.exercises.first.exerciseName,
                  exerciseType: 'weightedStrength',
                  sets: [
                    WorkoutSet(
                        weight: 40,
                        weightUnit: 'kg',
                        reps: 8,
                        isCompleted: true)
                  ])
            ]),
        workout,
      ];
}

class _NativeShare extends SharePlatform {
  bool fail = false;
  final calls = <ShareParams>[];
  final images = <Uint8List>[];
  Completer<void> nextCall = Completer<void>();

  void reset() {
    fail = false;
    calls.clear();
    images.clear();
    nextCall = Completer<void>();
  }

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    images.add(await params.files!.single.readAsBytes());
    if (!nextCall.isCompleted) nextCall.complete();
    if (fail) throw PlatformException(code: 'test-share-unavailable');
    return const ShareResult('test', ShareResultStatus.success);
  }
}

WorkoutLog _workout({int exerciseCount = 12}) => WorkoutLog(
      workoutName: _workoutName,
      timestamp: DateTime(2026, 11, 1, 9, 30),
      durationSeconds: 3720,
      notes: _privateNotes,
      exercises: List.generate(
          exerciseCount,
          (index) => WorkoutExerciseLog(
                  exerciseId: 'exercise-$index',
                  exerciseName:
                      'Exercise ${index + 1}: Alternating Incline Dumbbell Press with Controlled Repetitions',
                  exerciseType: 'weightedStrength',
                  muscleGroup: 'chest',
                  equipment: 'dumbbell',
                  sets: [
                    WorkoutSet(
                        weight: 50 + index.toDouble(),
                        weightUnit: 'kg',
                        reps: 8,
                        isCompleted: true),
                    WorkoutSet(
                        weight: 50 + index.toDouble(),
                        weightUnit: 'kg',
                        reps: 6,
                        isCompleted: true),
                    WorkoutSet(weight: 100, weightUnit: 'kg', reps: 10),
                  ])),
    );

Future<void> _pumpResult(WidgetTester tester,
    {required WorkoutLog workout,
    ThemeData? theme,
    Size size = const Size(390, 844),
    double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutNotifier>(
            create: (_) => _SavedWorkouts(workout)),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => _Settings()),
        ChangeNotifierProvider<AuthNotifier>(create: (_) => _Auth()),
      ],
      child: MaterialApp(
          theme: theme ?? lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: WorkoutSummaryScreen(completedWorkout: workout))));
  await tester.pumpAndSettle();
}

Finder _exportedCard() => find.byKey(const ValueKey('workout-share-card'));

Future<void> _prepareShare(WidgetTester tester, _NativeShare share) async {
  // PNG rasterization runs on the engine, outside the fake test clock.
  await tester.runAsync(() async {
    share.nextCall = Completer<void>();
    await tester.tap(find.text('Share or save image'));
    await tester.pump();
    await share.nextCall.future.timeout(const Duration(seconds: 10));
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final share = _NativeShare();
  late SharePlatform originalShare;
  setUpAll(() async {
    originalShare = SharePlatform.instance;
    SharePlatform.instance = share;
    final fonts = FontLoader('General Sans');
    for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
    }
    await fonts.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
  });
  setUp(share.reset);
  tearDownAll(() => SharePlatform.instance = originalShare);

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets(
        '${theme.brightness.name} summary and share fit narrow large text',
        (tester) async {
      final workout = _workout(exerciseCount: 4);
      await _pumpResult(tester,
          workout: workout,
          theme: theme,
          size: const Size(320, 844),
          textScale: 1.5);
      expect(find.text('S W E A T M A R K'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Share workout'));
      await tester.pumpAndSettle();
      expect(find.text('Share result'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final card = _exportedCard();
      expect(
          find.descendant(of: card, matching: find.textContaining('Tolu Test')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(_privateEmail)),
          findsNothing);
      expect(find.descendant(of: card, matching: find.text(_privateNotes)),
          findsNothing);
      expect(find.descendant(of: card, matching: find.byType(TextField)),
          findsNothing);
      // The image keeps the summary's totals, not its exercise list.
      expect(
          find.descendant(
              of: card,
              matching: find.text(workout.exercises.last.exerciseName!)),
          findsNothing);
      expect(find.descendant(of: card, matching: find.text('Top set')),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.descendant(of: card, matching: find.text('Chest')), 220,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close share preview'));
      await tester.pumpAndSettle();
      expect(find.text('Share result'), findsNothing);
      expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.byWidgetPredicate((widget) =>
                  widget is IconButton && widget.tooltip == 'Share workout'))
              .onPressed,
          isNotNull);
      expect(share.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'native share receives the full PNG and a failed attempt can retry',
      (tester) async {
    final workout = _workout();
    await _pumpResult(tester, workout: workout);
    await tester.tap(find.byTooltip('Share workout'));
    await tester.pumpAndSettle();
    final card = _exportedCard();
    final boundary = tester.renderObject<RenderRepaintBoundary>(card);
    expect(find.descendant(of: card, matching: find.text('Chest')),
        findsOneWidget);
    // The footer is the last thing painted; it must reach the PNG.
    final lastRow = tester.renderObject<RenderBox>(
        find.descendant(of: card, matching: find.text('Tracked with')));
    final lastRowOffset =
        boundary.globalToLocal(lastRow.localToGlobal(Offset.zero));

    share.fail = true;
    await _prepareShare(tester, share);
    expect(share.calls, hasLength(1));
    expect(find.text('Could not share this image. Please try again.'),
        findsOneWidget);
    expect(find.text('Share or save image'), findsOneWidget);

    share.fail = false;
    await _prepareShare(tester, share);
    expect(share.calls, hasLength(2));
    expect(find.text('Could not share this image. Please try again.'),
        findsNothing);
    final params = share.calls.last;
    expect(params.files!.single.mimeType, 'image/png');
    expect(params.title, _workoutName);
    expect(params.text, isNull);
    expect(params.subject, isNull);
    expect(params.fileNameOverrides!.single, endsWith('.png'));
    expect(params.sharePositionOrigin!.width, greaterThan(0));
    final bytes = share.images.last;
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final ratio = image.width / boundary.size.width;
        expect(image.height, closeTo(boundary.size.height * ratio, 2));
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var inkPixels = 0;
        final left = (lastRowOffset.dx * ratio).ceil();
        final top = (lastRowOffset.dy * ratio).ceil();
        final right = ((lastRowOffset.dx + lastRow.size.width) * ratio).floor();
        final bottom =
            ((lastRowOffset.dy + lastRow.size.height) * ratio).floor();
        expect(bottom, lessThan(image.height));
        for (var y = top; y < bottom; y++) {
          for (var x = left; x < right; x++) {
            final offset = (y * image.width + x) * 4;
            if (pixels.getUint8(offset) < 160 &&
                pixels.getUint8(offset + 1) < 160 &&
                pixels.getUint8(offset + 2) < 160 &&
                pixels.getUint8(offset + 3) > 200) {
              inkPixels++;
            }
          }
        }
        expect(inkPixels, greaterThan(20),
            reason: 'The footer text is painted in the exported PNG.');
      } finally {
        image.dispose();
        codec.dispose();
      }
    });
    await tester.tap(find.byTooltip('Close share preview'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
