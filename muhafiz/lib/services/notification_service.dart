import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:muhafiz/services/firebase_bootstrap.dart';

class NotificationService {
  NotificationService._();

  /// Singleton instance used throughout the app.
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

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
      settings: initSettings,
    );

    const channel = AndroidNotificationChannel(
      'muhafiz_channel',
      'Muhafiz Alerts',
      description: 'Emergency and safety alerts from Muhafiz.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  // ─── Local Notifications ─────────────────────────────────────────────────

  /// Show an immediate local notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'muhafiz_channel',
      'Muhafiz Alerts',
      channelDescription: 'Emergency and safety alerts from Muhafiz.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Convenience wrapper kept for backward compatibility with older call-sites.
  Future<void> sendLocalNotification(String title, String body) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
    );
  }

  Future<void> scheduleReminder(
    String title,
    String body,
    Duration delay,
  ) async {
    // TODO: Implement scheduling via flutter_local_notifications zonedSchedule.
  }

  Future<void> cancelAllReminders() async {
    await _localNotifications.cancelAll();
  }

  // ─── FCM ─────────────────────────────────────────────────────────────────

  /// Returns the FCM token, or null when Firebase is not available.
  Future<String?> getFcmToken() async {
    if (!FirebaseBootstrap.isReady) {
      return null;
    }

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
