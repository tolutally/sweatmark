import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/screens/account_profile_screen.dart';
import 'package:sweatmark/screens/settings_screen.dart';
import 'package:sweatmark/state/auth_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import 'home_test.dart' show Workouts, Templates;
import 'settings_screen_test.dart' show Preferences;

class _Provider implements UserInfo {
  @override
  final String providerId;
  _Provider(this.providerId);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Metadata implements UserMetadata {
  @override
  DateTime? get creationTime => DateTime(2026, 3, 4);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  String? name;
  _User(this.name);
  @override
  String? get displayName => name;
  @override
  String? get email => 'tolu@example.com';
  @override
  String get uid => 'user-1';
  @override
  List<UserInfo> get providerData => [_Provider('apple.com')];
  @override
  UserMetadata get metadata => _Metadata();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthNotifier {
  final _User account;
  int deletes = 0;
  _Auth(this.account);
  @override
  User? get user => account;
  @override
  Future<void> updateName(String name) async {
    account.name = name;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() async {
    deletes++;
    throw const AccountDeletionException(
        'For your security, sign out and sign back in, then delete your account.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Auth> _pump(WidgetTester tester, {String? name = 'Tolu Towoju'}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(_User(name));
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Preferences()),
      ChangeNotifierProvider<AuthNotifier>.value(value: auth),
      ChangeNotifierProvider<TemplateNotifier>(create: (_) => Templates([])),
    ],
    child: MaterialApp(theme: lightTheme, home: const AccountProfileScreen()),
  ));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  test('initials come from the name, or the email', () {
    expect(AccountProfileScreen.initials('Tolu Towoju', null), 'TT');
    expect(AccountProfileScreen.initials('  ada  ', null), 'A');
    expect(AccountProfileScreen.initials(null, 'kim@example.com'), 'K');
    expect(AccountProfileScreen.initials('', ''), '?');
  });

  testWidgets('profile shows who you are without recent activity',
      (tester) async {
    await _pump(tester);
    expect(find.text('TT'), findsOneWidget);
    expect(find.text('Member since March 2026'), findsOneWidget);
    expect(find.text('Your goals'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget, reason: 'sign-in method');
    expect(find.text('Your data'), findsOneWidget);
    expect(find.text('Recent activity'), findsNothing);
    final account = tester.getTopLeft(find.text('Account')).dy;
    final goals = tester.getTopLeft(find.text('Your goals')).dy;
    final data = tester.getTopLeft(find.text('Your data')).dy;
    expect(account < goals && goals < data, isTrue,
        reason: 'Account, then goals, then data');
    // Preferences, sign out and delete live only in Settings.
    for (final repeated in [
      'Training', 'Units', 'Rest timer', 'Apple Health', 'Sign out', //
      'Delete account'
    ]) {
      expect(find.text(repeated), findsNothing, reason: repeated);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('name can be edited from the profile', (tester) async {
    final auth = await _pump(tester, name: null);
    expect(find.text('Add your name'), findsOneWidget);
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ada Obi');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(auth.account.name, 'Ada Obi');
    expect(find.text('AO'), findsOneWidget);
  });

  testWidgets('the gear opens Settings', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Settings has sign out and a small delete account link',
      (tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    final link = find.text('Delete account');
    await tester.scrollUntilVisible(link, 200);
    await tester.pumpAndSettle();
    expect(tester.getSize(link).height, lessThan(18), reason: 'kept small');
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 0);

    await tester.tap(link);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 1);
    expect(find.textContaining('For your security'), findsOneWidget);
  });
}
