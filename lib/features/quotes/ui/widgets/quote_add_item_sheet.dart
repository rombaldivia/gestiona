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
                      if (i >= items.length) return const SizedBox.shrink();
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

                            // FIX: microsecondsSinceEpoch para evitar colisión
                            // de lineId cuando se agregan ítems muy rápido.
                            final now = DateTime.now().microsecondsSinceEpoch;

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
  String? errorText;

  final out = await showDialog<double?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Cantidad'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Ej: 2',
            // FIX: mostramos error en el campo si el valor no es válido
            errorText: errorText,
          ),
          onChanged: (_) {
            if (errorText != null) setState(() => errorText = null);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final raw = c.text.trim().replaceAll(',', '.');
              final v = double.tryParse(raw);

              // FIX: validamos que sea un número positivo mayor a 0
              if (v == null || v <= 0) {
                setState(() => errorText = 'Ingresa un número mayor a 0');
                return; // no cerrar el diálogo, mostrar el error
              }

              Navigator.pop(ctx, v);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    ),
  );
  return out;
}
