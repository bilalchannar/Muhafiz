import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> saveString(String key, String value) async {
    await init();
    return await _prefs!.setString(key, value);
  }

  Future<String?> getString(String key) async {
    await init();
    return _prefs?.getString(key);
  }

  Future<bool> saveBool(String key, bool value) async {
    await init();
    return await _prefs!.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    await init();
    return _prefs?.getBool(key);
  }

  Future<bool> saveInt(String key, int value) async {
    await init();
    return await _prefs!.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    await init();
    return _prefs?.getInt(key);
  }

  Future<bool> remove(String key) async {
    await init();
    return await _prefs!.remove(key);
  }

  Future<bool> clear() async {
    await init();
    return await _prefs!.clear();
  }
}
