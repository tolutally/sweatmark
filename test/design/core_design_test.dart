import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sweatmark/models/template_model.dart';
import 'package:sweatmark/screens/account_profile_screen.dart';
import 'package:sweatmark/screens/auth_screen.dart';
import 'package:sweatmark/screens/home_screen.dart';
import 'package:sweatmark/screens/settings_screen.dart';
import 'package:sweatmark/state/auth_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';
import 'package:sweatmark/state/template_notifier.dart';
import 'package:sweatmark/state/workout_notifier.dart';
import 'package:sweatmark/theme/app_theme.dart';
import '../logging/home_test.dart' show Workouts, Templates;
import '../logging/settings_screen_test.dart' show Preferences;

class _Auth extends ChangeNotifier implements AuthNotifier {
  @override
  User? get user => null;
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpSmallScreen(
    WidgetTester tester, ThemeData theme, Widget screen) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutNotifier>(create: (_) => Workouts()),
      ChangeNotifierProvider<SettingsNotifier>(create: (_) => Preferences()),
      ChangeNotifierProvider<AuthNotifier>(create: (_) => _Auth()),
      ChangeNotifierProvider<TemplateNotifier>(
          create: (_) => Templates([
                WorkoutTemplate(
                    id: 'routine',
                    userId: 'user',
                    name: 'Upper body and accessory strength',
                    exercises: [
                      TemplateExercise(
                          id: 'press', name: 'Alternating dumbbell bench press')
                    ])
              ])),
    ],
    child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true),
            child: child!),
        home: screen),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  for (final entry in {'light': lightTheme, 'dark': darkTheme}.entries) {
    testWidgets('home supports narrow screen and larger text in ${entry.key}',
        (tester) async {
      await _pumpSmallScreen(tester, entry.value, const HomeScreen());
      await tester.scrollUntilVisible(
          find.text('Upper body and accessory strength'), 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Upper body and accessory strength'), findsOneWidget);
    });

    testWidgets(
        'settings supports narrow screen and larger text in ${entry.key}',
        (tester) async {
      await _pumpSmallScreen(tester, entry.value, const SettingsScreen());
      await tester.scrollUntilVisible(find.text('Weight'), 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'profile supports narrow screen and larger text in ${entry.key}',
        (tester) async {
      await _pumpSmallScreen(tester, entry.value, const AccountProfileScreen());
      await tester.scrollUntilVisible(find.text('Recent activity'), 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sign in supports narrow screen and larger text in ${entry.key}',
        (tester) async {
      await _pumpSmallScreen(tester, entry.value, const AuthScreen());
      expect(find.text('Create your account'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Create account'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The footer link opens the separate sign-in screen and back.
      await tester.scrollUntilVisible(find.text('Sign in'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Forgot password?'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.scrollUntilVisible(find.text('Create account'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
