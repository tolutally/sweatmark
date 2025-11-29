import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/workout_notifier.dart';
import 'state/recovery_notifier.dart';
import 'state/auth_notifier.dart';
import 'state/settings_notifier.dart';
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
        ChangeNotifierProvider(create: (_) => WorkoutNotifier(syncService)),
        ChangeNotifierProvider(create: (_) => RecoveryNotifier()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        Provider.value(value: firebaseService),
        Provider.value(value: storageService),
        Provider.value(value: syncService),
      ],
      child: MaterialApp(
        title: 'SweatMark',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          primaryColor: const Color(0xFF2BD4BD),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2BD4BD),
            secondary: Color(0xFF3B82F6),
            surface: Colors.white,
            error: Color(0xFFEF4444),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.black,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
            bodyColor: Colors.black,
            displayColor: Colors.black,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Wrapper to show auth screen or main app based on auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    final authNotifier = context.read<AuthNotifier>();
    final firebaseService = context.read<FirebaseService>();
    final workoutNotifier = context.read<WorkoutNotifier>();

    // Listen to auth state and start/stop Firestore listeners
    authNotifier.addListener(() {
      if (authNotifier.isAuthenticated && authNotifier.user != null) {
        // Start real-time listeners when authenticated
        firebaseService.startWorkoutsListener(
          authNotifier.user!.uid,
          (workouts) {
            // Update workout history in local storage when cloud changes
            // This is silent and invisible to the user
            print('Received ${workouts.length} workouts from Firestore');
          },
        );
        
        // Set up PR notification callback
        workoutNotifier.onPersonalRecords = (newPRs) {
          if (mounted) {
            final message = newPRs.length == 1
                ? '🎉 New PR: ${newPRs.first}!'
                : '🎉 ${newPRs.length} New PRs: ${newPRs.join(", ")}!';
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: const Color(0xFF2BD4BD),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        };
      } else {
        // Stop listeners when signed out
        firebaseService.stopWorkoutsListener();
        workoutNotifier.onPersonalRecords = null;
      }
    });
  }

  @override
  void dispose() {
    final firebaseService = context.read<FirebaseService>();
    firebaseService.stopWorkoutsListener();
    super.dispose();
  }

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
