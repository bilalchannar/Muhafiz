enum AlertType { emergency, vulnerable }

enum AlertStatus { pending, sent, cancelled, failed, delivered }

class AlertModel {
  final String id;
  final String userId;
  final AlertType type;
  final AlertStatus status;
  final String message;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> sentToTrusteeIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AlertModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.message,
    this.latitude,
    this.longitude,
    this.address,
    required this.sentToTrusteeIds,
    required this.createdAt,
    this.updatedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => AlertType.emergency,
      ),
      status: AlertStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => AlertStatus.pending,
      ),
      message: json['message'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      sentToTrusteeIds: List<String>.from(json['sentToTrusteeIds'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'status': status.name,
      'message': message,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      'sentToTrusteeIds': sentToTrusteeIds,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  AlertModel copyWith({
    String? id,
    String? userId,
    AlertType? type,
    AlertStatus? status,
    String? message,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? sentToTrusteeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      message: message ?? this.message,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      sentToTrusteeIds: sentToTrusteeIds ?? this.sentToTrusteeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
