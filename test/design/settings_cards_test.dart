import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/user_settings.dart';
import 'package:sweatmark/models/weekly_progress.dart';
import 'package:sweatmark/screens/settings_screen.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';

import '../logging/settings_screen_test.dart' show Preferences;

Future<void> _pumpSettings(WidgetTester tester, Preferences preferences,
    {ThemeData? theme,
    Size size = const Size(390, 844),
    double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<SettingsNotifier>.value(
      value: preferences,
      child: MaterialApp(
          theme: theme ?? lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true),
              child: child!),
          home: const SettingsScreen())));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder,
    {double delta = 120}) async {
  await tester.scrollUntilVisible(finder, delta,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

ChoiceChip _timerChip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('General Sans');
    for (final style in ['Regular', 'Medium', 'Semibold', 'Bold']) {
      fonts.addFont(
          rootBundle.load('assets/fonts/general_sans/GeneralSans-$style.otf'));
    }
    await fonts.load();
  });

  testWidgets('unit cards retain direct selections and existing settings only',
      (tester) async {
    final preferences = Preferences();
    await _pumpSettings(tester, preferences);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget.runtimeType.toString().startsWith('DropdownButton') ||
            widget.runtimeType.toString().startsWith('DropdownMenu')),
        findsNothing);
    for (final unsupported in [
      'Height',
      'Energy',
      'Track your activities',
      'Use your location'
    ]) {
      expect(find.text(unsupported), findsNothing);
    }

    for (final unit in ['kg', 'lb']) {
      await tester.tap(find.text(unit));
      await tester.pumpAndSettle();
      expect(preferences.value.weightUnit,
          unit == 'kg' ? WeightUnit.kg : WeightUnit.lb);
    }
    for (final unit in ['km', 'mi']) {
      await tester.tap(find.text(unit));
      await tester.pumpAndSettle();
      expect(preferences.value.distanceUnit,
          unit == 'km' ? DistanceUnit.kilometers : DistanceUnit.miles);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'preferences preserve timer choices and independently toggle haptics',
      (tester) async {
    final preferences = Preferences()..duration = 75;
    await _pumpSettings(tester, preferences);
    await _reveal(tester, find.text('75s'));
    expect(_timerChip(tester, '75s').selected, isTrue);
    await tester.tap(find.text('90s'));
    await tester.pumpAndSettle();
    expect(preferences.duration, 90);
    expect(_timerChip(tester, '90s').selected, isTrue);

    await _reveal(tester, find.byType(CupertinoSwitch).first, delta: -120);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(preferences.duration, 0);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    expect(preferences.duration, 60);
    await _reveal(tester, find.text('60s'));
    expect(_timerChip(tester, '60s').selected, isTrue);

    await _reveal(tester, find.byType(CupertinoSwitch).last);
    await tester.tap(find.byType(CupertinoSwitch).last);
    await tester.pumpAndSettle();
    expect(preferences.haptics, isFalse);
    expect(preferences.duration, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact switches keep a 44px tap target around their track',
      (tester) async {
    final preferences = Preferences();
    await _pumpSettings(tester, preferences);
    final target = find
        .ancestor(
            of: find.byType(CupertinoSwitch).first,
            matching: find.byWidgetPredicate((widget) =>
                widget is GestureDetector &&
                widget.behavior == HitTestBehavior.opaque))
        .first;
    final rect = tester.getRect(target);
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(preferences.duration, 0);
  });

  testWidgets('calendar shortcut reveals goal and stepper schedules next week',
      (tester) async {
    final currentWeek = weekStart(DateTime.now());
    final nextWeek =
        DateTime(currentWeek.year, currentWeek.month, currentWeek.day + 7);
    final preferences = Preferences()
      ..value = UserSettings(weeklyGoals: {weekKey(currentWeek): 3});
    await _pumpSettings(tester, preferences);
    await tester.tap(find.byTooltip('Weekly workout goal'));
    await tester.pumpAndSettle();
    expect(
        find.byTooltip('Increase weekly goal').hitTestable(), findsOneWidget);
    expect(
        find.text('3 this week. Changes start next Monday.'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase weekly goal'));
    await tester.pumpAndSettle();
    expect(goalForWeek(preferences.value.weeklyGoals, currentWeek), 3);
    expect(goalForWeek(preferences.value.weeklyGoals, nextWeek), 4);
    await tester.tap(find.byTooltip('Decrease weekly goal'));
    await tester.pumpAndSettle();
    expect(goalForWeek(preferences.value.weeklyGoals, nextWeek), 3);
    expect(tester.takeException(), isNull);
  });

  for (final goal in [1, 14]) {
    testWidgets('weekly goal cannot move beyond boundary $goal',
        (tester) async {
      final preferences = Preferences()
        ..value = UserSettings(weeklyGoals: {weekKey(DateTime.now()): goal});
      await _pumpSettings(tester, preferences);
      await tester.tap(find.byTooltip('Weekly workout goal'));
      await tester.pumpAndSettle();
      final boundary = goal == 1 ? 'Decrease' : 'Increase';
      final button = tester.widget<IconButton>(find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == '$boundary weekly goal'));
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  for (final theme in {'light': lightTheme, 'dark': darkTheme}.entries) {
    testWidgets(
        'settings cards remain usable at 320px and 1.5x in ${theme.key}',
        (tester) async {
      final preferences = Preferences()..duration = 75;
      await _pumpSettings(tester, preferences,
          theme: theme.value, size: const Size(320, 740), textScale: 1.5);
      expect(tester.takeException(), isNull);
      for (final label in ['kg', 'km', '75s', 'Haptic Feedback', 'Sign out']) {
        await _reveal(tester, find.text(label));
        expect(tester.takeException(), isNull);
        expect(
            tester
                .getRect(find.byType(SingleChildScrollView))
                .contains(tester.getCenter(find.text(label))),
            isTrue,
            reason: '$label should remain visible after scrolling');
      }
    });
  }
}
