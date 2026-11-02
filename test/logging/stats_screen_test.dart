import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/screens/stats_screen.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'home_test.dart' show Workouts, Settings;

void main() {
  for (final period in ['Month', 'Year']) {
    testWidgets(
        '$period calendar selection applies and cancel preserves period',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
      ], child: MaterialApp(theme: lightTheme, home: const StatsScreen())));
      if (period == 'Year') {
        await tester.tap(find.text('Year'));
        await tester.pumpAndSettle();
      }

      Future<void> enterDate(String date, {required bool save}) async {
        await tester.tap(find.byTooltip('Choose period'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), date);
        await tester.tap(find.text(save ? 'OK' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }

      final selectedYear = DateTime.now().year - 1;
      final expectedPeriod =
          period == 'Month' ? 'January $selectedYear' : '$selectedYear';
      await enterDate('01/15/$selectedYear', save: true);
      expect(find.text(expectedPeriod), findsOneWidget);

      await enterDate('02/15/${selectedYear - 1}', save: false);
      expect(find.text(expectedPeriod), findsOneWidget);
    });
  }

  testWidgets('stats fits a narrow screen and month navigation stays bounded',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Settings()),
    ], child: MaterialApp(theme: ThemeData.dark(), home: const StatsScreen())));
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Next month'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Next month'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Next month'))
            .onPressed,
        isNull);
    expect(find.text('Lifting volume'), findsNothing);
    for (final unsupportedMetric in [
      'Heart Points',
      'Steps',
      'Sleep',
      'Calories'
    ]) {
      expect(find.text(unsupportedMetric), findsNothing);
    }
    const details = {
      'Workouts': 'Showing up',
      'Time': 'Average workout',
      'Personal Records': 'All-time bests',
      'Strength': 'Lifting volume',
      'Cardio': 'Recorded distance',
      'Muscles': 'Your muscle breakdown starts with your first completed sets.',
      'Active days': 'Showing up',
    };
    for (final entry in details.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      await tester.scrollUntilVisible(find.text(entry.value), 160,
          scrollable: find.descendant(
              of: find.byType(DraggableScrollableSheet),
              matching: find.byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    }
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Year'), -200,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    final nextYear = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Next year');
    expect(tester.widget<IconButton>(nextYear).onPressed, isNull);
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(nextYear).onPressed, isNotNull);
    await tester.tap(find.text('This year'));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(nextYear).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
