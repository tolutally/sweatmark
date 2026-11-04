import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthNotifier extends ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _user;
  bool _isLoading = false;
  late final StreamSubscription<User?> _authSubscription;

  AuthNotifier(this._firebaseService) {
    // Listen to auth state changes
    _user = _firebaseService.currentUser;
    _authSubscription = _firebaseService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null && !(_user?.isAnonymous ?? true);
  bool get isLoading => _isLoading;

  /// Check if user has a verified email (for extra security if needed)
  bool get hasVerifiedEmail => _user?.emailVerified ?? false;

  // Anonymous sign-in is DISABLED - all users must authenticate properly

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.signUpWithEmail(email, password);

    _isLoading = false;
    notifyListeners();

    return credential != null;
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.signInWithEmail(email, password);

    _isLoading = false;
    notifyListeners();

    return credential != null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseService.signOut();
  }

  // linkEmailPassword removed - no anonymous accounts to link

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    notifyListeners();

    final success = await _firebaseService.sendPasswordResetEmail(email);

    _isLoading = false;
    notifyListeners();

    return success;
  }

  /// Sign in with Google. Null means the person closed Google's sheet.
  Future<bool?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      return await _firebaseService.signInWithGoogle() != null;
    } on SignInCancelled {
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Apple. Null means the person closed Apple's sheet.
  Future<bool?> signInWithApple() async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _firebaseService.signInWithApple() != null;
    } on SignInWithAppleAuthorizationException {
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
