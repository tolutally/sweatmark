import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/streak_model.dart';
import '../services/streak_service.dart';

/// State management for workout streaks with real-time Firestore sync
class StreakNotifier extends ChangeNotifier {
  final StreakService _streakService;
  final String userId;

  StreakModel? _streak;
  StreamSubscription<StreakModel?>? _streakSubscription;
  bool _isLoading = true;
  String? _error;

  StreakNotifier({
    required StreakService streakService,
    required this.userId,
  }) : _streakService = streakService {
    _initializeListener();
  }

  // Getters
  StreakModel? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasStreak => _streak != null && _streak!.current > 0;

  /// Initialize real-time Firestore listener
  void _initializeListener() {
    _streakSubscription = _streakService.streakStream(userId).listen(
      (streakData) {
        _streak = streakData;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Update streak settings (type, weekly goal, scheduled days)
  Future<void> updateSettings({
    StreakType? type,
    int? weeklyGoal,
    List<int>? scheduledDays,
    String? timezone,
  }) async {
    try {
      await _streakService.updateStreakSettings(
        userId: userId,
        type: type,
        weeklyGoal: weeklyGoal,
        scheduledDays: scheduledDays,
        timezone: timezone,
      );
      // Firestore listener will automatically update _streak
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Acknowledge that user has seen "streak broken" modal
  Future<void> acknowledgeStreakBroken() async {
    try {
      await _streakService.acknowledgeStreakBroken(userId);
      // Firestore listener will automatically update _streak
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Initialize streak for new user
  Future<void> initializeStreak(String timezone) async {
    try {
      await _streakService.initializeStreak(userId, timezone);
      // Firestore listener will automatically update _streak
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get formatted deadline text for display
  String getDeadlineText() {
    if (_streak == null) return 'No active streak';
    return _streakService.getDeadlineText(_streak!);
  }

  /// Get urgency level for UI styling
  String getUrgencyLevel() {
    if (_streak == null) return 'normal';
    return _streakService.getUrgencyLevel(_streak!);
  }

  @override
  void dispose() {
    _streakSubscription?.cancel();
    super.dispose();
  }
}
