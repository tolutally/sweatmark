import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/data/exercise_db_repository.dart';
import 'package:sweatmark/models/exercise_model.dart';
import 'package:sweatmark/screens/create_exercise_screen.dart';
import 'package:sweatmark/screens/exercise_info_screen.dart';
import 'package:sweatmark/screens/library_screen.dart';
import 'package:sweatmark/state/exercise_db_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/home_test.dart' show Settings, Workouts;

const libraryLongName =
    'Incline Dumbbell Fly with Alternating Single Arm Repetitions';

List<Exercise> libraryFixtures() => [
      for (final entry in [
        ['bench', 'Barbell Bench Press', 'chest', 'barbell'],
        ['row', 'Barbell Row', 'back', 'barbell'],
        ['dumbbell', 'Dumbbell Bench Press', 'chest', 'dumbbell'],
        [
          'inner-hip',
          'Hip Adduction Machine (Inner Thigh)',
          'upper legs',
          'machine'
        ],
        ['long-name', libraryLongName, 'chest', 'dumbbell'],
        ['run', 'Treadmill Run', 'cardio', 'machine'],
        [
          'outer-hip',
          'Weighted Hip Abduction Machine (Outer Thigh)',
          'upper legs',
          'machine'
        ],
      ])
        Exercise(
            id: entry[0],
            name: entry[1],
            muscleGroup: entry[2],
            equipment: entry[3],
            instructions:
                'Set up in a comfortable starting position.\nComplete the movement with control.'),
    ];

/// Keeps the real notifier's loading/debounce/short-query behavior under test.
/// Only its offline exercise data boundary is replaced.
class LibraryCatalogRepository implements ExerciseDbRepository {
  LibraryCatalogRepository([List<Exercise>? exercises])
      : catalog = exercises ?? libraryFixtures();
  final List<Exercise> catalog;
  final List<String?> queries = [];

  @override
  Future<List<Exercise>> searchExercises(
      {String? query,
      String? bodyPart,
      String? equipment,
      int limit = 500}) async {
    queries.add(query);
    final term = query?.toLowerCase() ?? '';
    return catalog
        .where((exercise) =>
            (term.isEmpty ||
                exercise.name.toLowerCase().contains(term) ||
                exercise.muscleGroup.toLowerCase().contains(term) ||
                exercise.equipment.toLowerCase().contains(term)) &&
            (bodyPart == null ||
                exercise.muscleGroup.toLowerCase() == bodyPart.toLowerCase()) &&
            (equipment == null ||
                exercise.equipment.toLowerCase() == equipment.toLowerCase()))
        .take(limit)
        .toList();
  }

  @override
  Future<List<String>> getBodyParts() async =>
      catalog.map((exercise) => exercise.muscleGroup).toSet().toList()..sort();

  @override
  Future<List<String>> getEquipmentList() async =>
      catalog.map((exercise) => exercise.equipment).toSet().toList()..sort();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> initializeLibraryTestEnvironment() async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final listener in [
    'registerIdTokenListener',
    'registerAuthStateListener'
  ]) {
    final events = 'test.library.auth.$listener';
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.$listener',
        (_) async => const StandardMessageCodec().encodeMessage([events]));
    messenger.setMockMethodCallHandler(
        MethodChannel(events), (_) async => null);
  }
  await Firebase.initializeApp();
  final fonts = FontLoader('General Sans');
  for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
    fonts.addFont(
        rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
  }
  await fonts.load();
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await material.load();
  for (final name in ['Regular', 'Bold', 'Fill']) {
    final icons = FontLoader('packages/phosphor_icons/Phosphor$name')
      ..addFont(rootBundle.load(
          'packages/phosphor_icons/lib/fonts/Phosphor${name == 'Regular' ? '' : '-$name'}.ttf'));
    await icons.load();
  }
}

Widget libraryTestApp(
        {required ExerciseDbNotifier catalog,
        required Workouts workouts,
        required Widget home,
        ThemeData? theme,
        double textScale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<ExerciseDbNotifier>.value(value: catalog),
          ChangeNotifierProvider<WorkoutNotifier>.value(value: workouts),
          ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme ?? lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: home));

