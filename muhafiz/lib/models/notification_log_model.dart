class NotificationLogModel {
  final String id;
  final String? alertId;
  final String? userId;
  final String trusteeId;
  final String trusteeName;
  final String channel;
  final String status;
  final String message;
  final DateTime createdAt;

  const NotificationLogModel({
    required this.id,
    this.alertId,
    this.userId,
    required this.trusteeId,
    required this.trusteeName,
    required this.channel,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory NotificationLogModel.fromJson(Map<String, dynamic> json) {
    return NotificationLogModel(
      id: json['id'] as String? ?? '',
      alertId: json['alertId'] as String?,
      userId: json['userId'] as String?,
      trusteeId: json['trusteeId'] as String? ?? '',
      trusteeName: json['trusteeName'] as String? ?? '',
      channel: json['channel'] as String? ?? 'push',
      status: json['status'] as String? ?? 'queued',
      message: json['message'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
