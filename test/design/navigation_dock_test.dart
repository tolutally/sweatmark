import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'package:sweatmark/widgets/app_shell.dart';

void main() {
  for (final theme in [lightTheme, darkTheme]) {
    testWidgets('navigation dock remains usable in ${theme.brightness}',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? selected;
      var starts = 0;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            bottomNavigationBar: AppNavigationDock(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
              onWorkoutPressed: () => starts++,
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      for (final destination
          in {'Home': 0, 'History': 2, 'Browse': 1, 'Stats': 3}.entries) {
        final button =
            find.byKey(ValueKey('navigation-${destination.key.toLowerCase()}'));
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        await tester.tap(button);
        expect(selected, destination.value);
      }
      await tester.tap(find.byKey(const ValueKey('navigation-workout-action')));
      expect(starts, 1);
      expect(selected, 3); // Center action does not change the selected tab.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('raised action remains reachable above the full-width bar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var resumed = false;
    await tester.pumpWidget(MaterialApp(
        theme: lightTheme,
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(390, 844), viewPadding: EdgeInsets.only(bottom: 34)),
            child: Scaffold(
                bottomNavigationBar: AppNavigationDock(
                    selectedIndex: 2,
                    isWorkoutActive: true,
                    onSelected: (_) {},
                    onWorkoutPressed: () => resumed = true)))));
    final surface =
        tester.getRect(find.byKey(const ValueKey('navigation-surface')));
    final action =
        tester.getRect(find.byKey(const ValueKey('navigation-workout-action')));
    expect(surface.width, 390);
    expect(action.top, lessThan(surface.top));
    expect(action.center.dx, surface.center.dx);
    expect(find.byTooltip('Resume workout'), findsOneWidget);
    // Verify the raised portion is inside the hit-test bounds, not just painted.
    await tester.tapAt(Offset(action.center.dx, action.top + 8));
    expect(resumed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
