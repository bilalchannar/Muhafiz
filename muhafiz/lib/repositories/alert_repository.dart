import 'dart:convert';
import 'package:muhafiz/models/alert_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/local_storage_service.dart';

class AlertRepository {
  final LocalStorageService _storage;
  final FirestoreService _firestore;
  final String? userId;
  AlertRepository(this._storage, this._firestore, {this.userId});

  static const _alertsKey = 'muhafiz_alerts';

  Future<List<AlertModel>> loadAlerts() async {
    List<AlertModel> localAlerts = [];
    try {
      final raw = await _storage.getString(_alertsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        localAlerts = decoded.map((e) => AlertModel.fromJson(e)).toList();
        if (userId != null) {
          localAlerts = localAlerts.where((a) => a.userId == userId).toList();
        }
      }
    } catch (_) {}

    try {
      if (userId == null) return localAlerts;
      final remote = await _firestore.queryCollection(
        'alerts',
        ownerId: userId,
        ownerField: 'userId',
      );
      final remoteAlerts = remote.map(AlertModel.fromJson).toList();
      remoteAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // Update local storage for future offline access
      await _storage.saveString(_alertsKey, jsonEncode(remoteAlerts.map((a) => a.toJson()).toList()));
      return remoteAlerts;
    } catch (_) {
      return localAlerts;
    }
  }

  Future<void> saveAlerts(List<AlertModel> alerts) async {
    final encoded = alerts.map((a) => a.toJson()).toList();
    await _storage.saveString(_alertsKey, jsonEncode(encoded));
    for (final alert in alerts) {
      await _firestore.upsertDocument('alerts', alert.id, alert.toJson());
    }
  }

  Future<void> clearAlerts() async {
    await _storage.remove(_alertsKey);
    if (userId == null) return;
    final remote = await _firestore.queryCollection(
      'alerts',
      ownerId: userId,
      ownerField: 'userId',
    );
    for (final alert in remote) {
      final id = alert['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _firestore.deleteDocument('alerts', id);
      }
    }
  }
}
