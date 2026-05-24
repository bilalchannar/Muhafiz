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

    try {
      final raw = await _storage.getString(_trusteesKey);
      if (raw == null || raw.isEmpty) throw Exception('No local trustees');
      final List<dynamic> decoded = jsonDecode(raw);
      final trustees = decoded.map((e) => TrusteeModel.fromJson(e)).toList();
      // Extra safety: only return trustees belonging to this user.
      return trustees.where((t) => t.userId == userId).toList();
    } catch (_) {
      try {
        final remote = await _firestore.queryCollection(
          'trustees',
          ownerId: userId,
          ownerField: 'userId',
        );
        final list = remote.map(TrusteeModel.fromJson).toList();
        list.sort((a, b) {
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        if (list.isNotEmpty) {
          final encoded = list.map((t) => t.toJson()).toList();
          await _storage.saveString(_trusteesKey, jsonEncode(encoded));
        }
        return list;
      } catch (e) {
        // print('Error loading remote trustees: $e');
        return [];
      }
    }
  }

  Future<void> saveTrustees(List<TrusteeModel> trustees) async {
    if (userId == null || userId!.isEmpty) return;
    final encoded = trustees.map((t) => t.toJson()).toList();
    await _storage.saveString(_trusteesKey, jsonEncode(encoded));
    for (final trustee in trustees) {
      await _firestore.upsertDocument('trustees', trustee.id, trustee.toJson());
    }
  }

  Future<void> deleteTrustee(String id) async {
    if (userId == null || userId!.isEmpty) return;
    await _firestore.deleteDocument('trustees', id);
  }

  Future<void> clearTrustees() async {
    await _storage.remove(_trusteesKey);
    // Also clean up legacy key if it still exists.
    await _storage.remove(_legacyTrusteesKey);
    if (userId == null) return;
    final remote = await _firestore.queryCollection(
      'trustees',
      ownerId: userId,
      ownerField: 'userId',
    );
    for (final trustee in remote) {
      final id = trustee['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _firestore.deleteDocument('trustees', id);
      }
    }
  }
}
