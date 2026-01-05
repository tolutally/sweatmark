import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _restTimerDurationKey = 'rest_timer_duration';
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _restTimerDuration = 90; // Default 90 seconds
  bool _hapticFeedbackEnabled = true; // Default enabled
  Timer? _globalRestTimer;
  int _currentRestSeconds = 0;
  bool _isResting = false;
  bool _isPaused = false;
  DateTime? _timerStartTime;
  int _timerOriginalDuration = 0;
  
  // User unit preferences
  UserSettings _userSettings = const UserSettings();
  bool _userSettingsLoaded = false;
  
  int get restTimerDuration => _restTimerDuration;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  int get currentRestSeconds => _currentRestSeconds;
  bool get isResting => _isResting;
  bool get isPaused => _isPaused;
  UserSettings get userSettings => _userSettings;
  
  // Callback for timer completion
  VoidCallback? onTimerComplete;
  
  SettingsNotifier() {
    _loadSettings();
    _loadUserSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restTimerDuration = prefs.getInt(_restTimerDurationKey) ?? 90;
      _hapticFeedbackEnabled = prefs.getBool(_hapticFeedbackEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }
  
  Future<void> setRestTimerDuration(int duration) async {
    _restTimerDuration = duration;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_restTimerDurationKey, duration);
    } catch (e) {
      debugPrint('Error saving rest timer duration: $e');
    }
  }
  
  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    _hapticFeedbackEnabled = enabled;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hapticFeedbackEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving haptic feedback setting: $e');
    }
  }
  
  void startRestTimer({int? customDuration}) {
    // Cancel any existing timer first
    _globalRestTimer?.cancel();
    
    final duration = customDuration ?? _restTimerDuration;
    _isResting = true;
    _isPaused = false;
    _currentRestSeconds = duration;
    _timerOriginalDuration = duration;
    _timerStartTime = DateTime.now();
    
    // Play start haptic
    if (_hapticFeedbackEnabled) {
      HapticFeedback.mediumImpact();
    }
    
    notifyListeners();
    
    _globalRestTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 0) {
        _currentRestSeconds--;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }
  
  void _onTimerComplete() {
    _globalRestTimer?.cancel();
    _globalRestTimer = null;
    
    // Play completion haptic
    if (_hapticFeedbackEnabled) {
      HapticFeedback.heavyImpact();
    }
    
    _isResting = false;
    _isPaused = false;
    _currentRestSeconds = 0;
    _timerStartTime = null;
    
    // Trigger callback if set
    onTimerComplete?.call();
    
    notifyListeners();
  }
  
  void pauseRestTimer() {
    if (!_isResting || _isPaused) return;
    
    _globalRestTimer?.cancel();
    _isPaused = true;
    notifyListeners();
  }
  
  void resumeRestTimer() {
    if (!_isResting || !_isPaused) return;
    
    _isPaused = false;
    _timerStartTime = DateTime.now().subtract(
      Duration(seconds: _timerOriginalDuration - _currentRestSeconds),
    );
    notifyListeners();
    
    _globalRestTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 0) {
        _currentRestSeconds--;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }
  
  void stopRestTimer() {
    _globalRestTimer?.cancel();
    _globalRestTimer = null;
    _isResting = false;
    _isPaused = false;
    _currentRestSeconds = 0;
    _timerStartTime = null;
    notifyListeners();
  }
  
  /// Sync timer state when app resumes from background
  /// Uses wall-clock time to calculate how much time has passed
  void syncTimerFromBackground() {
    if (!_isResting || _isPaused || _timerStartTime == null) return;
    
    final elapsed = DateTime.now().difference(_timerStartTime!).inSeconds;
    final remaining = _timerOriginalDuration - elapsed;
    
    if (remaining <= 0) {
      _onTimerComplete();
    } else {
      _currentRestSeconds = remaining;
      notifyListeners();
    }
  }
  
  void adjustRestTime(int adjustment) {
    if (_isResting) {
      _currentRestSeconds = (_currentRestSeconds + adjustment).clamp(0, 600);
      // Also adjust the original duration to keep sync accurate
      _timerOriginalDuration = (_timerOriginalDuration + adjustment).clamp(0, 600);
      notifyListeners();
    }
  }
  
  String formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  // ==================== User Unit Preferences ====================
  
  /// Load user settings from Firestore
  Future<void> _loadUserSettings() async {
    if (_userSettingsLoaded) return;

    final user = _auth.currentUser;
    if (user == null) {
      _userSettingsLoaded = true;
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .get();

      if (doc.exists && doc.data() != null) {
        _userSettings = UserSettings.fromJson(doc.data()!);
      }
      _userSettingsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading user settings: $e');
    }
  }

  /// Reload settings when user logs in
  Future<void> reloadUserSettings() async {
    _userSettingsLoaded = false;
    await _loadUserSettings();
  }

  /// Save user settings to Firestore
  Future<void> _saveUserSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .set(_userSettings.toJson());
    } catch (e) {
      debugPrint('❌ Error saving user settings: $e');
    }
  }

  /// Update distance unit
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    _userSettings = _userSettings.copyWith(distanceUnit: unit);
    notifyListeners();
    await _saveUserSettings();
  }

  /// Update weight unit
  Future<void> setWeightUnit(WeightUnit unit) async {
    _userSettings = _userSettings.copyWith(weightUnit: unit);
    notifyListeners();
    await _saveUserSettings();
  }

  /// Format distance with current unit preference
  String formatDistance(double? distance) => _userSettings.formatDistance(distance);

  /// Format weight with current unit preference
  String formatWeight(double? weight) => _userSettings.formatWeight(weight);

  /// Format pace with current unit preference (min:sec/unit)
  String formatPace(int? durationSeconds, double? distance) =>
      _userSettings.formatPace(durationSeconds, distance);

  /// Format duration as mm:ss or h:mm:ss
  String formatDuration(int? seconds) => UserSettings.formatDuration(seconds);

  /// Parse duration string to seconds
  int? parseDuration(String input) => UserSettings.parseDuration(input);

  /// Get weight unit suffix
  String get weightSuffix => _userSettings.weightUnit == WeightUnit.lb ? 'lb' : 'kg';

  /// Get distance unit suffix
  String get distanceSuffix =>
      _userSettings.distanceUnit == DistanceUnit.miles ? 'mi' : 'km';

  /// Reset user settings when user logs out
  void resetUserSettings() {
    _userSettings = const UserSettings();
    _userSettingsLoaded = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _globalRestTimer?.cancel();
    super.dispose();
  }
}