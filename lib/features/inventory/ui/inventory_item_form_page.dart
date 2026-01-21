import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dollar/presentation/dollar_providers.dart';
import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../domain/inventory_item.dart';

class InventoryItemFormPage extends ConsumerStatefulWidget {
  const InventoryItemFormPage({super.key, this.initial});
  final InventoryItem? initial;

  @override
  ConsumerState<InventoryItemFormPage> createState() =>
      _InventoryItemFormPageState();
}

class _InventoryItemFormPageState
    extends ConsumerState<InventoryItemFormPage> {
  // Básico (FREE)
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _price = TextEditingController(); // precio de venta (FREE)
  final _stock = TextEditingController();
  final _minStock = TextEditingController();

  // PRO
  final _cost = TextEditingController(); // costo de adquisición
  final _margin = TextEditingController(); // margen %
  final _usdBaseRate = TextEditingController();
  final _usdBaseRateFocus = FocusNode();
  bool _savingUsd = false;

  late InventoryItemKind _kind;
  bool _protectDollar = false;

  bool get _isService => _kind == InventoryItemKind.servicio;
  bool get _supportsStock => !_isService;

  double? _d(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  bool _isProCloud(String? uid) {
    if (uid == null) return false;
    final ent = ref.watch(entitlementsProvider(uid));
    return ent.maybeWhen(
      data: (e) => e.tier == PlanTier.pro && e.cloudSync,
      orElse: () => false,
    );
  }

  // ======================
  // MARGEN (SOLO PRO)
  // ======================
  void _recalcPriceFromMargin() {
    final cost = _d(_cost);
    final margin = _d(_margin);
    if (cost == null || margin == null || margin >= 100) return;
    final price = cost / (1 - margin / 100);
    _price.text = price.toStringAsFixed(2);
  }

  void _recalcMarginFromPrice() {
    final cost = _d(_cost);
    final price = _d(_price);
    if (cost == null || price == null || price <= 0) return;
    final margin = (1 - cost / price) * 100;
    _margin.text = margin.toStringAsFixed(2);
  }

  // ======================
  // DÓLAR (SOLO PRO)
  // ======================
  Future<void> _refreshUsd(String uid) async {
    setState(() => _savingUsd = true);
    try {
      final repo = ref.read(dollarRepositoryProvider);
      final rate = await repo.fetchLastRate();
      await repo.setBaseAndLastToCurrent(uid);

      final txt = rate.toStringAsFixed(2);
      _usdBaseRate.value = TextEditingValue(
        text: txt,
        selection: TextSelection.collapsed(offset: txt.length),
      );
    } finally {
      if (mounted) setState(() => _savingUsd = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _kind = i?.kind ?? InventoryItemKind.articulo;

    if (i != null) {
      _name.text = i.name;
      _unit.text = i.unit ?? '';
      _price.text = i.salePrice.toString();
      _stock.text = i.stock.toString();
      _minStock.text = i.minStock?.toString() ?? '';
      _cost.text = i.cost?.toString() ?? '';
      _protectDollar = i.dollarProtected;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    _stock.dispose();
    _minStock.dispose();
    _cost.dispose();
    _margin.dispose();
    _usdBaseRate.dispose();
    _usdBaseRateFocus.dispose();
    super.dispose();
  }

  void _save(bool proCloud) {
    final item = InventoryItem(
      id: widget.initial?.id ??
          'p_${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      salePrice: _d(_price) ?? 0,
      cost: proCloud ? _d(_cost) : null,
      stock: _supportsStock ? int.tryParse(_stock.text) ?? 0 : 0,
      minStock: _supportsStock ? _d(_minStock) : null,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
      kind: _kind,
      dollarProtected: proCloud ? _protectDollar : false,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final proCloud = _isProCloud(uid);

    if (proCloud && _margin.text.isEmpty && _cost.text.isNotEmpty) {
      _recalcMarginFromPrice();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nuevo ítem' : 'Editar ítem'),
        actions: [
          TextButton(onPressed: () => _save(proCloud), child: const Text('Guardar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),

          if (_supportsStock) ...[
            TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unidad')),
            const SizedBox(height: 12),
            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad / Stock'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minStock,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stock mínimo'),
            ),
            const SizedBox(height: 12),
          ],

          // PRECIO (FREE)
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio de venta'),
            onChanged: (_) {
              if (proCloud) _recalcMarginFromPrice();
            },
          ),
          const SizedBox(height: 12),

          // COSTO + MARGEN (SOLO PRO)
          if (proCloud) ...[
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Costo de adquisición'),
              onChanged: (_) => _recalcMarginFromPrice(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _margin,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Margen (%)'),
              onChanged: (_) => _recalcPriceFromMargin(),
            ),
            const SizedBox(height: 16),
          ],

          // DÓLAR (SOLO PRO)
          if (proCloud && uid != null) ...[
            Row(
              children: [
                const Expanded(
                  child: Text('Protector de dólar (PRO)',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Switch(
                  value: _protectDollar,
                  onChanged: (v) => setState(() => _protectDollar = v),
                ),
              ],
            ),
            if (_protectDollar) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _usdBaseRate,
                focusNode: _usdBaseRateFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tasa Base (Bs/USD)',
                  suffixIcon: IconButton(
                    icon: _savingUsd
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed:
                        _savingUsd ? null : () => _refreshUsd(uid),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
