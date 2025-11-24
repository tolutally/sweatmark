import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../models/workout_model.dart';

class SyncService {
  final FirebaseService _firebaseService;
  final StorageService _storageService;

  SyncService(this._firebaseService, this._storageService);

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
    if (userId == null) {
      // No user, save locally only
      await _storageService.saveWorkout(workout);
      return;
    }

    try {
      // Try to save to Firestore
      await _firebaseService.saveWorkout(userId, workout);
      print('Workout synced to cloud');
    } catch (e) {
      // Fallback to local storage if offline
      print('Failed to sync to cloud, saving locally: $e');
      await _storageService.saveWorkout(workout);
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
