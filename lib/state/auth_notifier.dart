import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthNotifier extends ChangeNotifier {
  final FirebaseService _firebaseService;
  User? _user;
  bool _isLoading = false;

  AuthNotifier(this._firebaseService) {
    // Listen to auth state changes
    _firebaseService.authStateChanges.listen((user) {
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

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.signInWithGoogle();
    
    _isLoading = false;
    notifyListeners();
    
    return credential != null;
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.signInWithApple();
    
    _isLoading = false;
    notifyListeners();
    
    return credential != null;
  }
}
