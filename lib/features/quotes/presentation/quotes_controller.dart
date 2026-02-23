import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../../company/data/company_cloud_service.dart';
import '../data/quotes_offline_first_service.dart';
import '../domain/quote.dart';
import '../domain/quote_status.dart';
import 'quotes_state.dart';

final quotesControllerProvider =
    AsyncNotifierProvider<QuotesController, QuotesState>(QuotesController.new);

class QuotesController extends AsyncNotifier<QuotesState> {
  final _service = QuotesOfflineFirstService();
  final _companyCloud = CompanyCloudService();

  String? _companyId;
  StreamSubscription<List<Quote>>? _cloudSub;
  bool _ensuredCompanyOnCloud = false;

  static const _empty = QuotesState(quotes: <Quote>[]);

  @override
  Future<QuotesState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) {
      _companyId = null;
      _cloudSub?.cancel();
      _ensuredCompanyOnCloud = false;
      return _empty;
    }

    final company = await ref.watch(companyControllerProvider.future);
    final cid = company.companyId;
    if (cid == null) {
      _companyId = null;
      _cloudSub?.cancel();
      _ensuredCompanyOnCloud = false;
      return _empty;
    }

    _companyId = cid;

    final ent = await ref.watch(entitlementsProvider(user.uid).future);

    if (ent.cloudSync) {
      await _ensureCompanyDocIfNeeded(ent);

      _cloudSub?.cancel();
      _cloudSub = _service.watchCloudQuotes(companyId: cid).listen((
        cloudQuotes,
      ) async {
        await _service.applyCloudToLocal(cloudQuotes: cloudQuotes);

        final local = await _service.listQuotes();
        final cur = state.asData?.value ?? _empty;
        state = AsyncData(cur.copyWith(quotes: local));
      });

      ref.onDispose(() => _cloudSub?.cancel());
    } else {
      _cloudSub?.cancel();
    }

    final quotes = await _service.listQuotes();
    return QuotesState(quotes: quotes);
  }

  void _ensureCompany() {
    if (_companyId == null) {
      throw StateError('No hay empresa activa seleccionada.');
    }
  }

  Future<Entitlements> _getFreshEntitlements() async {
    final user = await ref.read(authStateProvider.future);
    if (user == null) throw StateError('No hay usuario autenticado.');
    return ref.read(entitlementsProvider(user.uid).future);
  }

  Future<void> _ensureCompanyDocIfNeeded(Entitlements ent) async {
    if (!ent.cloudSync) return;
    _ensureCompany();

    if (_ensuredCompanyOnCloud) return;

    try {
      final company = await ref.read(companyControllerProvider.future);
      await _companyCloud.ensureCompanyDocExists(
        companyId: _companyId!,
        companyName: company.companyName,
      );
      _ensuredCompanyOnCloud = true;
    } catch (_) {
      // no revientes si offline
    }
  }

  void setQuery(String q) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(query: q));
  }

  void setFilter(QuoteStatus? f) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(filterStatus: f, clearFilter: f == null));
  }

  Quote newDraft() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final y = DateTime.now().year;

    final quotes = state.value?.quotes ?? const <Quote>[];
    final maxSeq = quotes
        .where((q) => q.year == y)
        .fold<int>(0, (m, q) => q.sequence > m ? q.sequence : m);

    return Quote(
      id: 'COT-$now',
      sequence: maxSeq + 1,
      year: y,
      createdAtMs: now,
      updatedAtMs: now,
      status: QuoteStatus.draft,
      currency: 'BOB',
      lines: const [],
    );
  }

  Quote duplicate(Quote src, {required String mode}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final y = DateTime.now().year;

    final quotes = state.value?.quotes ?? const <Quote>[];
    final maxSeq = quotes
        .where((q) => q.year == y)
        .fold<int>(0, (m, q) => q.sequence > m ? q.sequence : m);

    return Quote(
      id: 'COT-$now',
      sequence: maxSeq + 1,
      year: y,
      createdAtMs: now,
      updatedAtMs: now,
      status: QuoteStatus.draft,
      customerName: src.customerName,
      customerPhone: src.customerPhone,
      notes: src.notes,
      currency: src.currency,
      lines: src.lines,
      sourceQuoteId: src.id,
      sourceMode: mode,
    );
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> upsert(Quote q) async {
    _ensureCompany();
    final ent = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(ent);

    await _service.upsertOfflineFirst(
      companyId: _companyId!,
      quote: q,
      ent: ent,
    );
    await reload();
  }

  Future<void> delete(String id) async {
    _ensureCompany();
    final ent = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(ent);

    await _service.deleteOfflineFirst(
      companyId: _companyId!,
      quoteId: id,
      ent: ent,
    );
    await reload();
  }
}
