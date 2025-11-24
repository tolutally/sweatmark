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
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isAnonymous => _user?.isAnonymous ?? false;

  /// Sign in anonymously
  Future<bool> signInAnonymously() async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.signInAnonymously();
    
    _isLoading = false;
    notifyListeners();
    
    return credential != null;
  }

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

  /// Link anonymous account to email/password
  Future<bool> linkEmailPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final credential = await _firebaseService.linkEmailPassword(email, password);
    
    _isLoading = false;
    notifyListeners();
    
    return credential != null;
  }
}
