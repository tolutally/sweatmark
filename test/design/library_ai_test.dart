import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/ai/ai_workers.dart';
import 'package:sweatmark/screens/create_exercise_screen.dart';
import 'package:sweatmark/screens/library_screen.dart';
import 'package:sweatmark/state/exercise_db_notifier.dart';

import '../logging/home_test.dart' show Workouts;
import 'library_design_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(initializeLibraryTestEnvironment);

  Future<ExerciseDbNotifier> pump(WidgetTester tester, AiWorkers ai) async {
    libraryPhone(tester);
    final workouts = Workouts();
    final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
    addTearDown(catalog.dispose);
    addTearDown(workouts.dispose);
    await tester.pumpWidget(libraryTestApp(
        catalog: catalog,
        workouts: workouts,
        home: LibraryScreen(aiWorkers: ai)));
    await tester.pumpAndSettle();
    return catalog;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('AI is offered only when search finds little, and only on tap',
      (tester) async {
    final calls = <Map<String, dynamic>>[];
    await pump(tester, AiWorkers(call: (worker, input) async {
      calls.add({'worker': worker, ...input});
      return {
        'matches': [
          {'id': 'dumbbell', 'reason': 'Same chest movement with dumbbells'},
          {'id': 'not-in-library', 'reason': 'Ignored'},
        ],
        'customExercise': null,
      };
    }));

    await search(tester, 'machine');
    expect(find.text('Ask AI'), findsNothing,
        reason: 'enough library results already');

    await search(tester, 'pec deck');
    expect(find.text('Ask AI'), findsOneWidget);
    expect(calls, isEmpty, reason: 'never called without a tap');

    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    expect(calls.single['worker'], 'exerciseSearch');
    expect(calls.single['query'], 'pec deck');
    expect(find.text('Suggested by AI'), findsOneWidget);
    expect(find.text('Dumbbell Bench Press'), findsOneWidget);
    expect(find.text('Same chest movement with dumbbells'), findsOneWidget);
    expect(find.text('Ignored'), findsNothing,
        reason: 'IDs missing from the library are dropped');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom suggestion opens Create with the details filled in',
      (tester) async {
    await pump(
        tester,
        AiWorkers(
            call: (_, __) async => {
                  'matches': [],
                  'customExercise': {
                    'name': 'Face Pull',
                    'muscleGroup': 'Shoulders',
                    'equipment': 'Cable'
                  },
                }));
    await search(tester, 'face pull');
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    expect(find.text('Create “Face Pull”'), findsOneWidget);
    await tester.tap(find.text('Create “Face Pull”'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateExerciseScreen), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Face Pull'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when AI is unavailable the library keeps working',
      (tester) async {
    await pump(
        tester,
        AiWorkers(
            call: (_, __) async => throw const AiUnavailable(
                'AI search isn’t available right now.')));
    await search(tester, 'pec deck');
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    expect(find.text('AI search isn’t available right now.'), findsOneWidget);
    await search(tester, 'bench');
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
