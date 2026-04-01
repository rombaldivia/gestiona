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

  String? _uid;

  String _legacyIdKey(String uid) => 'activeCompanyId_$uid';
  String _legacyNameKey(String uid) => 'activeCompanyName_$uid';

  @override
  Future<CompanyState> build() async {
    final user = await ref.watch(authStateProvider.future);

    if (user == null) {
      _uid = null;
      return const CompanyState(companyId: null, companyName: null);
    }

    _uid = user.uid;

    final local = await _service.getActiveLocalCompany(uid: _uid!);
    if (local != null) {
      return CompanyState(companyId: local.$1, companyName: local.$2);
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyId = prefs.getString(_legacyIdKey(_uid!));
    final legacyName = prefs.getString(_legacyNameKey(_uid!));

    if (legacyId != null && legacyName != null) {
      await _local.setActiveCompany(uid: _uid!, id: legacyId, name: legacyName);
      return CompanyState(companyId: legacyId, companyName: legacyName);
    }

    return const CompanyState(companyId: null, companyName: null);
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
