import 'widgets/personal_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'state/workout_notifier.dart';
import 'state/auth_notifier.dart';
import 'state/settings_notifier.dart';
import 'state/navigation/tab_navigation_notifier.dart';
import 'state/template_notifier.dart';
import 'state/exercise_db_notifier.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/account_storage.dart';
import 'widgets/account_session.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'data/exercise_catalog.dart';
import 'data/exercise_db_repository.dart';
import 'widgets/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/keyboard_done_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['General Sans'],
        await rootBundle.loadString('assets/fonts/general_sans/LICENSE.txt'));
  });

  // Initial system UI style; the app theme follows the device appearance.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Dark icons for Android
    statusBarBrightness:
        Brightness.light, // Light status bar for iOS (means dark icons)
  ));

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
    print('Please run: flutterfire configure');
  }

  // Records and progress map older exercise IDs through the bundled catalog,
  // so it must be ready before history is first shown.
  try {
    await ExerciseCatalog.load();
  } catch (e) {
    debugPrint('Exercise catalog failed to load: $e');
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
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AuthNotifier(FirebaseService()),
        child: Selector<AuthNotifier, String?>(
          selector: (_, auth) => auth.isAuthenticated ? auth.user!.uid : null,
          builder: (_, userId, __) => AccountSession(
            userId: userId,
            builder: (_) => _SessionApp(userId: userId),
          ),
        ),
      );
}

class _SessionApp extends StatefulWidget {
  final String? userId;
  const _SessionApp({required this.userId});

  @override
  State<_SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<_SessionApp> {
  late final account = AccountStorage(widget.userId);
  late final firebaseService = FirebaseService();
  late final storageService = StorageService(account: account);
  late final syncService = SyncService(firebaseService, storageService);
  late final notificationService = NotificationService();
  late final exerciseDbRepository = ExerciseDbRepository();

  @override
  void dispose() {
    syncService.dispose();
    firebaseService.stopWorkoutsListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => WorkoutNotifier(
                  syncService,
                  storageService: storageService,
                )),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider(create: (_) => TabNavigationNotifier()),
        ChangeNotifierProvider(create: (_) => TemplateNotifier()),
        ChangeNotifierProvider(
          create: (_) => ExerciseDbNotifier(exerciseDbRepository),
        ),
        Provider.value(value: firebaseService),
        Provider.value(value: storageService),
        Provider.value(value: syncService),
        Provider.value(value: notificationService),
        Provider.value(value: exerciseDbRepository),
      ],
      child: MaterialApp(
        title: 'SweatMark',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: KeyboardDoneBar(child: child!),
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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  FirebaseService? _firebaseService;
  WorkoutNotifier? _workoutNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer setup to avoid accessing context before widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupListeners();
      }
    });
  }

  void _setupListeners() {
    final auth = context.read<AuthNotifier>();
    if (!auth.isAuthenticated) return;
    final userId = auth.user!.uid;
    _firebaseService = context.read<FirebaseService>();
    _workoutNotifier = context.read<WorkoutNotifier>();
    context.read<TemplateNotifier>().initialize(userId);
    _workoutNotifier!.loadWorkoutHistoryFromCloud(userId);
    _workoutNotifier!.onPersonalRecords = (newPRs) {
      if (!mounted) return;
      final settings = context.read<SettingsNotifier>();
      final message = newPRs
          .map((r) =>
              'New PR! ${r.exerciseName} · ${r.label(settings.weightSuffix)}')
          .join('\n');
      if (settings.hapticFeedbackEnabled) HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: RecordCelebration(message),
        backgroundColor: AppDesign.of(context).recordContainer,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ));
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseService?.stopWorkoutsListener();
    _workoutNotifier?.onPersonalRecords = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _workoutNotifier?.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _workoutNotifier?.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();

    // Signed out: the intro pages once per device, then sign-up.
    if (!authNotifier.isAuthenticated) {
      return const SignedOutFlow();
    }

    // Show main app if authenticated
    return const AppShell();
  }
}

class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key});

  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  bool? _showIntro;

  @override
  void initState() {
    super.initState();
    OnboardingScreen.hasBeenSeen().then((seen) {
      if (mounted) setState(() => _showIntro = !seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showIntro = _showIntro;
    if (showIntro == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: showIntro
          ? OnboardingScreen(
              key: const ValueKey('intro'),
              onDone: () => setState(() => _showIntro = false))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}
