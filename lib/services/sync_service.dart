import 'dart:async';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../models/workout_model.dart';

class SyncService {
  final FirebaseService _firebaseService;
  final StorageService _storageService;

  // Retry state
  Timer? _retryTimer;
  final List<_PendingSync> _pendingSyncs = [];
  static const int _maxRetries = 3;

  SyncService(this._firebaseService, this._storageService) {
    _startRetryTimer();
  }

  /// Start periodic retry timer (every 5 seconds)
  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _processPendingSyncs();
    });
  }

  /// Process pending syncs with retry logic
  Future<void> _processPendingSyncs() async {
    if (_pendingSyncs.isEmpty) return;

    final syncsToRetry = List<_PendingSync>.from(_pendingSyncs);
    
    for (final sync in syncsToRetry) {
      try {
        // Attempt to sync to Firestore
        await _firebaseService.saveWorkout(sync.userId, sync.workout);
        
        // Success - remove from pending
        _pendingSyncs.remove(sync);
        print('Successfully synced workout ${sync.workout.id} on retry ${sync.retryCount}');
      } catch (e) {
        sync.retryCount++;
        
        if (sync.retryCount >= _maxRetries) {
          // Max retries reached - silently give up, data is in local storage
          _pendingSyncs.remove(sync);
          print('Max retries reached for workout ${sync.workout.id}, keeping in local storage only');
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingSyncs.clear();
  }

  /// Migrate local workouts to Firestore
  Future<void> migrateLocalWorkouts(String userId) async {
    try {
      // Get local workouts
      final localWorkouts = await _storageService.getWorkouts();
      
      if (localWorkouts.isEmpty) {
        print('No local workouts to migrate');
        return;
      }

      print('Migrating ${localWorkouts.length} workouts to Firestore...');
      
      // Batch upload to Firestore
      await _firebaseService.batchUploadWorkouts(userId, localWorkouts);
      
      print('Migration complete!');
    } catch (e) {
      print('Error migrating workouts: $e');
      rethrow;
    }
  }

  /// Sync workout to cloud (with offline fallback)
  Future<void> syncWorkout(String? userId, WorkoutLog workout) async {
    // Always save locally first
    await _storageService.saveWorkout(workout);
    
    if (userId == null) {
      // No user, local only
      return;
    }

    try {
      // Try to save to Firestore
      await _firebaseService.saveWorkout(userId, workout);
      print('Workout synced to cloud');
    } catch (e) {
      // Failed to sync - add to retry queue
      print('Failed to sync to cloud, will retry: $e');
      _pendingSyncs.add(_PendingSync(
        userId: userId,
        workout: workout,
        retryCount: 0,
      ));
    }
  }

  /// Get workouts (cloud-first with local fallback)
  Future<List<WorkoutLog>> getWorkouts(String? userId) async {
    if (userId == null) {
      // No user, get from local storage
      return await _storageService.getWorkouts();
    }

    try {
      // Try to get from Firestore
      final cloudWorkouts = await _firebaseService.getWorkouts(userId);
      return cloudWorkouts;
    } catch (e) {
      // Fallback to local storage if offline
      print('Failed to fetch from cloud, using local: $e');
      return await _storageService.getWorkouts();
    }
  }

  /// Get recent workouts for recovery calculation
  Future<List<WorkoutLog>> getRecentWorkouts(String? userId, int days) async {
    if (userId == null) {
      // No user, filter local workouts
      final allWorkouts = await _storageService.getWorkouts();
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      return allWorkouts.where((w) => w.timestamp.isAfter(cutoffDate)).toList();
    }

    try {
      // Get from Firestore
      return await _firebaseService.getRecentWorkouts(userId, days);
    } catch (e) {
      // Fallback to local
      print('Failed to fetch recent from cloud, using local: $e');
      final allWorkouts = await _storageService.getWorkouts();
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      return allWorkouts.where((w) => w.timestamp.isAfter(cutoffDate)).toList();
    }
  }
}

/// Internal class for tracking pending syncs
class _PendingSync {
  final String userId;
  final WorkoutLog workout;
  int retryCount;

  _PendingSync({
    required this.userId,
    required this.workout,
    required this.retryCount,
  });
}
