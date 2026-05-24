enum SafetyMode { normal, emergency, vulnerable }

class SafetyModeModel {
  final SafetyMode currentMode;
  final bool emergencyActive;
  final bool vulnerableActive;
  final String vulnerableMessage;
  final int checkInIntervalMinutes;
  final DateTime? emergencyStartedAt;
  final DateTime? vulnerableStartedAt;
  final DateTime? lastCheckInAt;

  const SafetyModeModel({
    this.currentMode = SafetyMode.normal,
    this.emergencyActive = false,
    this.vulnerableActive = false,
    this.vulnerableMessage = 'I may need help. Please check on me.',
    this.checkInIntervalMinutes = 30,
    this.emergencyStartedAt,
    this.vulnerableStartedAt,
    this.lastCheckInAt,
  });

  factory SafetyModeModel.fromJson(Map<String, dynamic> json) {
    return SafetyModeModel(
      currentMode: SafetyMode.values.firstWhere(
        (e) => e.name == (json['currentMode'] as String? ?? json['mode'] as String?),
        orElse: () => SafetyMode.normal,
      ),
      emergencyActive: json['emergencyActive'] as bool? ?? (json['mode'] == 'emergency'),
      vulnerableActive: json['vulnerableActive'] as bool? ?? (json['mode'] == 'vulnerable'),
      vulnerableMessage: json['vulnerableMessage'] as String? ?? json['message'] as String? ?? 'I may need help. Please check on me.',
      checkInIntervalMinutes: json['checkInIntervalMinutes'] as int? ?? json['intervalMinutes'] as int? ?? 30,
      emergencyStartedAt: json['emergencyStartedAt'] != null
          ? DateTime.tryParse(json['emergencyStartedAt'].toString())
          : null,
      vulnerableStartedAt: json['vulnerableStartedAt'] != null
          ? DateTime.tryParse(json['vulnerableStartedAt'].toString())
          : null,
      lastCheckInAt: json['lastCheckInAt'] != null
          ? DateTime.tryParse(json['lastCheckInAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentMode': currentMode.name,
      'emergencyActive': emergencyActive,
      'vulnerableActive': vulnerableActive,
      'vulnerableMessage': vulnerableMessage,
      'checkInIntervalMinutes': checkInIntervalMinutes,
      if (emergencyStartedAt != null) 'emergencyStartedAt': emergencyStartedAt!.toIso8601String(),
      if (vulnerableStartedAt != null) 'vulnerableStartedAt': vulnerableStartedAt!.toIso8601String(),
      if (lastCheckInAt != null) 'lastCheckInAt': lastCheckInAt!.toIso8601String(),
    };
  }

  SafetyModeModel copyWith({
    SafetyMode? currentMode,
    bool? emergencyActive,
    bool? vulnerableActive,
    String? vulnerableMessage,
    int? checkInIntervalMinutes,
    DateTime? emergencyStartedAt,
    DateTime? vulnerableStartedAt,
    DateTime? lastCheckInAt,
  }) {
    return SafetyModeModel(
      currentMode: currentMode ?? this.currentMode,
      emergencyActive: emergencyActive ?? this.emergencyActive,
      vulnerableActive: vulnerableActive ?? this.vulnerableActive,
      vulnerableMessage: vulnerableMessage ?? this.vulnerableMessage,
      checkInIntervalMinutes: checkInIntervalMinutes ?? this.checkInIntervalMinutes,
      emergencyStartedAt: emergencyStartedAt ?? this.emergencyStartedAt,
      vulnerableStartedAt: vulnerableStartedAt ?? this.vulnerableStartedAt,
      lastCheckInAt: lastCheckInAt ?? this.lastCheckInAt,
    );
  }
}
