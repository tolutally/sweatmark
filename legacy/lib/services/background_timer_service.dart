import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for running rest timer in background with notifications
class BackgroundTimerService {
  static final BackgroundTimerService _instance = BackgroundTimerService._internal();
  factory BackgroundTimerService() => _instance;
  BackgroundTimerService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  
  // Notification IDs
  static const int _restTimerNotificationId = 999;
  static const String _restTimerChannelId = 'sweatmark_rest_timer';
  
  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Create rest timer notification channel (Android only)
    if (Platform.isAndroid) {
      await _createRestTimerChannel();
    }
    
    // Configure the background service
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        onStart: _onStart,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: _restTimerChannelId,
        initialNotificationTitle: 'Rest Timer',
        initialNotificationContent: 'Timer running...',
        foregroundServiceNotificationId: _restTimerNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.shortService],
      ),
    );
    
    _isInitialized = true;
    debugPrint('✅ BackgroundTimerService initialized');
  }
  
  /// Create notification channel for rest timer (silent, low importance)
  Future<void> _createRestTimerChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;
    
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _restTimerChannelId,
        'Rest Timer',
        description: 'Shows rest timer countdown during workouts',
        importance: Importance.low, // Silent but visible
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    
    debugPrint('✅ Rest timer notification channel created');
  }
  
  /// Start the background timer service
  Future<void> startTimer(int durationSeconds) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Start the service
    await _service.startService();
    
    // Send timer data to the service
    _service.invoke('startTimer', {
      'duration': durationSeconds,
      'startTime': DateTime.now().millisecondsSinceEpoch,
    });
    
    debugPrint('🏃 Background timer started: ${durationSeconds}s');
  }
  
  /// Stop the background timer service
  Future<void> stopTimer() async {
    _service.invoke('stopTimer');
    
    // Cancel the notification
    await _localNotifications.cancel(_restTimerNotificationId);
    
    debugPrint('⏹️ Background timer stopped');
  }
  
  /// Update the timer notification (called from foreground)
  Future<void> updateTimerNotification(int remainingSeconds) async {
    if (!Platform.isAndroid) return;
    
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    await _localNotifications.show(
      _restTimerNotificationId,
      'Rest Timer',
      'Time remaining: $timeString',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _restTimerChannelId,
          'Rest Timer',
          channelDescription: 'Shows rest timer countdown during workouts',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          showWhen: false,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF5EDDC8),
        ),
      ),
    );
  }
  
  /// Show timer complete notification
  Future<void> showTimerCompleteNotification() async {
    await _localNotifications.show(
      _restTimerNotificationId + 1, // Different ID so it doesn't replace ongoing
      '⏱️ Rest Complete!',
      'Time to start your next set',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _restTimerChannelId,
          'Rest Timer',
          channelDescription: 'Shows rest timer countdown during workouts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false, // Haptic only as per user request
          enableVibration: true,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF5EDDC8),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
    
    // Cancel the ongoing timer notification
    await _localNotifications.cancel(_restTimerNotificationId);
  }
  
  /// Schedule a notification for when the timer should complete (for iOS background)
  Future<void> scheduleTimerCompleteNotification(int secondsFromNow) async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
    
    await _localNotifications.zonedSchedule(
      _restTimerNotificationId + 2,
      '⏱️ Rest Complete!',
      'Time to start your next set',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _restTimerChannelId,
          'Rest Timer',
          channelDescription: 'Shows rest timer countdown during workouts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF5EDDC8),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    debugPrint('📅 Scheduled timer complete notification for $scheduledTime');
  }
  
  /// Cancel the scheduled timer complete notification
  Future<void> cancelScheduledNotification() async {
    await _localNotifications.cancel(_restTimerNotificationId + 2);
  }
  
  /// Check if the service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}

/// Background service entry point
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  
  int? remainingSeconds;
  Timer? countdownTimer;
  
  service.on('startTimer').listen((event) {
    if (event == null) return;
    
    final duration = event['duration'] as int?;
    if (duration == null) return;
    
    remainingSeconds = duration;
    
    // Cancel existing timer
    countdownTimer?.cancel();
    
    // Start countdown
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (remainingSeconds != null && remainingSeconds! > 0) {
        remainingSeconds = remainingSeconds! - 1;
        
        // Update notification
        if (service is AndroidServiceInstance) {
          final minutes = remainingSeconds! ~/ 60;
          final seconds = remainingSeconds! % 60;
          final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          
          service.setForegroundNotificationInfo(
            title: 'Rest Timer',
            content: 'Time remaining: $timeString',
          );
        }
        
        // Send update to UI
        service.invoke('timerUpdate', {'remaining': remainingSeconds});
      } else {
        // Timer complete
        countdownTimer?.cancel();
        service.invoke('timerComplete');
        
        // Show completion notification
        await notifications.show(
          1000,
          '⏱️ Rest Complete!',
          'Time to start your next set',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'sweatmark_rest_timer',
              'Rest Timer',
              importance: Importance.high,
              priority: Priority.high,
              playSound: false,
              enableVibration: true,
            ),
          ),
        );
        
        // Stop service after completion
        service.stopSelf();
      }
    });
  });
  
  service.on('stopTimer').listen((event) {
    countdownTimer?.cancel();
    remainingSeconds = null;
    service.stopSelf();
  });
  
  service.on('stop').listen((event) {
    countdownTimer?.cancel();
    service.stopSelf();
  });
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
