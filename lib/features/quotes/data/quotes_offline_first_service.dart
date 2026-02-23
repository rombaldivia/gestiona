import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../subscription/domain/entitlements.dart';
import '../domain/quote.dart';
import 'quotes_cloud_service.dart';
import 'quotes_local_store.dart';

class QuotesOfflineFirstService {
  QuotesOfflineFirstService({
    FirebaseAuth? auth,
    QuotesLocalStore? local,
    QuotesCloudService? cloud,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _local = local ?? QuotesLocalStore(),
       _cloud = cloud ?? QuotesCloudService();

  final FirebaseAuth _auth;
  final QuotesLocalStore _local;
  final QuotesCloudService _cloud;

  Future<List<Quote>> listQuotes() async {
    final u = _auth.currentUser;
    if (u == null) return [];
    return _local.loadAll();
  }

  Stream<List<Quote>> watchCloudQuotes({required String companyId}) {
    return _cloud.watchQuotes(companyId: companyId);
  }

  /// Aplica cloud -> local (simple, sin dirty por ahora)
  Future<void> applyCloudToLocal({
    required List<Quote> cloudQuotes,
  }) async {
    // Merge simple: cloud gana por updatedAtMs
    final local = await _local.loadAll();
    final map = {for (final q in local) q.id: q};

    for (final cq in cloudQuotes) {
      final lq = map[cq.id];
      if (lq == null || cq.updatedAtMs >= lq.updatedAtMs) {
        map[cq.id] = cq;
      }
    }

    await _localReplaceAll(map.values.toList());
  }

  Future<void> upsertOfflineFirst({
    required String companyId,
    required Quote quote,
    required Entitlements ent,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No hay usuario autenticado.');
    final uid = u.uid;

    await _local.upsert(quote);

    if (!ent.cloudSync) return;

    await _cloud.upsertQuote(companyId: companyId, uid: uid, quote: quote);
  }

  Future<void> deleteOfflineFirst({
    required String companyId,
    required String quoteId,
    required Entitlements ent,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No hay usuario autenticado.');

    await _local.deleteById(quoteId);

    if (!ent.cloudSync) return;

    await _cloud.deleteQuote(companyId: companyId, quoteId: quoteId);
  }

  // helper: reemplaza todo (QuotesLocalStore no tiene esto)
  Future<void> _localReplaceAll(List<Quote> quotes) async {
    // Reusa la clave interna del store guardando JSON completo
    // sin exponer métodos nuevos
    // → hacemos "upsert" uno a uno después de limpiar
    // (simple y seguro)
    final existing = await _local.loadAll();
    for (final q in existing) {
      await _local.deleteById(q.id);
    }
    for (final q in quotes) {
      await _local.upsert(q);
    }
  }
}
