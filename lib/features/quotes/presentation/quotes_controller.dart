import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/data/company_cloud_service.dart';
import '../../company/presentation/company_providers.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/entitlements_providers.dart';
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
        await _service.applyCloudToLocal(
          companyId: cid,
          cloudQuotes: cloudQuotes,
        );
        final local = await _service.listQuotes(companyId: cid);
        final cur = state.asData?.value ?? _empty;
        state = AsyncData(cur.copyWith(quotes: local));
      });

      ref.onDispose(() => _cloudSub?.cancel());
    } else {
      _cloudSub?.cancel();
    }

    final raw    = await _service.listQuotes(companyId: cid);
    final quotes = await _fixBrokenSequences(raw, companyId: cid);
    return QuotesState(quotes: quotes);
  }

  /// Repara cotizaciones con sequence=0 asignándoles un correlativo
  /// cronológico. Solo se ejecuta si hay datos rotos — luego no hace nada.
  Future<List<Quote>> _fixBrokenSequences(
    List<Quote> quotes, {
    required String companyId,
  }) async {
    if (!quotes.any((q) => q.sequence == 0)) return quotes;

    final uid = _service.currentUid;
    if (uid == null) return quotes;

    // Ordena por fecha de creación para asignar 1,2,3 en orden cronológico
    final sorted = [...quotes]
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

    final Map<int, int> counter = {};
    final fixed = sorted.map((q) {
      if (q.sequence != 0) {
        final cur = counter[q.year] ?? 0;
        if (q.sequence > cur) counter[q.year] = q.sequence;
        return q;
      }
      final next = (counter[q.year] ?? 0) + 1;
      counter[q.year] = next;
      return q.copyWith(sequence: next);
    }).toList();

    // Persiste localmente
    await _service.saveAllLocal(
      companyId: companyId,
      uid: uid,
      quotes: fixed,
    );

    // También sube a Firestore para que no vuelva a pasar
    await _service.pushSequencesToCloud(
      companyId: companyId,
      uid: uid,
      quotes: fixed,
    );

    return fixed;
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
    } catch (_) {}
  }

  void setQuery(String q) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(query: q));
  }

  void setFilter(QuoteStatus? f) {
    final cur = state.value ?? _empty;
    state = AsyncData(cur.copyWith(filterStatus: f, clearFilter: f == null));
  }

  // FIX: async — lee del store para evitar sequence=1 cuando el
  // provider aún está cargando o el estado tiene datos incompletos.
  Future<Quote> newDraft() async {
    final now = DateTime.now();
    final ms  = now.millisecondsSinceEpoch;
    final us  = now.microsecondsSinceEpoch;
    final y   = now.year;

    final all = _companyId != null
        ? await _service.listQuotes(companyId: _companyId!)
        : (state.value?.quotes ?? const <Quote>[]);

    final maxSeq = all
        .where((q) => q.year == y)
        .fold<int>(0, (m, q) => q.sequence > m ? q.sequence : m);

    return Quote(
      id:          'COT-$us',
      sequence:    maxSeq + 1,
      year:        y,
      createdAtMs: ms,
      updatedAtMs: ms,
      status:      QuoteStatus.draft,
      currency:    'BOB',
      lines:       const [],
    );
  }

  Future<Quote> duplicate(Quote src, {required String mode}) async {
    final now = DateTime.now();
    final ms  = now.millisecondsSinceEpoch;
    final us  = now.microsecondsSinceEpoch;
    final y   = now.year;

    final all = _companyId != null
        ? await _service.listQuotes(companyId: _companyId!)
        : (state.value?.quotes ?? const <Quote>[]);

    final maxSeq = all
        .where((q) => q.year == y)
        .fold<int>(0, (m, q) => q.sequence > m ? q.sequence : m);

    return Quote(
      id:           'COT-$us',
      sequence:     maxSeq + 1,
      year:         y,
      createdAtMs:  ms,
      updatedAtMs:  ms,
      status:       QuoteStatus.draft,
      customerName: src.customerName,
      customerPhone: src.customerPhone,
      notes:        src.notes,
      currency:     src.currency,
      lines:        src.lines,
      sourceQuoteId: src.id,
      sourceMode:   mode,
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

  Future<int> syncPending() async {
    _ensureCompany();
    final ent = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(ent);
    final n = await _service.syncPending(companyId: _companyId!, ent: ent);
    await reload();
    return n;
  }
}
