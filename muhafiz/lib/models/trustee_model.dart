class TrusteeModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final String priority; // primary, secondary, backup
  final bool receivesEmergencyAlerts;
  final bool receivesLocationUpdates;
  final bool receivesVulnerableModeAlerts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrusteeModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.priority,
    this.receivesEmergencyAlerts = true,
    this.receivesLocationUpdates = true,
    this.receivesVulnerableModeAlerts = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TrusteeModel.fromJson(Map<String, dynamic> json) {
    return TrusteeModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'Contact',
      priority: json['priority'] as String? ?? json['tier'] as String? ?? 'secondary',
      receivesEmergencyAlerts: json['receivesEmergencyAlerts'] as bool? ?? true,
      receivesLocationUpdates: json['receivesLocationUpdates'] as bool? ?? true,
      receivesVulnerableModeAlerts: json['receivesVulnerableModeAlerts'] as bool? ?? true,
      createdAt: json['createdAt'] != null || json['added_at'] != null
          ? DateTime.tryParse((json['createdAt'] ?? json['added_at']).toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': priority,
      'receivesEmergencyAlerts': receivesEmergencyAlerts,
      'receivesLocationUpdates': receivesLocationUpdates,
      'receivesVulnerableModeAlerts': receivesVulnerableModeAlerts,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Returns first letter(s) for avatar display
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  TrusteeModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? relationship,
    String? priority,
    bool? receivesEmergencyAlerts,
    bool? receivesLocationUpdates,
    bool? receivesVulnerableModeAlerts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrusteeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      receivesEmergencyAlerts: receivesEmergencyAlerts ?? this.receivesEmergencyAlerts,
      receivesLocationUpdates: receivesLocationUpdates ?? this.receivesLocationUpdates,
      receivesVulnerableModeAlerts: receivesVulnerableModeAlerts ?? this.receivesVulnerableModeAlerts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Compatibility getter for 'tier'
  String get tier => priority;
}
