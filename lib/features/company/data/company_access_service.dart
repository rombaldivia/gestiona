import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/company_member.dart';
import 'company_local_store.dart';

class JoinCodeData {
  const JoinCodeData({
    required this.code,
    required this.companyId,
    required this.companyName,
    required this.ownerUid,
    required this.role,
    required this.active,
    required this.expiresAt,
  });

  final String code;
  final String companyId;
  final String companyName;
  final String ownerUid;
  final String role;
  final bool active;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

class CompanyAccessService {
  CompanyAccessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CompanyLocalStore? localStore,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _local = localStore ?? CompanyLocalStore();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final CompanyLocalStore _local;

  Future<bool> isCurrentUserOwner(String companyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final snap = await _db.collection('companies').doc(companyId).get();
    final data = snap.data();
    if (data == null) return false;
    return data['ownerUid'] == uid;
  }

  Stream<List<CompanyMember>> watchMembers({required String companyId}) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .snapshots()
        .map((snap) {
          final items = snap.docs
              .map((d) => CompanyMember.fromJson(d.data()))
              .toList();
          items.sort((a, b) => b.joinedAtMs.compareTo(a.joinedAtMs));
          return items;
        });
  }

  Future<JoinCodeData?> getActiveJoinCode({required String companyId}) async {
    final accessSnap = await _db
        .collection('companies')
        .doc(companyId)
        .collection('private')
        .doc('access')
        .get();

    final access = accessSnap.data();
    final code = (access?['activeJoinCode'] as String? ?? '').trim();
    if (code.isEmpty) return null;

    final codeSnap = await _db.collection('company_join_codes').doc(code).get();
    if (!codeSnap.exists) return null;

    return _joinCodeFromDoc(codeSnap);
  }

