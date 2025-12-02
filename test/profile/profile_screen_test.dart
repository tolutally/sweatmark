import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweatmark/models/workout_model.dart';
import 'package:sweatmark/screens/profile_screen.dart';
import 'package:sweatmark/services/firebase_service.dart';
import 'package:sweatmark/state/auth_notifier.dart';
import 'package:sweatmark/state/navigation/tab_navigation_notifier.dart';
import 'package:sweatmark/state/profile/profile_notifier.dart';
import 'package:sweatmark/state/settings_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('edits display name and handle', (tester) async {
    final fakeUser = _FakeUser('user-123');
    final fakeService = _FakeFirebaseService(
      initialUser: fakeUser,
      initialProfile: {
        'username': 'Test User',
        'handle': '@tester',
        'stats': {'totalWorkouts': 0, 'totalPRs': 0},
      },
    );

    final authNotifier = AuthNotifier(fakeService);
    fakeService.emitAuth(fakeUser);
    final profileNotifier = ProfileNotifier(fakeService);
    await profileNotifier.loadProfile(fakeUser.uid);

    await tester.pumpWidget(_TestHost(
      firebaseService: fakeService,
      authNotifier: authNotifier,
      profileNotifier: profileNotifier,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('@tester'), findsOneWidget);

    await tester.tap(find.text('Test User'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);

    await tester.enterText(
      _textFieldByLabel('Display Name'),
      'New Name',
    );
    await tester.enterText(
      _textFieldByLabel('Handle'),
      'newhandle',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('@newhandle'), findsOneWidget);
  });

  testWidgets('updates location from info row', (tester) async {
    final fakeUser = _FakeUser('user-456');
    final fakeService = _FakeFirebaseService(
      initialUser: fakeUser,
      initialProfile: {
        'username': 'Traveler',
        'handle': '@sweat',
        'stats': {'totalWorkouts': 0, 'totalPRs': 0},
      },
    );

    final authNotifier = AuthNotifier(fakeService);
    fakeService.emitAuth(fakeUser);
    final profileNotifier = ProfileNotifier(fakeService);
    await profileNotifier.loadProfile(fakeUser.uid);

    await tester.pumpWidget(_TestHost(
      firebaseService: fakeService,
      authNotifier: authNotifier,
      profileNotifier: profileNotifier,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add Location...'), findsOneWidget);

    await tester.tap(find.text('Add Location...'));
    await tester.pumpAndSettle();

    await tester.enterText(
      _textFieldByHint('Enter your location'),
      'Brooklyn',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Brooklyn'), findsOneWidget);
  });
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _textFieldByHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.firebaseService,
    required this.authNotifier,
    required this.profileNotifier,
  });

  final FirebaseService firebaseService;
  final AuthNotifier authNotifier;
  final ProfileNotifier profileNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        ChangeNotifierProvider<AuthNotifier>.value(value: authNotifier),
        ChangeNotifierProvider<ProfileNotifier>.value(value: profileNotifier),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider(create: (_) => TabNavigationNotifier()),
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }
}

class _FakeFirebaseService implements FirebaseService {
  _FakeFirebaseService({
    required User? initialUser,
    Map<String, dynamic>? initialProfile,
  }) : _initialUser = initialUser {
    if (initialUser != null && initialProfile != null) {
      _profiles[initialUser.uid] = Map<String, dynamic>.from(initialProfile);
    }

    Future.microtask(() {
      emitAuth(_initialUser);
    });
  }

  final User? _initialUser;
  final Map<String, Map<String, dynamic>> _profiles = {};
  final _authController = StreamController<User?>.broadcast(sync: true);
  User? _currentUser;

  void emitAuth(User? user) {
    _currentUser = user;
    _authController.add(user);
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  @override
  Future<UserCredential?> signInAnonymously() async {
    return null;
  }

  @override
  Future<UserCredential?> signUpWithEmail(
      String email, String password) async {
    return null;
  }

  @override
  Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    return null;
  }

  @override
  Future<void> signOut() async {
    emitAuth(null);
  }

  @override
  Future<UserCredential?> linkEmailPassword(
      String email, String password) async {
    return null;
  }

  @override
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    final existing = Map<String, dynamic>.from(_profiles[userId] ?? {});
    data.forEach((key, value) {
      if (value is FieldValue) {
        existing.remove(key);
      } else {
        existing[key] = value;
      }
    });
    _profiles[userId] = existing;
  }

  @override
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) async {
    _profiles[userId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final data = _profiles[userId];
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  @override
  Future<void> saveWorkout(String userId, WorkoutLog workout) async {}

  @override
  Future<List<WorkoutLog>> getWorkouts(String userId) async {
    return [];
  }

  @override
  Stream<List<WorkoutLog>> getWorkoutsStream(String userId) {
    return const Stream.empty();
  }

  @override
  Future<List<WorkoutLog>> getRecentWorkouts(
      String userId, int days) async {
    return [];
  }

  @override
  Future<void> deleteWorkout(String userId, WorkoutLog workout) async {}

  @override
  Future<void> batchUploadWorkouts(
      String userId, List<WorkoutLog> workouts) async {}

  @override
  void startWorkoutsListener(
      String userId, Function(List<WorkoutLog>) onUpdate) {}

  @override
  void stopWorkoutsListener() {}
}

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
