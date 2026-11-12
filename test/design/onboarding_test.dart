import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweatmark/screens/onboarding_screen.dart';
import 'package:sweatmark/theme/app_theme.dart';

Future<int> _pump(WidgetTester tester,
    {ThemeData? theme,
    Size size = const Size(390, 844),
    double text = 1}) async {
  var done = 0;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? lightTheme,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(text)),
        child: child!),
    home: RepaintBoundary(child: OnboardingScreen(onDone: () => done++)),
  ));
  await tester.pumpAndSettle();
  return done;
}

Future<void> _capture(WidgetTester tester, String name) async {
  const dir = String.fromEnvironment('CAPTURE_ONBOARDING');
  if (dir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('two pages lead to sign-up and are remembered', (tester) async {
    var done = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: lightTheme,
        home: RepaintBoundary(child: OnboardingScreen(onDone: () => done++))));
    await tester.pumpAndSettle();
    expect(find.text('Log every set in seconds'), findsOneWidget);
    await _capture(tester, 'page1');

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Watch your progress add up'), findsOneWidget);
    await _capture(tester, 'page2');
    expect(done, 0);

    await tester.tap(find.byTooltip('Continue to sign up'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(await OnboardingScreen.hasBeenSeen(), isTrue);
  });

  testWidgets('skip goes straight to sign-up', (tester) async {
    var done = 0;
    await tester
        .pumpWidget(MaterialApp(home: OnboardingScreen(onDone: () => done++)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(await OnboardingScreen.hasBeenSeen(), isTrue);
  });

  for (final theme in [lightTheme, darkTheme]) {
    testWidgets('${theme.brightness.name} fits narrow large text',
        (tester) async {
      await _pump(tester, theme: theme, size: const Size(320, 640), text: 1.5);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
