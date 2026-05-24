import 'dart:convert';
import 'package:muhafiz/models/app_settings_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/local_storage_service.dart';

class SettingsRepository {
  final LocalStorageService _storage;
  final FirestoreService _firestore;
  final String? userId;
  SettingsRepository(this._storage, this._firestore, {this.userId});

  static const _settingsKey = 'muhafiz_app_settings';

  Future<AppSettingsModel> loadSettings() async {
    try {
      final raw = await _storage.getString(_settingsKey);
      if (raw == null || raw.isEmpty) throw Exception('No local settings');
      return AppSettingsModel.fromJson(jsonDecode(raw));
    } catch (_) {
      if (userId != null) {
        final remote = await _firestore.getDocument('settings', userId!);
        if (remote != null) {
          return AppSettingsModel.fromJson(remote);
        }
      }
      return const AppSettingsModel();
    }
  }

  Future<void> saveSettings(AppSettingsModel settings) async {
    await _storage.saveString(_settingsKey, jsonEncode(settings.toJson()));
    if (userId != null) {
      await _firestore.upsertDocument('settings', userId!, {
        ...settings.toJson(),
        'id': userId,
        'userId': userId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> clearSettings() async {
    await _storage.remove(_settingsKey);
    if (userId != null) {
      await _firestore.deleteDocument('settings', userId!);
    }
  }
}
