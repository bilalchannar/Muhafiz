import 'dart:convert';
import 'package:muhafiz/models/trustee_model.dart';
import 'package:muhafiz/services/firestore_service.dart';
import 'package:muhafiz/services/local_storage_service.dart';

class TrusteeRepository {
  final LocalStorageService _storage;
  final FirestoreService _firestore;
  final String? userId;
  TrusteeRepository(this._storage, this._firestore, {this.userId});

  String get _trusteesKey => 'muhafiz_trustees_$userId';

  /// Legacy key from before user-scoped storage. Cleaned up on first load.
  static const _legacyTrusteesKey = 'muhafiz_trustees';

  Future<List<TrusteeModel>> loadTrustees() async {
    if (userId == null || userId!.isEmpty) return [];

    // Clean up old global key so stale data never leaks across users.
    try {
      final legacy = await _storage.getString(_legacyTrusteesKey);
      if (legacy != null) {
        await _storage.remove(_legacyTrusteesKey);
      }
    } catch (_) {}

    // 1. Load local cache as backup
    List<TrusteeModel> localList = [];
    try {
      final raw = await _storage.getString(_trusteesKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final trustees = decoded.map((e) => TrusteeModel.fromJson(e)).toList();
        localList = trustees.where((t) => t.userId == userId).toList();
      }
    } catch (_) {}

    // 2. Fetch remote trustees first from scoped user subcollection
    try {
      final remote = await _firestore.queryCollection(
        'users/$userId/trustees',
      );
      final list = remote.map(TrusteeModel.fromJson).toList();
      list.sort((a, b) {
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      // Update local storage cache for offline backup
      final encoded = list.map((t) => t.toJson()).toList();
      await _storage.saveString(_trusteesKey, jsonEncode(encoded));
      return list;
    } catch (e) {
      // 3. Fallback to local cache backup if Firestore is unavailable
      return localList;
    }
  }

  Future<void> saveTrustees(List<TrusteeModel> trustees) async {
    if (userId == null || userId!.isEmpty) return;
    final encoded = trustees.map((t) => t.toJson()).toList();
    await _storage.saveString(_trusteesKey, jsonEncode(encoded));
    for (final trustee in trustees) {
      await _firestore.upsertDocument('users/$userId/trustees', trustee.id, trustee.toJson());
    }
  }

  Future<void> deleteTrustee(String id) async {
    if (userId == null || userId!.isEmpty) return;
    await _firestore.deleteDocument('users/$userId/trustees', id);
  }

  Future<void> clearTrustees() async {
    await _storage.remove(_trusteesKey);
    // Also clean up legacy key if it still exists.
    await _storage.remove(_legacyTrusteesKey);
    if (userId == null) return;
    final remote = await _firestore.queryCollection(
      'users/$userId/trustees',
    );
    for (final trustee in remote) {
      final id = trustee['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _firestore.deleteDocument('users/$userId/trustees', id);
      }
    }
  }
}
