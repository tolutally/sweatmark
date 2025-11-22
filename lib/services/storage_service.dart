import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/workout_model.dart';

class StorageService {
  static const String _fileName = 'workout_logs.json';

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  Future<void> saveWorkout(WorkoutLog log) async {
    final List<WorkoutLog> logs = await getWorkouts();
    logs.add(log);
    
    final file = File(await _getFilePath());
    final jsonList = logs.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<List<WorkoutLog>> getWorkouts() async {
    try {
      final file = File(await _getFilePath());
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => WorkoutLog.fromJson(e)).toList();
    } catch (e) {
      print('Error reading workouts: $e');
      return [];
    }
  }
}
