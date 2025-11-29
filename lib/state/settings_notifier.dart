import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _restTimerDurationKey = 'rest_timer_duration';
  
  int _restTimerDuration = 90; // Default 90 seconds
  Timer? _globalRestTimer;
  int _currentRestSeconds = 0;
  bool _isResting = false;
  
  int get restTimerDuration => _restTimerDuration;
  int get currentRestSeconds => _currentRestSeconds;
  bool get isResting => _isResting;
  
  SettingsNotifier() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restTimerDuration = prefs.getInt(_restTimerDurationKey) ?? 90;
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
  
  void startRestTimer({int? customDuration}) {
    _stopRestTimer();
    
    _isResting = true;
    _currentRestSeconds = customDuration ?? _restTimerDuration;
    notifyListeners();
    
    _globalRestTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentRestSeconds > 0) {
        _currentRestSeconds--;
        notifyListeners();
      } else {
        _stopRestTimer();
      }
    });
  }
  
  void _stopRestTimer() {
    _globalRestTimer?.cancel();
    _globalRestTimer = null;
    _isResting = false;
    _currentRestSeconds = 0;
    notifyListeners();
  }
  
  void stopRestTimer() {
    _stopRestTimer();
  }
  
  void adjustRestTime(int adjustment) {
    if (_isResting) {
      _currentRestSeconds = (_currentRestSeconds + adjustment).clamp(0, 600);
      notifyListeners();
    }
  }
  
  String formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _globalRestTimer?.cancel();
    super.dispose();
  }
}