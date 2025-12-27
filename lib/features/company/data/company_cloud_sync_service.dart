import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyCloudSyncService {
  final FirebaseFirestore _db;

  CompanyCloudSyncService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Sincroniza la empresa activa:
  /// - crea/merge companies/{companyId}
  /// - actualiza users/{uid}.activeCompanyId/Name + lastSyncAt
  ///
  /// Si companyId == null o "local-default", genera un ID nuevo en Firestore.
  Future<String> syncActiveCompany({
    required User user,
    required String companyName,
    String? companyId,
  }) async {
    final uid = user.uid;

    final usersRef = _db.collection('users').doc(uid);

    final cid = (companyId != null && companyId.isNotEmpty && companyId != 'local-default')
        ? companyId
        : _db.collection('companies').doc().id;

    final companyRef = _db.collection('companies').doc(cid);

    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      tx.set(
        companyRef,
        {
          'id': cid,
          'name': companyName,
          'ownerUid': uid,
          'updatedAt': now,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        usersRef,
        {
          'uid': uid,
          'email': user.email,
          'activeCompanyId': cid,
          'activeCompanyName': companyName,
          'lastSyncAt': now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });

    return cid;
  }
}
