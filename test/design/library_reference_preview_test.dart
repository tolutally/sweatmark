import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/screens/library_screen.dart';
import 'package:sweatmark/state/exercise_db_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/app_shell.dart';

import '../logging/home_test.dart' show Workouts;
import 'library_design_test.dart';

Future<void> _capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_DESIGN')) return;
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/sweatmark-library-reference-$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(initializeLibraryTestEnvironment);
  for (final theme in [lightTheme, darkTheme]) {
    final mode = theme.brightness.name;
    testWidgets('$mode Browse and filter sheets render with real fonts',
        (tester) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      libraryPhone(tester);
      final workouts = Workouts();
      final catalog = ExerciseDbNotifier(LibraryCatalogRepository());
      addTearDown(catalog.dispose);
      addTearDown(workouts.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: libraryTestApp(
              catalog: catalog,
              workouts: workouts,
              theme: theme,
              home: Scaffold(
                  body: const LibraryScreen(),
                  bottomNavigationBar: AppNavigationDock(
                      selectedIndex: 1,
                      onSelected: (_) {},
                      onWorkoutPressed: () {})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'overview-$mode');
      for (final entry in {
        'Any Muscle': 'muscles',
        'Any Equipment': 'equipment',
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, boundary, '${entry.value}-$mode');
        await tester.tap(find.byTooltip('Close filters'));
        await tester.pumpAndSettle();
      }
      debugDisableShadows = true;
    });
  }
}
