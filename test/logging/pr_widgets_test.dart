import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/widgets/personal_records.dart';

void main() {
  testWidgets('celebration respects reduced motion and fits narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: RecordCelebration(
                    'New PR! Hip Abduction Machine · 65 kg × 8')))));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.textContaining('New PR!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RecordCelebration('New PR! Bench Press · 65 kg × 8'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
