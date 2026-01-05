import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

/// State management for Analytics screen
class AnalyticsNotifier extends ChangeNotifier {
  final AnalyticsService _analyticsService;
  final String userId;

  AnalyticsSummary? _summary;
  AnalyticsWindow _selectedWindow = AnalyticsWindow.days7;
  bool _isLoading = true;
  String? _error;
  bool _hasMigrated = false;

  AnalyticsNotifier({
    required AnalyticsService analyticsService,
    required this.userId,
  }) : _analyticsService = analyticsService {
    // Schedule initialization after constructor completes
    Future.microtask(() => _initialize());
  }

  // Getters
  AnalyticsSummary? get summary => _summary;
  AnalyticsWindow get selectedWindow => _selectedWindow;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SweatTier get tier => _summary?.tier ?? SweatTier.starter;
  bool get hasMigrated => _hasMigrated;

  /// Initialize analytics
  Future<void> _initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Migrate historical data if needed
      await _analyticsService.migrateHistoricalData(userId);
      _hasMigrated = true;

      // Load initial data
      await _loadSummary();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load analytics summary for selected window
  Future<void> _loadSummary() async {
    try {
      _summary = await _analyticsService.getAnalyticsSummary(
        userId,
        _selectedWindow,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change time window
  Future<void> setWindow(AnalyticsWindow window) async {
    if (window == _selectedWindow) return;

    _selectedWindow = window;
    _isLoading = true;
    notifyListeners();

    await _loadSummary();
  }

  /// Refresh data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _loadSummary();
  }

  /// Get tier progress info
  Map<String, dynamic> getTierProgress() {
    final currentTier = _summary?.tier ?? SweatTier.starter;
    final nextTier = currentTier.nextTier;

    if (nextTier == null) {
      return {
        'currentTier': currentTier,
        'nextTier': null,
        'progress': 1.0,
        'message': 'You\'ve reached the top!',
      };
    }

    final allTimeWorkouts = _summary?.allTimeWorkouts ?? 0;
    final allTimeVolume = _summary?.allTimeVolume ?? 0;
    final remaining = currentTier.remainingForNext(allTimeWorkouts, allTimeVolume);
    final progress = currentTier.progressToNext(allTimeWorkouts, allTimeVolume);

    String message;
    if (remaining['workouts']! > 0 && remaining['volume']! > 0) {
      message =
          '${remaining['workouts']} workouts & ${AnalyticsSummary.formatVolume(remaining['volume']!)} volume to go';
    } else if (remaining['workouts']! > 0) {
      message = '${remaining['workouts']} workouts to go';
    } else if (remaining['volume']! > 0) {
      message = '${AnalyticsSummary.formatVolume(remaining['volume']!)} volume to go';
    } else {
      message = 'Almost there!';
    }

    return {
      'currentTier': currentTier,
      'nextTier': nextTier,
      'progress': progress,
      'message': message,
      'remainingWorkouts': remaining['workouts'],
      'remainingVolume': remaining['volume'],
    };
  }

  /// Get consistency rating
  String getConsistencyRating() {
    final percent = _summary?.consistencyPercent ?? 0;
    if (percent >= 80) return 'Excellent';
    if (percent >= 60) return 'Great';
    if (percent >= 40) return 'Good';
    if (percent >= 20) return 'Building';
    return 'Getting started';
  }

  /// Get chart data for volume trend
  List<Map<String, dynamic>> getVolumeTrendData() {
    final dailyStats = _summary?.dailyStats ?? [];
    return dailyStats
        .map((day) => {
              'date': day.date,
              'volume': day.volume,
              'workouts': day.workouts,
            })
        .toList();
  }

  /// Get muscle distribution data for chart
  List<Map<String, dynamic>> getMuscleDistributionData() {
    final dist = _summary?.muscleDistribution.distribution ?? {};
    if (dist.isEmpty) return [];

    final sorted = dist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map((e) => {
              'muscle': e.key,
              'count': e.value,
              'percentage': _summary!.muscleDistribution.percentageOf(e.key),
            })
        .toList();
  }
}
