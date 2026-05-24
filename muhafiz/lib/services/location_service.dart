import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:muhafiz/models/location_snapshot_model.dart';

class LocationService {
  final StreamController<LocationSnapshot> _controller = StreamController.broadcast();
  Timer? _timer;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!kIsWeb) {
        // openLocationSettings is not supported on web
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return false;
      } else {
        return false;
      }
    }

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    
    if (p == LocationPermission.deniedForever) {
      if (!kIsWeb) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<LocationSnapshot> getLocationStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationSnapshot(status: LocationStatus.serviceDisabled);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationSnapshot(status: LocationStatus.denied);
    }

    try {
      // First try to get last known position quickly
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        return LocationSnapshot(
          status: LocationStatus.granted,
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
          updatedAt: DateTime.now(),
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 4),
      );
      return LocationSnapshot(
        status: LocationStatus.granted,
        latitude: pos.latitude,
        longitude: pos.longitude,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return const LocationSnapshot(status: LocationStatus.unavailable);
    }
  }

  Future<LocationSnapshot> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationSnapshot(status: LocationStatus.serviceDisabled);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const LocationSnapshot(status: LocationStatus.denied);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      );
      return LocationSnapshot(
        status: LocationStatus.granted,
        latitude: pos.latitude,
        longitude: pos.longitude,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return LocationSnapshot(
            status: LocationStatus.granted,
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
            updatedAt: DateTime.now(),
          );
        }
      } catch (_) {}
      return const LocationSnapshot(status: LocationStatus.unavailable);
    }
  }

  Stream<LocationSnapshot> get positionStream => _controller.stream;

  Future<void> startLocationSharing({Duration interval = const Duration(seconds: 15)}) async {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      final snap = await getCurrentLocation();
      if (!_controller.isClosed) _controller.add(snap);
    });
  }

  Future<void> stopLocationSharing() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
