import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:muhafiz/core/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'muhafiz_foreground',
    'Muhafiz Safety Service',
    description: 'This channel is used for important safety notifications.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'muhafiz_foreground',
      initialNotificationTitle: 'Muhafiz Active',
      initialNotificationContent: 'Monitoring your safety in the background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Check every 5 seconds if an alert should be sent based on SharedPreferences
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    // Reload prefs in case they were modified by the main isolate
    await prefs.reload();

    // final active = prefs.getBool('bg_active') ?? false;
    // print('BG Service Tick - active: $active');
    // if (!active) return;

    final int intervalSeconds = prefs.getInt('bg_interval') ?? 30;
    final int lastRun = prefs.getInt('bg_last_run') ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    
    // print('BG Service - now: $now, lastRun: $lastRun, diff: ${now - lastRun}, required: ${intervalSeconds * 1000}');

    if (now - lastRun < (intervalSeconds * 1000)) {
      return;
    }
    
    // print('BG Service - Triggering alert! Interval passed.');
    await prefs.setInt('bg_last_run', now);

    final List<String> phones = prefs.getStringList('bg_phones') ?? [];
    final String message = prefs.getString('bg_message') ?? '';
    final bool includeLocation = prefs.getBool('bg_location') ?? false;

    String finalMessage = message;
    if (includeLocation) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        ).timeout(const Duration(seconds: 10));
        finalMessage +=
            '\nLocation: https://maps.google.com/?q=${position.latitude},${position.longitude}';
      } catch (_) {}
    }

    try {
      // print('BG Service - Sending mass message to ${phones.length} contacts...');
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sendMassMsg'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phones, 'message': finalMessage}),
      );
      // print('BG Service - Message sent, status: ${response.statusCode}');
    } catch (e) {
      // print('BG Service - Failed to send message: $e');
    }
  });
}
