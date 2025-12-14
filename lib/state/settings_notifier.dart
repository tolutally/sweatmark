import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _restTimerDurationKey = 'rest_timer_duration';
  static const String _hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  
  int _restTimerDuration = 90; // Default 90 seconds
  bool _hapticFeedbackEnabled = true; // Default enabled
  Timer? _globalRestTimer;
  int _currentRestSeconds = 0;
  bool _isResting = false;
  bool _isPaused = false;
  DateTime? _timerStartTime;
  int _timerOriginalDuration = 0;
  
  int get restTimerDuration => _restTimerDuration;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  int get currentRestSeconds => _currentRestSeconds;
  bool get isResting => _isResting;
  bool get isPaused => _isPaused;
  
  // Callback for timer completion
  VoidCallback? onTimerComplete;
  
  SettingsNotifier() {
    _loadSettings();
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
  
  @override
  void dispose() {
    _globalRestTimer?.cancel();
    super.dispose();
  }
}