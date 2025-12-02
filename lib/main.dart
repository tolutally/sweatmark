import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/workout_notifier.dart';
import 'state/recovery_notifier.dart';
import 'state/auth_notifier.dart';
import 'state/settings_notifier.dart';
import 'state/profile/profile_notifier.dart';
import 'state/navigation/tab_navigation_notifier.dart';
import 'state/template_notifier.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'widgets/app_shell.dart';
import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for light theme (dark status bar icons)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Dark icons for Android
    statusBarBrightness: Brightness.light, // Light status bar for iOS (means dark icons)
  ));

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

  // Initialize notification service
  try {
    await NotificationService().initialize();
    print('NotificationService initialized successfully');
  } catch (e) {
    print('NotificationService initialization error: $e');
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
    final notificationService = NotificationService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier(firebaseService)),
        ChangeNotifierProvider(create: (_) => WorkoutNotifier(syncService)),
        ChangeNotifierProvider(create: (_) => RecoveryNotifier()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider(create: (_) => ProfileNotifier(firebaseService)),
        ChangeNotifierProvider(create: (_) => TabNavigationNotifier()),
        ChangeNotifierProvider(create: (_) => TemplateNotifier()),
        Provider.value(value: firebaseService),
        Provider.value(value: storageService),
        Provider.value(value: syncService),
        Provider.value(value: notificationService),
      ],
      child: MaterialApp(
        title: 'SweatMark',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupListeners();
  }

  void _setupListeners() {
    final authNotifier = context.read<AuthNotifier>();
    final firebaseService = context.read<FirebaseService>();
    final workoutNotifier = context.read<WorkoutNotifier>();
    final profileNotifier = context.read<ProfileNotifier>();
    final templateNotifier = context.read<TemplateNotifier>();

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

        // Initialize template notifier for the user
        templateNotifier.initialize(authNotifier.user!.uid);

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

        profileNotifier.loadProfile(authNotifier.user!.uid, forceRefresh: true);
      } else {
        // Stop listeners when signed out
        firebaseService.stopWorkoutsListener();
        workoutNotifier.onPersonalRecords = null;
        profileNotifier.clear();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final firebaseService = context.read<FirebaseService>();
    firebaseService.stopWorkoutsListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final workoutNotifier = context.read<WorkoutNotifier>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      workoutNotifier.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      workoutNotifier.onAppResumed();
    }
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
