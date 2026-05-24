import 'dart:convert';
import 'package:muhafiz/models/user_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/local_storage_service.dart';

class UserRepository {
  final LocalStorageService _storage;
  final FirestoreService _firestore;
  UserRepository(this._storage, this._firestore);

  static const _userKey = 'muhafiz_user';

  Future<UserModel?> loadUser() async {
    try {
      final raw = await _storage.getString(_userKey);
      if (raw == null || raw.isEmpty) return null;
      return UserModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    await _storage.saveString(_userKey, jsonEncode(user.toJson()));
    await _firestore.upsertDocument('users', user.id, user.toJson());
  }

  Future<void> clearUser(String? userId) async {
    await _storage.remove(_userKey);
    if (userId != null && userId.isNotEmpty) {
      await _firestore.deleteDocument('users', userId);
    }
  }
}
