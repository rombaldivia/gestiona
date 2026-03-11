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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _local = local ?? QuotesLocalStore(),
        _cloud = cloud ?? QuotesCloudService();

  final FirebaseAuth _auth;
  final QuotesLocalStore _local;
  final QuotesCloudService _cloud;

  String? get _uid => _auth.currentUser?.uid;

  Future<List<Quote>> listQuotes({required String companyId}) async {
    final uid = _uid;
    if (uid == null) return [];
    return _local.loadAll(uid: uid, companyId: companyId);
  }

  String? get currentUid => _uid;

  /// Guarda toda la lista local (usado en migración de sequences)
  Future<void> saveAllLocal({
    required String companyId,
    required String uid,
    required List<Quote> quotes,
  }) =>
      _local.saveAll(quotes, uid: uid, companyId: companyId);

  /// Sube sequences corregidos a Firestore para que no vuelvan a llegar con 0
  Future<void> pushSequencesToCloud({
    required String companyId,
    required String uid,
    required List<Quote> quotes,
  }) async {
    for (final q in quotes) {
      try {
        await _cloud.upsertQuote(companyId: companyId, uid: uid, quote: q);
      } catch (_) {
        // no interrumpir si hay error de red
      }
    }
  }

  Stream<List<Quote>> watchCloudQuotes({required String companyId}) {
    return _cloud.watchQuotes(companyId: companyId);
  }

  /// Aplica cloud -> local (gana updatedAtMs más reciente)
  Future<void> applyCloudToLocal({
    required String companyId,
    required List<Quote> cloudQuotes,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final local = await _local.loadAll(uid: uid, companyId: companyId);
    final map = {for (final q in local) q.id: q};

    for (final cq in cloudQuotes) {
      final lq = map[cq.id];
      if (lq == null || cq.updatedAtMs >= lq.updatedAtMs) {
        // Si Firestore devuelve sequence=0 pero localmente ya tiene
        // un correlativo correcto, lo preservamos. Esto ocurre cuando
        // la cotización fue creada antes de que existiera el campo.
        final seqToKeep = (cq.sequence == 0 && (lq?.sequence ?? 0) > 0)
            ? lq!.sequence
            : cq.sequence;
        map[cq.id] = seqToKeep != cq.sequence
            ? cq.copyWith(sequence: seqToKeep)
            : cq;
      }
    }

    // FIX: saveAll es una sola escritura atómica.
    // Antes: se borraba todo y luego se re-insertaba, si la app se
    // interrumpía entre medio se perdían todas las cotizaciones locales.
    await _local.saveAll(
      map.values.toList(),
      uid: uid,
      companyId: companyId,
    );
  }

  Future<void> upsertOfflineFirst({
    required String companyId,
    required Quote quote,
    required Entitlements ent,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('No hay usuario autenticado.');

    await _local.upsert(quote, uid: uid, companyId: companyId);

    if (!ent.cloudSync) return;

    await _cloud.upsertQuote(companyId: companyId, uid: uid, quote: quote);
  }

  Future<void> deleteOfflineFirst({
    required String companyId,
    required String quoteId,
    required Entitlements ent,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('No hay usuario autenticado.');

    await _local.deleteById(quoteId, uid: uid, companyId: companyId);

    if (!ent.cloudSync) return;

    await _cloud.deleteQuote(companyId: companyId, quoteId: quoteId);
  }

  /// Actualiza snapshots en cotizaciones draft cuando cambie el inventario.
  /// Regla: SOLO draft (no toca cotizaciones históricas).
  Future<int> refreshDraftQuotesFromInventory({
    required String companyId,
    required List<InventoryItem> inventory,
  }) async {
    final uid = _uid;
    if (uid == null) return 0;

    final invById = {for (final it in inventory) it.id: it};
    final quotes = await _local.loadAll(uid: uid, companyId: companyId);
    int changed = 0;

    for (final q in quotes) {
      if (q.status != QuoteStatus.draft) continue;

      bool dirty = false;

      final newLines = q.lines.map((l) {
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

        // FIX: ahora QuoteLine implementa == correctamente,
        // así que esta comparación detecta cambios reales (no siempre true).
        if (next != l) dirty = true;
        return next;
      }).toList(growable: false);

      if (dirty) {
        final updated = q.copyWith(
          lines: newLines,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        await _local.upsert(updated, uid: uid, companyId: companyId);
        changed++;
      }
    }

    return changed;
  }

  /// Reintenta subir al cloud cotizaciones creadas sin conexión.
  Future<int> syncPending({
    required String companyId,
    required Entitlements ent,
  }) async {
    if (!ent.cloudSync) return 0;
    final uid = _uid;
    if (uid == null) return 0;

    final local = await _local.loadAll(uid: uid, companyId: companyId);
    int synced = 0;

    for (final q in local) {
      try {
        await _cloud.upsertQuote(companyId: companyId, uid: uid, quote: q);
        synced++;
      } catch (_) {
        // no interrumpir el resto si uno falla
      }
    }

    return synced;
  }
}
