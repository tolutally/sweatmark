import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/workout_notifier.dart';
import 'state/recovery_notifier.dart';
import 'state/auth_notifier.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'widgets/app_shell.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    print('Please run: flutterfire configure');
  }
  
  runApp(const SweatMarkApp());
}

class SweatMarkApp extends StatelessWidget {
  const SweatMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize services
    final firebaseService = FirebaseService();
    final storageService = StorageService();
    final syncService = SyncService(firebaseService, storageService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier(firebaseService)),
        ChangeNotifierProvider(create: (_) => WorkoutNotifier()),
        ChangeNotifierProvider(create: (_) => RecoveryNotifier()),
        Provider.value(value: firebaseService),
        Provider.value(value: storageService),
        Provider.value(value: syncService),
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
            error: Color(0xFFEF4444),
            onPrimary: Colors.black,
            onSecondary: Colors.white,
            onSurface: Colors.white,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper to show auth screen or main app based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();

    // Show auth screen if not authenticated
    if (!authNotifier.isAuthenticated) {
      return const AuthScreen();
    }

    // Show main app if authenticated
    return const AppShell();
  }
}
