import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'state/workout_notifier.dart';
import 'state/recovery_notifier.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const SweatMarkApp());
}

class SweatMarkApp extends StatelessWidget {
  const SweatMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutNotifier()),
        ChangeNotifierProvider(create: (_) => RecoveryNotifier()),
      ],
      child: MaterialApp(
        title: 'SweatMark',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          primaryColor: const Color(0xFF2BD4BD),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2BD4BD),
            secondary: Color(0xFF3B82F6),
            surface: Color(0xFF1C1C1E),
            background: Color(0xFF000000),
            error: Color(0xFFEF4444),
            onPrimary: Colors.black,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onBackground: Colors.white,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const AppShell(),
      ),
    );
  }
}
