import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/widgets/keyboard_done_bar.dart';

void main() {
  testWidgets('screens keep room for the Done bar above the keyboard',
      (tester) async {
    double? inset;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => KeyboardDoneBar(child: child!),
      home: Builder(builder: (context) {
        inset = MediaQuery.viewInsetsOf(context).bottom;
        return const Scaffold(body: TextField());
      }),
    ));
    addTearDown(tester.view.resetViewInsets);
    expect(inset, 0);

    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keyboard-done')), findsOneWidget);
    expect(
        inset, 300 / tester.view.devicePixelRatio + KeyboardDoneBar.barHeight,
        reason: 'the field being typed in stays above the bar');
  });
}
