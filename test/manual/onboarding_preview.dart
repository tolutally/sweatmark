// Memory-only simulator preview of the signed-out intro. Never touches an
// account: run with `flutter run -t test/manual/onboarding_preview.dart`.
import 'package:flutter/material.dart';
import 'package:sweatmark/screens/onboarding_screen.dart';
import 'package:sweatmark/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Preview());
}

class _Preview extends StatefulWidget {
  const _Preview();

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: _done
            ? Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => setState(() => _done = false),
                        child:
                            const Text('Sign-up screen goes here · replay'))))
            : OnboardingScreen(
                remember: false, onDone: () => setState(() => _done = true)),
      );
}
