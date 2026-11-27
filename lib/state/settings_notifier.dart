import 'session_notifier.dart';
import '../models/weekly_progress.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsNotifier extends SessionNotifier {
  static const String _restTimerDurationKey = 'rest_timer_duration';
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  String _preferenceKey(String key) =>
      '${sha256.convert(utf8.encode(_userId ?? "signed-out"))}_$key';

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
  bool get userSettingsLoaded => _userSettingsLoaded;

  // Callback for timer completion
  VoidCallback? onTimerComplete;

  SettingsNotifier() {
    _loadSettings();
    _loadUserSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restTimerDuration =
          prefs.getInt(_preferenceKey(_restTimerDurationKey)) ?? 90;
      _hapticFeedbackEnabled =
          prefs.getBool(_preferenceKey(_hapticFeedbackEnabledKey)) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setRestTimerDuration(int duration) async {
    _restTimerDuration = duration;
    if (duration == 0) stopRestTimer();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_preferenceKey(_restTimerDurationKey), duration);
    } catch (e) {
      debugPrint('Error saving rest timer duration: $e');
    }
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    _hapticFeedbackEnabled = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferenceKey(_hapticFeedbackEnabledKey), enabled);
    } catch (e) {
      debugPrint('Error saving haptic feedback setting: $e');
    }
  }

  void startRestTimer({int? customDuration}) {
    // Cancel any existing timer first
    _globalRestTimer?.cancel();

    final duration = customDuration ?? _restTimerDuration;
    if (duration == 0) {
      stopRestTimer();
      return;
    }
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
      _timerOriginalDuration =
          (_timerOriginalDuration + adjustment).clamp(0, 600);
      notifyListeners();
    }
  }

  String formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // ==================== User Unit Preferences ====================

  int _settingsRevision = 0;
  Future<void> _loadUserSettings() async {
    if (_userSettingsLoaded || _userId == null) return;
    final revision = _settingsRevision;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_preferenceKey('preferences'));
    if (revision != _settingsRevision || isDisposed) return;
    if (cached != null) {
      _userSettings = UserSettings.fromJson(jsonDecode(cached));
      _userSettingsLoaded = true;
      notifyListeners();
      return;
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .get()
          .timeout(const Duration(seconds: 5));
      if (revision != _settingsRevision || isDisposed) return;
      if (doc.data() != null)
        _userSettings = UserSettings.fromJson(doc.data()!);
      _userSettingsLoaded = true;
      await prefs.setString(
          _preferenceKey('preferences'), jsonEncode(_userSettings.toJson()));
      notifyListeners();
    } catch (_) {
      _userSettingsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> reloadUserSettings() => _loadUserSettings();

  Future<void> _saveUserSettings() async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _preferenceKey('preferences'), jsonEncode(_userSettings.toJson()));
    if (_userId == null || isDisposed || _auth.currentUser?.uid != _userId)
      return;
    unawaited(_firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences')
        .set(_userSettings.toJson())
        .catchError((Object error) {
      debugPrint('Preferences saved locally: $error');
    }));
  }

  Future<void> setWeeklyGoal(int goal, {DateTime? now}) async {
    if (goal < 1 || goal > 14) throw ArgumentError.value(goal);
    final week = weekStart(now ?? DateTime.now());
    final next = DateTime(week.year, week.month, week.day + 7);
    _userSettings = _userSettings.copyWith(weeklyGoals: {
      ..._userSettings.weeklyGoals,
      weekKey(next): goal,
    });
    await _saveUserSettings();
    notifyListeners();
  }

  /// Update distance unit
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    _userSettings = _userSettings.copyWith(distanceUnit: unit);
    notifyListeners();
    await _saveUserSettings();
  }

  /// Where cardio in Stats comes from when Apple Health is on.
  Future<void> setCardioSource(CardioSource source) async {
    _userSettings = _userSettings.copyWith(cardioSource: source);
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
  String formatDistance(double? distance) =>
      _userSettings.formatDistance(distance);

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
  String get weightSuffix =>
      _userSettings.weightUnit == WeightUnit.lb ? 'lb' : 'kg';

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
