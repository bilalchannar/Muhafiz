enum LocationStatus {
  unknown,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unavailable,
}

class LocationSnapshot {
  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? updatedAt;

  const LocationSnapshot({
    required this.status,
    this.latitude,
    this.longitude,
    this.address,
    this.updatedAt,
  });

  const LocationSnapshot.unknown()
      : status = LocationStatus.unknown,
        latitude = null,
        longitude = null,
        address = null,
        updatedAt = null;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get statusLabel {
    switch (status) {
      case LocationStatus.granted:
        return hasCoordinates ? 'Location ready' : 'Permission granted';
      case LocationStatus.requesting:
        return 'Requesting location';
      case LocationStatus.denied:
        return 'Permission denied';
      case LocationStatus.permanentlyDenied:
        return 'Location permission permanently denied. Please enable it in Settings.';
      case LocationStatus.serviceDisabled:
        return 'Location disabled';
      case LocationStatus.unavailable:
        return 'Location unavailable';
      case LocationStatus.unknown:
        return 'Location not checked';
    }
  }

  String get coordinatesLabel {
    if (!hasCoordinates) return 'No coordinates yet';
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    return LocationSnapshot(
      status: LocationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LocationStatus.unknown,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  LocationSnapshot copyWith({
    LocationStatus? status,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? updatedAt,
  }) {
    return LocationSnapshot(
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
