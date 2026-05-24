import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:muhafiz/core/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/models/trustee_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/location_service.dart';
import 'package:muhafiz/services/notification_service.dart';

class AlertDeliveryService {
  final FirestoreService firestoreService;
  final NotificationService notificationService;
  final LocationService locationService;
  Timer? _realtimeServiceTimer;

  AlertDeliveryService({
    required this.firestoreService,
    required this.notificationService,
    required this.locationService,
  });

  Future<void> sendMassMessage(List<String> phones, String message) async {
    if (phones.isEmpty) return;
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sendMassMsg'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phones, 'message': message}),
      );
    } catch (e) {
      // Ignore errors for now
    }
  }

  Future<void> stopRealtimeService() async {
    _realtimeServiceTimer?.cancel();
    _realtimeServiceTimer = null;
    
    final prefs = await SharedPreferences.getInstance();

    final bool wasActive = prefs.getBool('bg_active') ?? false;
    if (wasActive) {
      final List<String> phones = prefs.getStringList('bg_phones') ?? [];
      if (phones.isNotEmpty) {
        final String? userRaw = prefs.getString('muhafiz_user');
        String userName = 'User';
        if (userRaw != null && userRaw.isNotEmpty) {
          try {
            final Map<String, dynamic> userMap = jsonDecode(userRaw);
            userName = userMap['name'] ?? 'User';
          } catch (_) {}
        }
        await sendMassMessage(
          phones,
          "I'm safe now. ($userName's safety mode has been turned off.)",
        );
      }
    }

    await prefs.setBool('bg_active', false);
    
    if (!kIsWeb) {
      FlutterBackgroundService().invoke('stopService');
    }
  }

  Future<bool> createEmergencyAlert({
    required String userId,
    required String message,
    required List<TrusteeModel> trustees,
    required bool includeLocation,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userRaw = prefs.getString('muhafiz_user');
      String userName = 'User';
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final Map<String, dynamic> userMap = jsonDecode(userRaw);
          userName = userMap['name'] ?? 'User';
        } catch (_) {}
      }

      final String messageWithUser = 'Emergency SOS Alert from $userName: $message';
      double? lat;
      double? lng;
      String finalMessage = messageWithUser;

      if (includeLocation) {
        final loc = await locationService.getCurrentLocation();
        lat = loc.latitude;
        lng = loc.longitude;
        if (lat != null && lng != null) {
          finalMessage += '\nLocation: https://maps.google.com/?q=$lat,$lng';
        }
      }

      final alert = AlertModel(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        type: AlertType.emergency,
        status: AlertStatus.sent,
        message: messageWithUser,
        latitude: lat,
        longitude: lng,
        sentToTrusteeIds: trustees.map((t) => t.id).toList(),
        createdAt: DateTime.now(),
      );

      // Extract phone numbers and send immediately
      final phones = trustees.map((t) => t.phone).toList();
      await sendMassMessage(phones, finalMessage);

      await prefs.setBool('bg_active', true);
      await prefs.setInt('bg_interval', 30);
      await prefs.setStringList('bg_phones', phones);
      await prefs.setString('bg_message', messageWithUser);
      await prefs.setBool('bg_location', includeLocation);
      await prefs.setInt('bg_last_run', DateTime.now().millisecondsSinceEpoch);

      if (!kIsWeb) {
        final service = FlutterBackgroundService();
        await service.startService();
      }

      return await sendEmergencyAlert(alert);
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendEmergencyAlert(AlertModel alert) async {
    try {
      // 1. Save alert to Firestore
      await firestoreService.upsertDocument('alerts', alert.id, alert.toJson());

      // 2. Notify locally
      if (!kIsWeb) {
        await notificationService.showNotification(
          id: 1,
          title: 'Emergency SOS Sent',
          body: 'Your trusted contacts have been notified.',
        );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> createVulnerableSession({
    required String userId,
    required String message,
    required int checkInMinutes,
    required List<TrusteeModel> trustees,
    required bool includeLocation,
  }) async {
    try {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final prefs = await SharedPreferences.getInstance();

      final String? userRaw = prefs.getString('muhafiz_user');
      String userName = 'User';
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final Map<String, dynamic> userMap = jsonDecode(userRaw);
          userName = userMap['name'] ?? 'User';
        } catch (_) {}
      }

      final String messageWithUser = 'Protective Mode Alert from $userName: $message';
      double? lat;
      double? lng;
      String finalMessage = messageWithUser;

      if (includeLocation) {
        final loc = await locationService.getCurrentLocation();
        lat = loc.latitude;
        lng = loc.longitude;
        if (lat != null && lng != null) {
          finalMessage += '\nLocation: https://maps.google.com/?q=$lat,$lng';
        }
      }

      final sessionData = {
        'id': sessionId,
        'userId': userId,
        'message': messageWithUser,
        'interval': checkInMinutes,
        'trustees': trustees.map((t) => t.toJson()).toList(),
        'active': true,
        'latitude': lat,
        'longitude': lng,
        'startedAt': DateTime.now().toIso8601String(),
        'lastCheckInAt': DateTime.now().toIso8601String(),
      };

      await firestoreService.upsertDocument(
        'safety_sessions',
        sessionId,
        sessionData,
      );

      // Save a Vulnerable Alert to the alert history
      final alert = AlertModel(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        type: AlertType.vulnerable,
        status: AlertStatus.sent,
        message: messageWithUser,
        latitude: lat,
        longitude: lng,
        sentToTrusteeIds: trustees.map((t) => t.id).toList(),
        createdAt: DateTime.now(),
      );
      await sendVulnerableAlert(alert);

      if (!kIsWeb) {
        await notificationService.showNotification(
          id: 2,
          title: 'Protective Mode Active',
          body:
              'Safe travels. We will check in on you every $checkInMinutes minutes.',
        );
      }

      final phones = trustees.map((t) => t.phone).toList();

      // Send initial message immediately
      await sendMassMessage(phones, finalMessage);

      await prefs.setBool('bg_active', true);
      await prefs.setInt('bg_interval', checkInMinutes * 60);
      await prefs.setStringList('bg_phones', phones);
      await prefs.setString('bg_message', messageWithUser);
      await prefs.setBool('bg_location', includeLocation);
      await prefs.setInt('bg_last_run', DateTime.now().millisecondsSinceEpoch);

      if (!kIsWeb) {
        final service = FlutterBackgroundService();
        await service.startService();
      }
    } catch (e) {
      // Log error
    }
  }

  Future<bool> sendVulnerableAlert(AlertModel alert) async {
    try {
      await firestoreService.upsertDocument('alerts', alert.id, alert.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> notifyTrustees(List<String> trusteeIds, String message) async {
    // This would typically be handled by Firebase Cloud Messaging (FCM)
    // triggered by a Firestore update or a Cloud Function.
  }
}
