import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyService {
  CompanyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<String?> firstCompanyIdStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<String?>.empty();

    return _db
        .collection('company_members')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final data = snap.docs.first.data();
          final companyId = data['companyId'];
          return companyId is String ? companyId : null;
        });
  }

  Future<String> createCompanyAndMembership({
    required String companyName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario logueado.');
    }

    final companyRef = _db.collection('companies').doc();
    final companyId = companyRef.id;

    final memberId = '${user.uid}_$companyId';
    final memberRef = _db.collection('company_members').doc(memberId);

    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();
    batch.set(companyRef, {
      'name': companyName.trim(),
      'ownerUid': user.uid,
      'createdAt': now,
      'updatedAt': now,
    });

    batch.set(memberRef, {
      'uid': user.uid,
      'companyId': companyId,
      'role': 'owner',
      'createdAt': now,
    });

    await batch.commit();
    return companyId;
  }
}
