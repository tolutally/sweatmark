import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/state/session_notifier.dart';
import 'package:sweatmark/widgets/account_session.dart';

class _AccountData extends SessionNotifier {
  String value;
  _AccountData(this.value);
  Future<void> load(Future<String> pending) async {
    final result = await pending;
    if (isDisposed) return;
    value = result;
    notifyListeners();
  }
}

void main() {
  testWidgets('account changes dispose old state and reset private navigation',
      (tester) async {
    final created = <_AccountData>[];
    Widget app(String? uid) => AccountSession(
          userId: uid,
          builder: (_) => ChangeNotifierProvider(
            create: (_) {
              final data = _AccountData(uid ?? 'signed-out');
              created.add(data);
              return data;
            },
            child: MaterialApp(
                home: Builder(
                    builder: (context) => Scaffold(
                            body: Column(children: [
                          Text(context.watch<_AccountData>().value),
                          TextButton(
                              onPressed: () => Navigator.of(context)
                                      .push(MaterialPageRoute<void>(
                                    builder: (_) => const Scaffold(
                                        body: Text('private workout details')),
                                  )),
                              child: const Text('Open workout')),
                        ])))),
          ),
        );
    await tester.pumpWidget(app('account-a'));
    final original = created.single;
    await tester.tap(find.text('Open workout'));
    await tester.pumpAndSettle();
    expect(find.text('private workout details'), findsOneWidget);
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    expect(original.isDisposed, isTrue);
    expect(find.text('private workout details'), findsNothing);
    expect(find.text('signed-out'), findsOneWidget);
    await tester.pumpWidget(app('account-b'));
    await tester.pumpAndSettle();
    expect(find.text('account-a'), findsNothing);
    expect(find.text('account-b'), findsOneWidget);
  });

  testWidgets(
      'same account retains state; late previous-account result cannot replace it',
      (tester) async {
    final created = <_AccountData>[];
    Widget app(String uid) => AccountSession(
        userId: uid,
        builder: (_) => ChangeNotifierProvider(
              create: (_) {
                final data = _AccountData(uid);
                created.add(data);
                return data;
              },
              child: MaterialApp(
                  home: Builder(
                      builder: (context) =>
                          Text(context.watch<_AccountData>().value))),
            ));
    await tester.pumpWidget(app('a'));
    final original = created.single;
    final pending = Completer<String>();
    final loading = original.load(pending.future);
    await tester.pumpWidget(app('a'));
    expect(created.length, 1);
    expect(original.isDisposed, isFalse);
    await tester.pumpWidget(app('b'));
    expect(original.isDisposed, isTrue);
    pending.complete('a private cloud data');
    await loading;
    await tester.pump();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('a private cloud data'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('late notifications after disposal are ignored', () {
    final notifier = SessionNotifier();
    var notifications = 0;
    notifier.addListener(() => notifications++);
    notifier.notifyListeners();
    notifier.dispose();
    notifier.notifyListeners();
    expect(notifications, 1);
  });
}
