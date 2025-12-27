import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyCloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> upsertCompany({
    required String uid,
    required String companyId,
    required String name,
  }) async {
    final ref = _db.collection('companies').doc(companyId);
    await ref.set({
      'name': name,
      'ownerId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setUserActiveCompany({
    required String uid,
    required String companyId,
    required String companyName,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      'uid': uid,
      'activeCompanyId': companyId,
      'activeCompanyName': companyName,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSyncAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sync “rápido”: asegura empresa + escribe activeCompany en users/{uid}
  Future<void> syncNow({
    required String uid,
    required String companyId,
    required String companyName,
  }) async {
    await upsertCompany(uid: uid, companyId: companyId, name: companyName);
    await setUserActiveCompany(
      uid: uid,
      companyId: companyId,
      companyName: companyName,
    );
  }
}
