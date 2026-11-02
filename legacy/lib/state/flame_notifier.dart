import 'session_notifier.dart';
import 'dart:async';
import '../models/flame_model.dart';
import '../models/workout_model.dart';
import '../services/flame_service.dart';

/// State management for Flame (7-day peak volume tracker)
class FlameNotifier extends SessionNotifier {
  final FlameService _flameService;
  final String userId;

  FlameStats? _stats;
  List<DailyVolume>? _dailyVolumes;
  StreamSubscription<FlameStats?>? _subscription;
  bool _isLoading = true;
  String? _error;

  // Animation triggers (reset after being consumed)
  bool _showPeakAnimation = false;
  bool _showLevelUpAnimation = false;
  FlameLevel? _newLevel;

  FlameNotifier({
    required FlameService flameService,
    required this.userId,
  }) : _flameService = flameService {
    _initializeListener();
  }

  // Getters
  FlameStats? get stats => _stats;
  List<DailyVolume>? get dailyVolumes => _dailyVolumes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasFlame => _stats != null && _stats!.peak7d > 0;

  // Animation flags
  bool get showPeakAnimation => _showPeakAnimation;
  bool get showLevelUpAnimation => _showLevelUpAnimation;
  FlameLevel? get newLevel => _newLevel;

  /// Initialize real-time Firestore listener
  void _initializeListener() {
    _subscription = _flameService.watchFlameStats(userId).listen(
      (flameStats) {
        _stats = flameStats;
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
    _loadDailyVolumes();
  }

  /// Load 7-day volume data for chart
  Future<void> _loadDailyVolumes() async {
    // Retry up to 3 times with exponential backoff for transient errors
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        _dailyVolumes = await _flameService.getLast7DaysVolume(userId);
        notifyListeners();
        return; // Success, exit retry loop
      } catch (e) {
        final isLastAttempt = attempt == 2;
        if (isLastAttempt) {
          print('Error loading daily volumes after 3 attempts: $e');
          // Set empty list so UI doesn't hang
          _dailyVolumes = [];
          notifyListeners();
        } else {
          // Wait before retry (500ms, 1000ms)
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }
  }

  /// Record workout volume (called from WorkoutNotifier)
  Future<FlameStats> recordWorkout(WorkoutLog workout) async {
    try {
      final result = await _flameService.recordWorkoutVolume(userId, workout);

      // Trigger animations
      if (result.isNewPeak) {
        _showPeakAnimation = true;
      }
      if (result.leveledUp) {
        _showLevelUpAnimation = true;
        _newLevel = result.level;
      }

      _stats = result;
      await _loadDailyVolumes();
      notifyListeners();

      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Consume peak animation flag (call after animation plays)
  void consumePeakAnimation() {
    _showPeakAnimation = false;
    notifyListeners();
  }

  /// Consume level-up animation flag
  void consumeLevelUpAnimation() {
    _showLevelUpAnimation = false;
    _newLevel = null;
    notifyListeners();
  }

  /// Migrate historical workouts
  Future<void> migrateHistory(List<WorkoutLog> workouts) async {
    try {
      await _flameService.migrateHistoricalData(userId, workouts);
      // Listener will automatically update _stats
    } catch (e) {
      print('Error migrating flame history: $e');
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _loadDailyVolumes();
    _isLoading = false;
    notifyListeners();
  }

  /// Format volume for display (e.g., 12,500 → "12.5K")
  static String formatVolume(int volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(volume >= 10000 ? 0 : 1)}K';
    }
    return volume.toString();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
