import '../../domain/process_template.dart';
import '../../../../inventory/domain/inventory_item.dart';
import '../../../domain/quote_line.dart';

/// Convierte un ProcessTemplate (requirements) en líneas de cotización.
///
/// Qué se “importa” como snapshot (según QuoteLine):
/// - nameSnapshot, skuSnapshot, unitSnapshot
/// - qty
/// - unitPriceBobSnapshot (desde InventoryItem.salePrice)
/// - costBobSnapshot (desde InventoryItem.cost)
/// - usdRateSnapshot / source / updatedAt (desde InventoryItem.*)
/// - note (se combina con info del proceso + nota del requerimiento)
///
/// Si un item ya no existe en inventario, se crea como "manual" con precio 0.
List<QuoteLine> processTemplateToQuoteLines({
  required ProcessTemplate template,
  required Map<String, InventoryItem> inventoryById,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final out = <QuoteLine>[];

  String joinNotes(String a, String? b) {
    final aa = a.trim();
    final bb = (b ?? '').trim();
    if (bb.isEmpty) return aa;
    return '$aa\n$bb';
  }

  for (final r in template.requirements) {
    final inv = inventoryById[r.inventoryItemId];

    final kind = (inv != null) ? 'inventory' : 'manual';

    // snapshots desde inventario (si existe) o desde requirement (fallback)
    final name = inv?.name ?? r.nameSnapshot;
    final sku = inv?.sku; // si no hay inv, no hay sku confiable
    final unit = (inv?.unit ?? r.unitSnapshot).trim();

    // precio/costo/tasa USD
    final unitPrice = inv?.salePrice ?? 0.0;
    final costBob = inv?.cost;

    final usdRate = inv?.usdRate;
    final usdSource = inv?.usdRateSource;
    final usdUpdatedAt = inv?.usdRateUpdatedAtMs;

    // metemos contexto del proceso en note para rastrear de dónde vino
    final baseNote = 'Proceso: ${template.name}';
    final note = joinNotes(baseNote, r.note);

    out.add(
      QuoteLine(
        lineId: 'PROC-$now-${r.reqId}-${out.length}',
        kind: kind,
        inventoryItemId: inv?.id ?? r.inventoryItemId,
        nameSnapshot: name,
        skuSnapshot: sku,
        unitSnapshot: unit.isEmpty ? null : unit,
        qty: r.qty,
        unitPriceBobSnapshot: unitPrice,
        costBobSnapshot: costBob,
        usdRateSnapshot: usdRate,
        usdRateSourceSnapshot: usdSource,
        usdRateUpdatedAtMsSnapshot: usdUpdatedAt,
        note: note,
      ),
    );
  }

  return out;
}
