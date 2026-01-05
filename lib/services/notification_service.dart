import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
}

/// Service for handling push notifications and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification channel IDs
  static const String _workoutChannelId = 'sweatmark_workouts';
  static const String _reminderChannelId = 'sweatmark_reminders';
  static const String _generalChannelId = 'sweatmark_general';
  static const String _restTimerChannelId = 'sweatmark_rest_timer';
  
  // Rest timer notification ID
  static const int _restTimerNotificationId = 999;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data for scheduled notifications
    tz_data.initializeTimeZones();

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set up FCM handlers
    _setupFCMHandlers();

    // Get FCM token
    await _getFCMToken();

    _isInitialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // iOS/macOS permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

    // Android 13+ permissions
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Workout reminders channel (high importance)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        'Workout Reminders',
        description: 'Scheduled workout reminder notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // General notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _generalChannelId,
        'General',
        description: 'General app notifications',
        importance: Importance.defaultImportance,
      ),
    );

    // Workout progress channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _workoutChannelId,
        'Workout Updates',
        description: 'Workout progress and achievement notifications',
        importance: Importance.defaultImportance,
      ),
    );
    
    // Rest timer channel (silent but visible)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _restTimerChannelId,
        'Rest Timer',
        description: 'Shows rest timer countdown during workouts',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  /// Set up Firebase Cloud Messaging handlers
  void _setupFCMHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Get and log FCM token
  Future<String?> _getFCMToken() async {
    try {
      // On iOS, we need to get APNS token first
      if (Platform.isIOS) {
        final apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⚠️ APNS token not available yet, waiting...');
          // Wait a bit and try again
          await Future.delayed(const Duration(seconds: 2));
          final retryToken = await _fcm.getAPNSToken();
          if (retryToken == null) {
            debugPrint('❌ APNS token still not available');
            return null;
          }
          debugPrint('✅ APNS Token obtained: $retryToken');
        } else {
          debugPrint('✅ APNS Token: $apnsToken');
        }
      }

      final token = await _fcm.getToken();
      debugPrint('🔑 FCM Token: $token');

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        // TODO: Send new token to backend if needed
      });

      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground FCM messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 Foreground message: ${message.notification?.title}');

    // Show local notification for foreground messages
    if (message.notification != null) {
      await showNotification(
        title: message.notification!.title ?? 'SweatMark',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
    // TODO: Navigate to appropriate screen based on message data
  }

  /// Check for initial message when app opens from terminated state
  Future<void> _checkInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      debugPrint('🚀 App opened from notification: ${message.data}');
      // TODO: Navigate to appropriate screen
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  // ============================================
  // PUBLIC API
  // ============================================

  /// Show an immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _generalChannelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _reminderChannelId
          ? 'Workout Reminders'
          : channelId == _workoutChannelId
              ? 'Workout Updates'
              : 'General',
      importance: channelId == _reminderChannelId
          ? Importance.high
          : Importance.defaultImportance,
      priority: channelId == _reminderChannelId
          ? Priority.high
          : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF5EDDC8), // brandTeal
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule a workout reminder notification
  Future<int> scheduleWorkoutReminder({
    required String workoutName,
    required DateTime scheduledTime,
    String? templateId,
  }) async {
    // Generate unique notification ID
    final notificationId = scheduledTime.millisecondsSinceEpoch.remainder(100000);

    final androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Workout Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF5EDDC8),
      styleInformation: BigTextStyleInformation(
        "Time to get moving! Your scheduled workout is ready.",
        contentTitle: "🏋️ $workoutName",
        summaryText: 'Tap to start your workout',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert to timezone-aware datetime
    final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _localNotifications.zonedSchedule(
      notificationId,
      '🏋️ $workoutName',
      "Time to get moving! Your scheduled workout is ready.",
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: templateId,
    );

    debugPrint('📅 Scheduled reminder for "$workoutName" at $scheduledTime (ID: $notificationId)');
    return notificationId;
  }

  /// Schedule repeating workout reminders
  Future<List<int>> scheduleRepeatingReminders({
    required String workoutName,
    required List<int> weekdays, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? templateId,
  }) async {
    final notificationIds = <int>[];

    for (final weekday in weekdays) {
      final notificationId = await _scheduleWeeklyReminder(
        workoutName: workoutName,
        weekday: weekday,
        hour: hour,
        minute: minute,
        templateId: templateId,
      );
      notificationIds.add(notificationId);
    }

    return notificationIds;
  }

  /// Schedule a weekly reminder for a specific day
  Future<int> _scheduleWeeklyReminder({
    required String workoutName,
    required int weekday,
    required int hour,
    required int minute,
    String? templateId,
  }) async {
    final notificationId = '$workoutName-$weekday'.hashCode.abs();

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Workout Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF5EDDC8),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Calculate next occurrence of this weekday
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Find the next occurrence of the target weekday
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      notificationId,
      '🏋️ $workoutName',
      "Time for your scheduled workout!",
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: templateId,
    );

    debugPrint('📅 Scheduled weekly reminder for "$workoutName" on weekday $weekday at $hour:$minute');
    return notificationId;
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
    debugPrint('🗑️ Cancelled notification: $notificationId');
  }

  /// Cancel all notifications for a template
  Future<void> cancelTemplateReminders(String templateId, List<int> weekdays) async {
    for (final weekday in weekdays) {
      final notificationId = '$templateId-$weekday'.hashCode.abs();
      await _localNotifications.cancel(notificationId);
    }
    debugPrint('🗑️ Cancelled all reminders for template: $templateId');
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('🗑️ Cancelled all notifications');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  /// Show a workout completion notification
  Future<void> showWorkoutCompleteNotification({
    required String workoutName,
    required Duration duration,
    int? exerciseCount,
  }) async {
    final minutes = duration.inMinutes;
    final body = exerciseCount != null
        ? 'Great job! You completed $exerciseCount exercises in $minutes minutes.'
        : 'Great job! Workout completed in $minutes minutes.';

    await showNotification(
      title: '🎉 $workoutName Complete!',
      body: body,
      channelId: _workoutChannelId,
    );
  }

  /// Show a PR (Personal Record) notification
  Future<void> showPRNotification({
    required String exerciseName,
    required String newRecord,
  }) async {
    await showNotification(
      title: '🏆 New Personal Record!',
      body: 'You hit a new PR on $exerciseName: $newRecord',
      channelId: _workoutChannelId,
    );
  }
  
  // ============================================
  // REST TIMER NOTIFICATIONS
  // ============================================
  
  /// Show/update the rest timer notification (Android only - silent, ongoing)
  Future<void> showRestTimerNotification(int remainingSeconds) async {
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
  
  /// Cancel the rest timer notification
  Future<void> cancelRestTimerNotification() async {
    await _localNotifications.cancel(_restTimerNotificationId);
  }
  
  /// Schedule a rest timer complete notification (for iOS background)
  Future<void> scheduleRestTimerCompleteNotification(int secondsFromNow) async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
    
    await _localNotifications.zonedSchedule(
      _restTimerNotificationId + 1,
      '⏱️ Rest Complete!',
      'Time to start your next set',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _restTimerChannelId,
          'Rest Timer',
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
    
    debugPrint('📅 Scheduled rest timer complete: $scheduledTime');
  }
  
  /// Cancel the scheduled rest timer complete notification
  Future<void> cancelScheduledRestTimerNotification() async {
    await _localNotifications.cancel(_restTimerNotificationId + 1);
  }
  
  /// Show rest timer complete notification (immediate)
  Future<void> showRestTimerCompleteNotification() async {
    await showNotification(
      title: '⏱️ Rest Complete!',
      body: 'Time to start your next set',
      channelId: _restTimerChannelId,
    );
    
    // Cancel the ongoing timer notification
    await cancelRestTimerNotification();
  }

  /// Subscribe to a topic for targeted notifications
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('📬 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('📭 Unsubscribed from topic: $topic');
  }
}
