import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../subscription/domain/entitlements.dart';
import '../data/company_local_store.dart';
import '../data/company_offline_first_service.dart';
import 'company_state.dart';

class CompanyController extends AsyncNotifier<CompanyState> {
  final _service = CompanyOfflineFirstService();
  final _local = CompanyLocalStore();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String? _uid;

  String _legacyIdKey(String uid) => 'activeCompanyId_$uid';
  String _legacyNameKey(String uid) => 'activeCompanyName_$uid';

  @override
  Future<CompanyState> build() async {
    // Depende del usuario autenticado.
    // Cuando cambie el auth state, este provider se reconstruye.
    final user = await ref.watch(authStateProvider.future);

    if (user == null) {
      _uid = null;
      await _sub?.cancel();
      _sub = null;
      return const CompanyState(companyId: null, companyName: null);
    }

    _uid = user.uid;

    // 1) Carga local (storage nuevo)
    final local = await _service.getActiveLocalCompany(uid: _uid!);

    // 2) Si no hay en storage nuevo, migra desde legacy prefs
    if (local == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyId = prefs.getString(_legacyIdKey(_uid!));
      final legacyName = prefs.getString(_legacyNameKey(_uid!));

      if (legacyId != null && legacyName != null) {
        await _local.setActiveCompany(
          uid: _uid!,
          id: legacyId,
          name: legacyName,
        );
        _startCloudListener(_uid!);
        return CompanyState(companyId: legacyId, companyName: legacyName);
      }

      _startCloudListener(_uid!);
      return const CompanyState(companyId: null, companyName: null);
    }

    _startCloudListener(_uid!);
    return CompanyState(companyId: local.$1, companyName: local.$2);
  }

  void _startCloudListener(String uid) {
    // Evita duplicar listeners
    _sub?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
          _handleCloudSnap(uid, snap);
        });

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
  }

  Future<void> _handleCloudSnap(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    final data = snap.data();
    if (data == null) return;

    final cid = data['activeCompanyId'] as String?;
    final cname = data['activeCompanyName'] as String?;
    if (cid == null || cname == null) return;

    // Guarda a storage nuevo
    await _local.setActiveCompany(uid: uid, id: cid, name: cname);

    // Mantén legacy actualizado (compatibilidad)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyIdKey(uid), cid);
    await prefs.setString(_legacyNameKey(uid), cname);

    state = AsyncData(CompanyState(companyId: cid, companyName: cname));
  }

  void _ensureUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('No hay usuario autenticado (uid=null).');
    }
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> createCompany({
    required String name,
    required Entitlements ent,
  }) async {
    _ensureUid();
    final uid = _uid!;

    await _service.createCompanyOfflineFirst(companyName: name, ent: ent);

    final local = await _service.getActiveLocalCompany(uid: uid);
    if (local == null) return;

    // legacy compat
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyIdKey(uid), local.$1);
    await prefs.setString(_legacyNameKey(uid), local.$2);

    state = AsyncData(CompanyState(companyId: local.$1, companyName: local.$2));
  }

  Future<void> renameActiveCompany({
    required String newName,
    required Entitlements ent,
  }) async {
    _ensureUid();
    final uid = _uid!;

    await _service.renameActiveCompany(newName: newName, ent: ent);

    final local = await _service.getActiveLocalCompany(uid: uid);
    if (local == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_legacyIdKey(uid), local.$1);
    await prefs.setString(_legacyNameKey(uid), local.$2);

    state = AsyncData(CompanyState(companyId: local.$1, companyName: local.$2));
  }

  Future<void> syncNow({required Entitlements ent}) async {
    if (!ent.cloudSync) return;
    await _service.syncActiveCompany(ent: ent);
  }
}
