import 'package:flutter/material.dart';

import '../../../inventory/domain/inventory_item.dart';
import '../../domain/quote_line.dart';

class QuoteAddItemSheet extends StatefulWidget {
  const QuoteAddItemSheet({super.key, required this.inventoryItems});
  final List<InventoryItem> inventoryItems;

  @override
  State<QuoteAddItemSheet> createState() => _QuoteAddItemSheetState();
}

class _QuoteAddItemSheetState extends State<QuoteAddItemSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.inventoryItems.where((it) {
      if (q.trim().isEmpty) return true;
      final t = q.trim().toLowerCase();
      return it.name.toLowerCase().contains(t) ||
          (it.sku ?? '').toLowerCase().contains(t);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Material(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Agregar ítem',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar en inventario…',
                  ),
                  onChanged: (v) => setState(() => q = v),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final price = it.salePrice ?? 0.0;
                      final hasUsd = (it.usdRate ?? 0) > 0;

                      return Card(
                        elevation: 0,
                        child: ListTile(
                          title: Text(
                            it.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Bs ${price.toStringAsFixed(2)}${it.sku == null ? '' : ' • SKU ${it.sku}'}',
                          ),
                          trailing: hasUsd ? const Text('USD🔒') : null,
                          onTap: () async {
                            final nav = Navigator.of(context);
                            final qty = await _askQty(context);
                            if (qty == null) return;

                            final now = DateTime.now().millisecondsSinceEpoch;

                            final line = QuoteLine(
                              lineId: 'L-$now',
                              kind: 'inventory',
                              inventoryItemId: it.id,
                              nameSnapshot: it.name,
                              skuSnapshot: it.sku,
                              unitSnapshot: it.unit,
                              qty: qty,
                              unitPriceBobSnapshot: (it.salePrice ?? 0.0),
                              costBobSnapshot: it.cost,
                              usdRateSnapshot: it.usdRate,
                              usdRateSourceSnapshot: it.usdRateSource,
                              usdRateUpdatedAtMsSnapshot: it.usdRateUpdatedAtMs,
                            );

                            if (!mounted) return;
                            nav.pop(line);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<double?> _askQty(BuildContext context) async {
  final c = TextEditingController(text: '1');
  final out = await showDialog<double?>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cantidad'),
      content: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: 'Ej: 2'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
            Navigator.pop(context, v);
          },
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
  return out;
}
