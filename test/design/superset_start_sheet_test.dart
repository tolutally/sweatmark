import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/ai/ai_workers.dart';
import 'package:sweatmark/data/exercise_catalog.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/superset_start_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bench = WorkoutExerciseLog(
      exerciseId: 'bench',
      exerciseName: 'Barbell Bench Press',
      muscleGroup: 'Chest',
      equipment: 'Barbell',
      sets: []);
  final curl = WorkoutExerciseLog(
      exerciseId: 'curl',
      exerciseName: 'Dumbbell Curl',
      muscleGroup: 'Biceps',
      sets: []);

  Future<List<SupersetChoice?>> pump(WidgetTester tester, AiWorkers ai,
      {List<WorkoutExerciseLog> inWorkout = const []}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final choices = <SupersetChoice?>[];
    await tester.pumpWidget(MaterialApp(
      theme: lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => choices.add(await showSupersetStartSheet(
                  context,
                  current: bench,
                  inWorkout: inWorkout,
                  ai: ai)),
              child: const Text('Superset'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Superset'));
    await tester.pumpAndSettle();
    return choices;
  }

  testWidgets('the library comes first', (tester) async {
    final choices = await pump(tester, AiWorkers(call: (_, __) async => {}));
    expect(find.text('Superset with…'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('superset-library')));
    await tester.pumpAndSettle();
    expect(choices.single, isA<SupersetFromLibrary>());
  });

  testWidgets('an exercise already in the workout can be paired',
      (tester) async {
    final choices = await pump(tester, AiWorkers(call: (_, __) async => {}),
        inWorkout: [curl]);
    expect(find.text('In this workout'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('superset-logged-curl')));
    await tester.pumpAndSettle();
    expect((choices.single as SupersetWithLogged).exerciseId, 'curl');
  });

  testWidgets('AI suggests partners for the kind you pick', (tester) async {
    final exercises =
        await tester.runAsync(() => ExerciseCatalog.load(bundle: rootBundle));
    final partner = exercises!.firstWhere(
        (e) => e.name == 'Barbell Bent-Over Row',
        orElse: () => exercises.first);
    final calls = <(String, Map<String, dynamic>)>[];
    final ai = AiWorkers(call: (worker, input) async {
      calls.add((worker, input));
      return {
        'matches': [
          {
            'id': partner.id,
            'reason': 'Works your back while your chest rests'
          },
          {'id': 'not-in-library', 'reason': 'ignored'},
        ],
        'customExercise': null,
      };
    });
    final choices = await pump(tester, ai, inWorkout: [curl]);
    await tester.ensureVisible(find.byKey(const ValueKey('ai-alternate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-alternate')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'supersetPartner');
    expect(calls.single.$2['mode'], 'alternate');
    expect(calls.single.$2['exercise'], 'Barbell Bench Press');
    expect(calls.single.$2['exclude'], ['bench', 'curl']);
    expect(find.text('Works your back while your chest rests'), findsOneWidget);
    final row = find.byKey(ValueKey('superset-ai-${partner.id}'));
    await tester.scrollUntilVisible(row, 120,
        scrollable: find
            .descendant(
                of: find.byType(SupersetStartSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect((choices.single as SupersetWithExercise).exercise.id, partner.id);
  });

  testWidgets('when AI is unavailable the sheet says so and keeps working',
      (tester) async {
    final ai = AiWorkers(
        call: (_, __) async =>
            throw const AiUnavailable('AI is busy. Try again.'));
    await pump(tester, ai);
    await tester.ensureVisible(find.byKey(const ValueKey('ai-same')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-same')));
    await tester.pumpAndSettle();
    expect(find.text('AI is busy. Try again.'), findsOneWidget);
    expect(find.byKey(const ValueKey('superset-library')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
