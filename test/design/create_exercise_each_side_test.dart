import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/screens/create_exercise_screen.dart';
import 'package:sweatmark/theme/app_theme.dart';

void main() {
  testWidgets('Each side follows the name until set by hand', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: lightTheme, home: const CreateExerciseScreen()));
    bool on() => tester
        .widget<Switch>(find.byKey(const ValueKey('custom-each-side')))
        .value;

    expect(find.text('Each side'), findsOneWidget);
    expect(on(), isFalse);
    await tester.enterText(find.byType(TextField).first, 'Single Arm Cable Row');
    await tester.pump();
    expect(on(), isTrue, reason: 'one-sided name');
    await tester.enterText(find.byType(TextField).first, 'Cable Row');
    await tester.pump();
    expect(on(), isFalse);

    await tester.tap(find.byKey(const ValueKey('custom-each-side')));
    await tester.pump();
    expect(on(), isTrue, reason: 'set by hand');
    await tester.enterText(find.byType(TextField).first, 'Landmine Press');
    await tester.pump();
    expect(on(), isTrue, reason: 'a hand choice is kept');
    expect(tester.takeException(), isNull);
  });
}
