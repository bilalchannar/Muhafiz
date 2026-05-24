import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:muhafiz/services/firebase_bootstrap.dart';

class FirestoreService {
  Future<FirebaseFirestore?> _db() async {
    final ready = await FirebaseBootstrap.ensureInitialized();
    if (!ready) return null;
    return FirebaseFirestore.instance;
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String id,
  ) async {
    final db = await _db();
    if (db == null) return null;

    final snapshot = await db.collection(collection).doc(id).get();
    return snapshot.data();
  }

  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    String? ownerId,
    String ownerField = 'userId',
    int? limit,
    String? orderByField,
    bool descending = true,
  }) async {
    final db = await _db();
    if (db == null) return [];

    Query<Map<String, dynamic>> query = db.collection(collection);
    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where(ownerField, isEqualTo: ownerId);
    }
    if (orderByField != null && orderByField.isNotEmpty) {
      query = query.orderBy(orderByField, descending: descending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> upsertDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = await _db();
    if (db == null) return;

    await db.collection(collection).doc(id).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<void> deleteDocument(String collection, String id) async {
    final db = await _db();
    if (db == null) return;

    await db.collection(collection).doc(id).delete();
  }

  Future<int> countCollection(
    String collection, {
    String? ownerId,
    String ownerField = 'userId',
  }) async {
    final docs = await queryCollection(
      collection,
      ownerId: ownerId,
      ownerField: ownerField,
    );
    return docs.length;
  }

  Future<void> addSubCollectionItem({
    required String collection,
    required String parentId,
    required String subCollection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final db = await _db();
    if (db == null) return;

    await db
        .collection(collection)
        .doc(parentId)
        .collection(subCollection)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
  }
}