  Future<JoinCodeData> createJoinCode({
    required String companyId,
    required String companyName,
    required String role,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }
    if (!companyJoinRoles.contains(role)) {
      throw ArgumentError('Rol inválido: $role');
    }

    final expiresAt = DateTime.now().add(ttl);
    final newCode = _generateJoinCode();

    final accessRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('private')
        .doc('access');

    final oldAccess = await accessRef.get();
    final oldCode = (oldAccess.data()?['activeJoinCode'] as String? ?? '')
        .trim();

    final batch = _db.batch();

    if (oldCode.isNotEmpty) {
      batch.set(_db.collection('company_join_codes').doc(oldCode), {
        'active': false,
        'revokedAt': FieldValue.serverTimestamp(),
        'revokedByUid': user.uid,
      }, SetOptions(merge: true));
    }

    batch.set(_db.collection('company_join_codes').doc(newCode), {
      'companyId': companyId,
      'companyName': companyName,
      'createdByUid': user.uid,
      'ownerUid': user.uid,
      'role': role,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    batch.set(accessRef, {
      'activeJoinCode': newCode,
      'activeJoinRole': role,
      'activeJoinExpiresAt': Timestamp.fromDate(expiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    return JoinCodeData(
      code: newCode,
      companyId: companyId,
      companyName: companyName,
      ownerUid: user.uid,
      role: role,
      active: true,
      expiresAt: expiresAt,
    );
  }

  Future<JoinCodeData> joinWithCode(String rawCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesión antes de unirte.');
    }

    final code = normalizeJoinCode(rawCode);
    if (code.isEmpty) {
      throw ArgumentError('Código vacío.');
    }

    final joinSnap = await _readJoinCode(code);
    if (!joinSnap.exists) {
      throw StateError('El código no existe o ya fue revocado.');
    }

    final joinData = _joinCodeFromDoc(joinSnap);
    if (!joinData.active || joinData.isExpired) {
      throw StateError('El código ya expiró o fue desactivado.');
    }

    final uid = user.uid;
    final ownerUid = joinData.ownerUid.trim();
    final resolvedCompanyName = joinData.companyName.trim();
    final isOwner = ownerUid.isNotEmpty && ownerUid == uid;

    final memberRef = _db
        .collection('companies')
        .doc(joinData.companyId)
        .collection('members')
        .doc(uid);

    final companyMemberRef = _db
        .collection('company_members')
        .doc('${uid}_${joinData.companyId}');

    final userRef = _db.collection('users').doc(uid);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final name = _bestUserName(user);
    final email = (user.email ?? '').trim();

    if (!isOwner) {
      await _safeSet(
        memberRef,
        {
          'uid': uid,
          'name': name,
          'email': email,
          'role': joinData.role,
          'joinedAtMs': nowMs,
          'joinCode': joinData.code,
        },
        'escribiendo companies/${joinData.companyId}/members/$uid',
        merge: true,
      );

      await _safeSet(
        companyMemberRef,
        {
          'uid': uid,
          'companyId': joinData.companyId,
          'companyName': resolvedCompanyName,
          'ownerUid': ownerUid,
          'email': email,
          'name': name,
          'role': joinData.role,
          'joinedAtMs': nowMs,
          'joinCode': joinData.code,
        },
        'escribiendo company_members/${uid}_${joinData.companyId}',
        merge: true,
      );
    }

    await _safeSet(
      userRef,
      {
        'uid': uid,
        if (email.isNotEmpty) 'email': email,
        'activeCompanyId': joinData.companyId,
        'activeCompanyName': resolvedCompanyName,
        'activeCompanyOwnerUid': ownerUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastJoinAt': FieldValue.serverTimestamp(),
      },
      'escribiendo users/$uid',
      merge: true,
    );

    await _local.setActiveCompany(
      uid: uid,
      id: joinData.companyId,
      name: resolvedCompanyName,
    );

    return JoinCodeData(
      code: joinData.code,
      companyId: joinData.companyId,
      companyName: resolvedCompanyName,
      ownerUid: ownerUid,
      role: joinData.role,
      active: joinData.active,
      expiresAt: joinData.expiresAt,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readJoinCode(
    String code,
  ) async {
    return _safeGet(
      _db.collection('company_join_codes').doc(code),
      'leyendo company_join_codes/$code',
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _safeGet(
    DocumentReference<Map<String, dynamic>> ref,
    String step,
  ) async {
    try {
      return await ref.get();
    } on FirebaseException catch (e) {
      throw StateError('$step falló: code=${e.code} message=${e.message}');
    }
  }

  Future<void> _safeSet(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
    String step, {
    bool merge = false,
  }) async {
    try {
      await ref.set(data, merge ? SetOptions(merge: true) : null);
    } on FirebaseException catch (e) {
      throw StateError('$step falló: code=${e.code} message=${e.message}');
    }
  }

  static String normalizeJoinCode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'] as String?;
        if (code != null && code.trim().isNotEmpty) {
          return code.trim().toUpperCase();
        }
      }
    } catch (_) {}

    final uri = Uri.tryParse(text);
    final qpCode = uri?.queryParameters['code'];
    if (qpCode != null && qpCode.trim().isNotEmpty) {
      return qpCode.trim().toUpperCase();
    }

    return text.toUpperCase();
  }

  JoinCodeData _joinCodeFromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    final expiresTs = data['expiresAt'] as Timestamp?;
    final ownerUid =
        (data['ownerUid'] as String? ?? data['createdByUid'] as String? ?? '')
            .trim();

    return JoinCodeData(
      code: snap.id,
      companyId: (data['companyId'] as String? ?? '').trim(),
      companyName: (data['companyName'] as String? ?? '').trim(),
      ownerUid: ownerUid,
      role: (data['role'] as String? ?? 'operario').trim(),
      active: data['active'] == true,
      expiresAt: expiresTs?.toDate(),
    );
  }

  String _generateJoinCode({int length = 12}) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[rnd.nextInt(alphabet.length)],
    ).join();
  }

  String _bestUserName(User user) {
    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Usuario';
  }
}
