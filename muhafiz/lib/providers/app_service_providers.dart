import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/services/alert_delivery_service.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/location_service.dart';
import 'package:muhafiz/services/notification_service.dart';
import 'package:muhafiz/services/local_storage_service.dart';

final storageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final alertDeliveryServiceProvider = Provider<AlertDeliveryService>((ref) {
  return AlertDeliveryService(
    firestoreService: ref.watch(firestoreServiceProvider),
    notificationService: ref.watch(notificationServiceProvider),
    locationService: ref.watch(locationServiceProvider),
  );
});
