import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../domain/quote.dart';
import '../presentation/quotes_controller.dart';
import 'quote_editor_page.dart';
import 'widgets/quote_banner_requote.dart';
import 'widgets/quote_line_tile.dart';

class QuoteDetailsPage extends ConsumerWidget {
  const QuoteDetailsPage({super.key, required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = EntitlementsScope.of(context);
    final isPro = ent.tier == PlanTier.pro;

    final invState = ref.watch(inventoryControllerProvider);
    final inv = invState.asData?.value.items ?? const <InventoryItem>[];
    final invById = <String, InventoryItem>{for (final i in inv) i.id: i};

    final diff = _diffQuote(quote, invById);

    Future<void> doDuplicate({required bool requote}) async {
      final ctrl = ref.read(quotesControllerProvider.notifier);
      final duplicated = ctrl.duplicate(
        quote,
        mode: requote ? 'requote' : 'duplicate',
      );

      Quote out = duplicated;

      if (requote) {
        if (!isPro) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Re-cotizar es PRO.')));
          return;
        }
        out = _requoteFromInventory(duplicated, invById);
      }

      final nav = Navigator.of(context);
      final saved = await nav.push<Quote>(
        MaterialPageRoute(builder: (_) => QuoteEditorPage(quote: out)),
      );
      if (saved != null) {
        nav.pop(saved);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(quote.id),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dup') doDuplicate(requote: false);
              if (v == 'requote') doDuplicate(requote: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
              PopupMenuItem(
                value: 'requote',
                enabled: isPro,
                child: Text(isPro ? 'Re-cotizar (PRO)' : 'Re-cotizar (PRO)'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (diff.hasChanges)
            QuoteBannerRequote(
              diffText: diff.text,
              isPro: isPro,
              onRequote: () => doDuplicate(requote: true),
            ),

          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (quote.customerName ?? 'Sin cliente').trim(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total: Bs ${quote.totalBob.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if ((quote.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Notas: ${quote.notes}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Ítems',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),

          if (quote.lines.isEmpty)
            const Text('Sin ítems.')
          else
            ...quote.lines.map(
              (l) => QuoteLineTile(line: l, onEditQty: null, onRemove: null),
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => doDuplicate(requote: false),
                  icon: const Icon(Icons.copy),
                  label: const Text('Duplicar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isPro
                      ? () => doDuplicate(requote: true)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Re-cotizar es PRO.')),
                        ),
                  icon: const Icon(Icons.refresh),
                  label: Text(isPro ? 'Re-cotizar' : 'Re-cotizar (PRO)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteDiff {
  _QuoteDiff(this.hasChanges, this.text);
  final bool hasChanges;
  final String text;
}

_QuoteDiff _diffQuote(Quote q, Map<String, InventoryItem> invById) {
  int changed = 0;
  int missing = 0;

  for (final l in q.lines) {
    final id = l.inventoryItemId;
    if (id == null) continue;

    final it = invById[id];
    if (it == null) {
      missing++;
      continue;
    }

    final currentPrice = (it.salePrice ?? 0.0);
    final currentRate = it.usdRate; // si tu InventoryItem lo tiene

    final priceDiff = (currentPrice - l.unitPriceBobSnapshot).abs() > 0.009;
    final rateDiff =
        (((currentRate ?? 0.0) - (l.usdRateSnapshot ?? 0.0)).abs() > 0.009);

    if (priceDiff || rateDiff) changed++;
  }

  final has = (changed + missing) > 0;
  final parts = <String>[];
  if (changed > 0) parts.add('$changed ítems cambiaron (precio/dólar)');
  if (missing > 0) parts.add('$missing ítems ya no existen');
  return _QuoteDiff(has, parts.isEmpty ? '' : parts.join(' • '));
}

Quote _requoteFromInventory(Quote base, Map<String, InventoryItem> invById) {
  final now = DateTime.now().millisecondsSinceEpoch;

  final newLines = base.lines.map((l) {
    final id = l.inventoryItemId;
    if (id == null) return l;

    final it = invById[id];
    if (it == null) return l;

    return l.copyWith(
      unitPriceBobSnapshot: it.salePrice ?? l.unitPriceBobSnapshot,
      usdRateSnapshot: it.usdRate ?? l.usdRateSnapshot,
      usdRateSourceSnapshot: it.usdRateSource,
      usdRateUpdatedAtMsSnapshot: it.usdRateUpdatedAtMs,
    );
  }).toList();

  return base.copyWith(updatedAtMs: now, lines: newLines);
}
