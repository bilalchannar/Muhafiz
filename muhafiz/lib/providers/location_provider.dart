import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muhafiz/models/location_snapshot_model.dart';
import 'package:muhafiz/services/location_service.dart';
import 'package:muhafiz/providers/app_service_providers.dart';

final locationProvider = NotifierProvider<LocationNotifier, LocationSnapshot>(LocationNotifier.new);

class LocationNotifier extends Notifier<LocationSnapshot> {
  @override
  LocationSnapshot build() {
    return const LocationSnapshot(status: LocationStatus.unknown);
  }

  LocationService get _service => ref.read(locationServiceProvider);

  Future<void> requestPermission() async {
    final granted = await _service.requestPermission();
    if (granted) {
      await updateLocation();
    } else {
      state = const LocationSnapshot(status: LocationStatus.denied);
    }
  }

  Future<void> updateLocation() async {
    state = await _service.getCurrentLocation();
  }

  void startSharing() {
    _service.startLocationSharing();
    _service.positionStream.listen((snap) {
      state = snap;
    });
  }

  void stopSharing() {
    _service.stopLocationSharing();
  }
}
