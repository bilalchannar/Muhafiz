import 'dart:convert';
import 'package:muhafiz/models/safety_mode_model.dart';
import 'package:muhafiz/services/local_storage_service.dart';

class SafetyModeRepository {
  final LocalStorageService _storage;
  SafetyModeRepository(this._storage);

  static const _modeKey = 'muhafiz_mode_state';

  Future<SafetyModeModel> loadSafetyMode() async {
    try {
      final raw = await _storage.getString(_modeKey);
      if (raw == null || raw.isEmpty) return const SafetyModeModel();
      return SafetyModeModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return const SafetyModeModel();
    }
  }

  Future<void> saveSafetyMode(SafetyModeModel mode) async {
    await _storage.saveString(_modeKey, jsonEncode(mode.toJson()));
  }

  Future<void> clearSafetyMode() async {
    await _storage.remove(_modeKey);
  }
}
