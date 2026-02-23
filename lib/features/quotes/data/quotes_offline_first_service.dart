import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../inventory/domain/inventory_item.dart';
import '../../subscription/domain/entitlements.dart';
import '../domain/quote.dart';
import '../domain/quote_status.dart';
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

  /// Aplica cloud -> local (simple: gana updatedAtMs más reciente)
  Future<void> applyCloudToLocal({required List<Quote> cloudQuotes}) async {
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

  /// ✅ PRO: Actualiza snapshots en cotizaciones draft cuando cambie inventario.
  /// Regla: SOLO draft (no toca cotizaciones históricas).
  /// Actualiza: nombre/sku/unidad/costo/venta(Bs)
  Future<int> refreshDraftQuotesFromInventory({
    required List<InventoryItem> inventory,
  }) async {
    final invById = {for (final it in inventory) it.id: it};

    final quotes = await _local.loadAll();
    int changed = 0;

    for (final q in quotes) {
      if (q.status != QuoteStatus.draft) continue;

      bool dirty = false;

      final newLines = q.lines
          .map((l) {
            final itemId = l.inventoryItemId;
            if (itemId == null) return l;

            final it = invById[itemId];
            if (it == null) return l;

            final next = l.copyWith(
              nameSnapshot: it.name,
              skuSnapshot: it.sku,
              unitSnapshot: it.unit,
              costBobSnapshot: it.cost,
              unitPriceBobSnapshot: it.salePrice,
            );

            if (next != l) dirty = true;
            return next;
          })
          .toList(growable: false);

      if (dirty) {
        final updated = q.copyWith(
          lines: newLines,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        await _local.upsert(updated);
        changed++;
      }
    }

    return changed;
  }

  // helper: reemplaza todo (simple y seguro)
  Future<void> _localReplaceAll(List<Quote> quotes) async {
    final existing = await _local.loadAll();
    for (final q in existing) {
      await _local.deleteById(q.id);
    }
    for (final q in quotes) {
      await _local.upsert(q);
    }
  }
}
