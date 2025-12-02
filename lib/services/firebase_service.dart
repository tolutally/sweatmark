import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/workout_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _workoutsSubscription;
  Function(List<WorkoutLog>)? _onWorkoutsUpdate;

  // ============================================
  // AUTHENTICATION
  // ============================================

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Anonymous sign-in is DISABLED for security
  // All users must authenticate with email/password, Google, or Apple

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Create user profile
      if (credential.user != null) {
        await _createUserProfileIfNeeded(credential.user!.uid);
      }
      return credential;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _createUserProfileIfNeeded(credential.user!.uid);
      }
      return credential;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // linkEmailPassword removed - anonymous sign-in is disabled

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Error sending password reset email: $e');
      return false;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create user profile if needed
      if (userCredential.user != null) {
        await _createUserProfileIfNeeded(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  /// Generate a random string for Apple Sign-In nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Generate SHA256 hash of a string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuthCredential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Update display name if provided by Apple (only on first sign-in)
      if (userCredential.user != null && 
          appleCredential.givenName != null && 
          userCredential.user!.displayName == null) {
        final displayName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }
      
      // Create user profile if needed
      if (userCredential.user != null) {
        await _createUserProfileIfNeeded(userCredential.user!.uid);
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }

  // ============================================
  // USER PROFILE
  // ============================================

  /// Create user profile document if it doesn't exist
  Future<void> _createUserProfileIfNeeded(String userId) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data');
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'username': 'Flex User',
          'handle': '@sweatmark_user',
          'createdAt': FieldValue.serverTimestamp(),
          'stats': {
            'totalWorkouts': 0,
            'totalPRs': 0,
          },
        });
      }
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // ============================================
  // GLOBAL EXERCISES
  // ============================================

  Future<List<Map<String, dynamic>>> getGlobalExercises() async {
    try {
      final snapshot = await _firestore
          .collection('exercises')
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching global exercises: $e');
      return [];
    }
  }

  Future<void> seedGlobalExercises(List<Map<String, dynamic>> exercises) async {
    final batch = _firestore.batch();
    try {
      for (final ex in exercises) {
        final docRef = _firestore.collection('exercises').doc(ex['id'] as String);
        batch.set(docRef, ex, SetOptions(merge: true));
      }
      await batch.commit();
      print('✅ Seeded ${exercises.length} exercises to Firestore');
    } catch (e) {
      print('Error seeding exercises: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user profile: $e');
    }
  }

  /// Overwrite or create user profile
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error setting user profile: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // ============================================
  // WORKOUT OPERATIONS
  // ============================================

  /// Save workout to Firestore
  Future<void> saveWorkout(String userId, WorkoutLog workout) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .doc(workout.id)
          .set(workout.toJson());

      // Update stats
      await _incrementWorkoutCount(userId);
    } catch (e) {
      print('Error saving workout: $e');
      rethrow;
    }
  }

  /// Get all workouts for a user
  Future<List<WorkoutLog>> getWorkouts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting workouts: $e');
      return [];
    }
  }

  /// Get workouts stream for real-time updates
  Stream<List<WorkoutLog>> getWorkoutsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutLog.fromJson(doc.data()))
            .toList());
  }

  /// Get recent workouts (last N days)
  Future<List<WorkoutLog>> getRecentWorkouts(String userId, int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .where('timestamp', isGreaterThan: cutoffDate.toIso8601String())
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WorkoutLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting recent workouts: $e');
      return [];
    }
  }

  // ============================================
  // USER SCHEDULE
  // ============================================

  /// Save or update a user's workout schedule/preferences
  Future<void> setUserSchedule(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedule')
          .doc('data')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user schedule: $e');
      rethrow;
    }
  }

  /// Get a user's workout schedule/preferences
  Future<Map<String, dynamic>?> getUserSchedule(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedule')
          .doc('data')
          .get();
      return doc.data();
    } catch (e) {
      print('Error fetching user schedule: $e');
      return null;
    }
  }

  /// Delete workout
  Future<void> deleteWorkout(String userId, WorkoutLog workout) async {
    try {
      // Use timestamp as document ID since that's how workouts are stored
      final workoutId = workout.timestamp.millisecondsSinceEpoch.toString();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('workouts')
          .doc(workoutId)
          .delete();
    } catch (e) {
      print('Error deleting workout: $e');
      rethrow;
    }
  }

  /// Increment workout count in user stats
  Future<void> _incrementWorkoutCount(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .update({
        'stats.totalWorkouts': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing workout count: $e');
    }
  }

  // ============================================
  // CUSTOM EXERCISES (Firebase Sync)
  // ============================================

  /// Save custom exercise to Firebase
  Future<void> saveCustomExercise(String userId, Map<String, dynamic> exercise) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_exercises')
          .doc(exercise['id'])
          .set(exercise);
      print('✅ Custom exercise saved to Firebase: ${exercise['name']}');
    } catch (e) {
      print('❌ Error saving custom exercise to Firebase: $e');
      rethrow;
    }
  }

  /// Get all custom exercises for a user
  Future<List<Map<String, dynamic>>> getCustomExercises(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_exercises')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ Error getting custom exercises from Firebase: $e');
      return [];
    }
  }

  /// Stream of custom exercises for real-time updates
  Stream<List<Map<String, dynamic>>> getCustomExercisesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('custom_exercises')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Delete custom exercise from Firebase
  Future<void> deleteCustomExercise(String userId, String exerciseId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_exercises')
          .doc(exerciseId)
          .delete();
      print('✅ Custom exercise deleted from Firebase: $exerciseId');
    } catch (e) {
      print('❌ Error deleting custom exercise from Firebase: $e');
      rethrow;
    }
  }

  /// Batch upload custom exercises (for migration from local storage)
  Future<void> batchUploadCustomExercises(
      String userId, List<Map<String, dynamic>> exercises) async {
    try {
      final batch = _firestore.batch();

      for (final exercise in exercises) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('custom_exercises')
            .doc(exercise['id']);
        batch.set(docRef, exercise);
      }

      await batch.commit();
      print('✅ Batch uploaded ${exercises.length} custom exercises to Firebase');
    } catch (e) {
      print('❌ Error batch uploading custom exercises: $e');
      rethrow;
    }
  }

  // ============================================
  // BATCH OPERATIONS (for data migration)
  // ============================================

  /// Batch upload workouts (for migration from local storage)
  Future<void> batchUploadWorkouts(
      String userId, List<WorkoutLog> workouts) async {
    try {
      final batch = _firestore.batch();

      for (final workout in workouts) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('workouts')
            .doc(workout.id);
        batch.set(docRef, workout.toJson());
      }

      await batch.commit();

      // Update total count
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .update({
        'stats.totalWorkouts': workouts.length,
      });
    } catch (e) {
      print('Error batch uploading workouts: $e');
      rethrow;
    }
  }

  // ============================================
  // REAL-TIME LISTENERS
  // ============================================

  /// Start listening to workouts collection for real-time updates
  void startWorkoutsListener(
      String userId, Function(List<WorkoutLog>) onUpdate) {
    _onWorkoutsUpdate = onUpdate;

    _workoutsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          final workouts = snapshot.docs
              .map((doc) => WorkoutLog.fromJson(doc.data()))
              .toList();
          _onWorkoutsUpdate?.call(workouts);
        } catch (e) {
          print('Error parsing workouts in listener: $e');
        }
      },
      onError: (error) {
        print('Listener error: $error');
        // Silent reconnection attempt
        _silentReconnect(userId);
      },
      cancelOnError: false, // Keep listening even after errors
    );
  }

  /// Stop listening to workouts collection
  void stopWorkoutsListener() {
    _workoutsSubscription?.cancel();
    _workoutsSubscription = null;
    _onWorkoutsUpdate = null;
  }

  /// Silent reconnection logic for Firestore listeners
  void _silentReconnect(String userId) {
    // Wait 5 seconds before attempting to reconnect
    Future.delayed(const Duration(seconds: 5), () {
      if (_onWorkoutsUpdate != null) {
        // Only reconnect if listener was active
        stopWorkoutsListener();
        startWorkoutsListener(userId, _onWorkoutsUpdate!);
      }
    });
  }
}
