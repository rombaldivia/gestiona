import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../subscription/domain/entitlements.dart';
import 'company_local_store.dart';

class CompanyOfflineFirstService {
  CompanyOfflineFirstService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CompanyLocalStore? local,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _local = local ?? CompanyLocalStore();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final CompanyLocalStore _local;

  /// Lee empresa activa desde local (para que CompanyGate arranque bien)
  Future<(String, String)?> getActiveLocalCompany({required String uid}) {
    return _local.getActiveCompany(uid: uid);
  }

  /// 1) guarda local SIEMPRE (persistencia inmediata)
  /// 2) si ent.cloudSync (Plus/Pro) intenta mandar a Firestore
  Future<String> createCompanyOfflineFirst({
    required String companyName,
    required Entitlements ent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final uid = user.uid;

    final now = DateTime.now().millisecondsSinceEpoch;
    final companyId = 'c_$now';

    // ✅ 1) LOCAL primero
    await _local.setActiveCompany(uid: uid, id: companyId, name: companyName);
    await _local.addPendingCompany(
      uid: uid,
      id: companyId,
      name: companyName,
      createdAtMs: now,
    );

    // ✅ 2) NUBE después (solo Plus/Pro)
    if (ent.cloudSync) {
      try {
        await _syncCompanyToCloud(
          uid: uid,
          email: user.email,
          companyId: companyId,
          companyName: companyName,
        );
        await _local.removePendingCompany(uid, companyId); // <- 2 args
      } catch (_) {
        // queda pendiente en local
      }
    }

    return companyId;
  }

  /// Renombrar empresa activa (local primero; nube si Plus/Pro)
  Future<void> renameActiveCompany({
    required String newName,
    required Entitlements ent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final uid = user.uid;

    final active = await _local.getActiveCompany(uid: uid);
    if (active == null) throw StateError('No hay empresa activa en local.');

    final companyId = active.$1;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _local.setActiveCompany(uid: uid, id: companyId, name: newName);
    await _local.addPendingCompany(
      uid: uid,
      id: companyId,
      name: newName,
      createdAtMs: now,
    );

    if (ent.cloudSync) {
      try {
        await _syncCompanyToCloud(
          uid: uid,
          email: user.email,
          companyId: companyId,
          companyName: newName,
        );
        await _local.removePendingCompany(uid, companyId);
      } catch (_) {
        // queda pendiente para sync manual
      }
    }
  }

  /// Sync del active company guardado en local
  Future<bool> syncActiveCompany({required Entitlements ent}) async {
    if (!ent.cloudSync) return false;

    final user = _auth.currentUser;
    if (user == null) return false;
    final uid = user.uid;

    final active = await _local.getActiveCompany(uid: uid);
    if (active == null) return false;

    final companyId = active.$1;
    final companyName = active.$2;

    await _syncCompanyToCloud(
      uid: uid,
      email: user.email,
      companyId: companyId,
      companyName: companyName,
    );

    await _local.removePendingCompany(uid, companyId);
    return true;
  }

  Future<void> _syncCompanyToCloud({
    required String uid,
    required String? email,
    required String companyId,
    required String companyName,
  }) async {
    final nowServer = FieldValue.serverTimestamp();

    // companies/{companyId}
    await _db.collection('companies').doc(companyId).set({
      'name': companyName,
      'ownerUid': uid,
      'createdAt': nowServer,
      'updatedAt': nowServer,
    }, SetOptions(merge: true));

    // users/{uid}
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      if (email != null) 'email': email,
      'activeCompanyId': companyId,
      'activeCompanyName': companyName,
      'updatedAt': nowServer,
      'lastSyncAt': nowServer,
    }, SetOptions(merge: true));
  }
}
