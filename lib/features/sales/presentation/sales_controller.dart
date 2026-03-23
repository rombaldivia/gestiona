import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../data/sales_local_store.dart';
import '../domain/sale.dart';
import '../domain/sale_status.dart';
import 'sales_state.dart';

final salesControllerProvider =
    AsyncNotifierProvider<SalesController, SalesState>(SalesController.new);

class SalesController extends AsyncNotifier<SalesState> {
  final _store = SalesLocalStore();

  String? _companyId;
  String? _uid;

  static const _empty = SalesState(sales: <Sale>[]);

  @override
  Future<SalesState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) {
      _uid = null;
      _companyId = null;
      return _empty;
    }

    final company = await ref.watch(companyControllerProvider.future);
    if (company.companyId == null) {
      _uid = user.uid;
      _companyId = null;
      return _empty;
    }

    _uid = user.uid;
    _companyId = company.companyId;

    final sales = await _store.loadAll(uid: _uid, companyId: _companyId);
    sales.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return SalesState(sales: sales);
  }

  void setQuery(String q) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(query: q));
  }

  void setFilter(SaleStatus? status) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(filterStatus: status, clearFilter: status == null));
  }

  Future<void> reload() async {
    if (_uid == null || _companyId == null) {
      state = const AsyncData(_empty);
      return;
    }
    final sales = await _store.loadAll(uid: _uid, companyId: _companyId);
    final cur = state.value ?? _empty;
    sales.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    state = AsyncData(cur.copyWith(sales: sales));
  }

  Future<Sale> newDraft() async {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    final us = now.microsecondsSinceEpoch;
    final y = now.year;

    final all = (_uid != null && _companyId != null)
        ? await _store.loadAll(uid: _uid, companyId: _companyId)
        : (state.value?.sales ?? const <Sale>[]);

    final maxSeq = all
        .where((s) => s.year == y)
        .fold<int>(0, (m, s) => s.sequence > m ? s.sequence : m);

    return Sale(
      id: 'VTA-$us',
      sequence: maxSeq + 1,
      year: y,
      createdAtMs: ms,
      updatedAtMs: ms,
      status: SaleStatus.completed,
      currency: 'BOB',
      lines: const [],
    );
  }

  Future<void> upsert(Sale sale) async {
    if (_uid == null || _companyId == null) {
      throw StateError('No hay usuario o empresa activa.');
    }

    await _store.upsert(sale, uid: _uid, companyId: _companyId);
    await reload();
  }

  Future<void> deleteById(String id) async {
    if (_uid == null || _companyId == null) {
      throw StateError('No hay usuario o empresa activa.');
    }

    await _store.deleteById(id, uid: _uid, companyId: _companyId);
    await reload();
  }
}