void libraryPhone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> searchLibrary(WidgetTester tester, String term) async {
  await tester.enterText(find.byType(TextField), term);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(initializeLibraryTestEnvironment);

  testWidgets('Browse info and custom exercise entry do not start workouts',
      (tester) async {
    libraryPhone(tester);
    final workouts = Workouts();
    final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
    addTearDown(catalog.dispose);
    addTearDown(workouts.dispose);
    await tester.pumpWidget(libraryTestApp(
        catalog: catalog, workouts: workouts, home: const LibraryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Info for Barbell Bench Press'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseInfoScreen), findsOneWidget);
    expect(find.text('Set up in a comfortable starting position.'),
        findsOneWidget);
    expect(workouts.starts, 0);
    await tester.tap(find.byTooltip('Close exercise info'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    await tester.tap(find.text('Create Custom Exercise…'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateExerciseScreen), findsOneWidget);
    expect(workouts.starts, 0);
    Navigator.of(tester.element(find.byType(CreateExerciseScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(catalog.exercises, hasLength(libraryFixtures().length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker info stays open and row selection returns the exercise',
      (tester) async {
    libraryPhone(tester);
    final workouts = Workouts();
    final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
    addTearDown(catalog.dispose);
    addTearDown(workouts.dispose);
    Exercise? selected;
    await tester.pumpWidget(libraryTestApp(
        catalog: catalog,
        workouts: workouts,
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: FilledButton(
                        onPressed: () async {
                          selected = await Navigator.push<Exercise>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const LibraryScreen(isPicker: true)));
                        },
                        child: const Text('Pick exercise')))))));
    await tester.tap(find.text('Pick exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Choose exercises'), findsOneWidget);
    await tester.tap(find.byTooltip('Info for Barbell Bench Press'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseInfoScreen), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.byTooltip('Close exercise info'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'bench');
    expect(find.byType(LibraryScreen), findsNothing);
    expect(workouts.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search, muscle, and equipment filters intersect and clear cleanly',
      (tester) async {
    libraryPhone(tester);
    final workouts = Workouts();
    final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
    addTearDown(catalog.dispose);
    addTearDown(workouts.dispose);
    await tester.pumpWidget(libraryTestApp(
        catalog: catalog, workouts: workouts, home: const LibraryScreen()));
    await tester.pumpAndSettle();

    await searchLibrary(tester, 'bench');
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Dumbbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsNothing);
    await tester.tap(find.text('Any Muscle'));
    await tester.pumpAndSettle();
    expect(find.text('Muscle group'), findsOneWidget);
    // Options still come from the whole catalog while search narrows rows.
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Cardio'), findsOneWidget);
    await tester.tap(find.text('Chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any Equipment'));
    await tester.pumpAndSettle();
    expect(find.text('Machine'), findsOneWidget);
    await tester.tap(find.text('Barbell'));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Dumbbell Bench Press'), findsNothing);
    expect(find.text('Barbell Row'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Dumbbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(catalog.exercises, hasLength(libraryFixtures().length));
    await searchLibrary(tester, 'b');
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('Treadmill Run'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets(
        '${theme.brightness.name} Browse and filters fit narrow large text',
        (tester) async {
      libraryPhone(tester, size: const Size(320, 844));
      final workouts = Workouts();
      final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
      addTearDown(catalog.dispose);
      addTearDown(workouts.dispose);
      await tester.pumpWidget(libraryTestApp(
          catalog: catalog,
          workouts: workouts,
          theme: theme,
          textScale: 1.5,
          home: const LibraryScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Any Muscle'));
      await tester.pumpAndSettle();
      expect(find.text('Muscle group'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any Equipment'));
      await tester.pumpAndSettle();
      expect(find.text('Equipment'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      await searchLibrary(tester, 'Incline');
      expect(find.text(libraryLongName), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Info for $libraryLongName'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseInfoScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
