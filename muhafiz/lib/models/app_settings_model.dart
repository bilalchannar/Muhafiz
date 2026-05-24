class AppSettingsModel {
  final String defaultEmergencyMessage;
  final int emergencyCountdownSeconds;
  final int alertRepeatIntervalMinutes;
  final bool autoShareLocation;
  final bool emergencyNotificationsEnabled;
  final bool vulnerableRemindersEnabled;
  final bool trusteeUpdatesEnabled;
  final bool hideSensitiveAlertContent;
  final bool appLockEnabled;

  const AppSettingsModel({
    this.defaultEmergencyMessage = 'I need help. Please check on me immediately.',
    this.emergencyCountdownSeconds = 10,
    this.alertRepeatIntervalMinutes = 5,
    this.autoShareLocation = true,
    this.emergencyNotificationsEnabled = true,
    this.vulnerableRemindersEnabled = true,
    this.trusteeUpdatesEnabled = true,
    this.hideSensitiveAlertContent = false,
    this.appLockEnabled = false,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      defaultEmergencyMessage: json['defaultEmergencyMessage'] as String? ?? 'I need help. Please check on me immediately.',
      emergencyCountdownSeconds: json['emergencyCountdownSeconds'] as int? ?? 10,
      alertRepeatIntervalMinutes: json['alertRepeatIntervalMinutes'] as int? ?? 5,
      autoShareLocation: json['autoShareLocation'] as bool? ?? true,
      emergencyNotificationsEnabled: json['emergencyNotificationsEnabled'] as bool? ?? true,
      vulnerableRemindersEnabled: json['vulnerableRemindersEnabled'] as bool? ?? true,
      trusteeUpdatesEnabled: json['trusteeUpdatesEnabled'] as bool? ?? true,
      hideSensitiveAlertContent: json['hideSensitiveAlertContent'] as bool? ?? false,
      appLockEnabled: json['appLockEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultEmergencyMessage': defaultEmergencyMessage,
      'emergencyCountdownSeconds': emergencyCountdownSeconds,
      'alertRepeatIntervalMinutes': alertRepeatIntervalMinutes,
      'autoShareLocation': autoShareLocation,
      'emergencyNotificationsEnabled': emergencyNotificationsEnabled,
      'vulnerableRemindersEnabled': vulnerableRemindersEnabled,
      'trusteeUpdatesEnabled': trusteeUpdatesEnabled,
      'hideSensitiveAlertContent': hideSensitiveAlertContent,
      'appLockEnabled': appLockEnabled,
    };
  }

  AppSettingsModel copyWith({
    String? defaultEmergencyMessage,
    int? emergencyCountdownSeconds,
    int? alertRepeatIntervalMinutes,
    bool? autoShareLocation,
    bool? emergencyNotificationsEnabled,
    bool? vulnerableRemindersEnabled,
    bool? trusteeUpdatesEnabled,
    bool? hideSensitiveAlertContent,
    bool? appLockEnabled,
  }) {
    return AppSettingsModel(
      defaultEmergencyMessage: defaultEmergencyMessage ?? this.defaultEmergencyMessage,
      emergencyCountdownSeconds: emergencyCountdownSeconds ?? this.emergencyCountdownSeconds,
      alertRepeatIntervalMinutes: alertRepeatIntervalMinutes ?? this.alertRepeatIntervalMinutes,
      autoShareLocation: autoShareLocation ?? this.autoShareLocation,
      emergencyNotificationsEnabled: emergencyNotificationsEnabled ?? this.emergencyNotificationsEnabled,
      vulnerableRemindersEnabled: vulnerableRemindersEnabled ?? this.vulnerableRemindersEnabled,
      trusteeUpdatesEnabled: trusteeUpdatesEnabled ?? this.trusteeUpdatesEnabled,
      hideSensitiveAlertContent: hideSensitiveAlertContent ?? this.hideSensitiveAlertContent,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    );
  }
}
