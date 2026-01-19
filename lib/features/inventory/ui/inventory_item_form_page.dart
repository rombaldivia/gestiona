import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../domain/inventory_item.dart';

class InventoryItemFormPage extends ConsumerStatefulWidget {
  const InventoryItemFormPage({super.key, this.initial});
  final InventoryItem? initial;

  @override
  ConsumerState<InventoryItemFormPage> createState() => _InventoryItemFormPageState();
}

class _InventoryItemFormPageState extends ConsumerState<InventoryItemFormPage> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _unit = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _min = TextEditingController();

  late InventoryItemKind _kind;

  bool _useSku = false;
  bool _calcMargin = false;
  bool _serviceHourly = false;

  // valores calculados para mostrar (no se guardan)
  double? _profitMoney;   // Bs
  double? _markupPct;     // %
  double? _marginPct;     // %

  bool get _isService => _kind == InventoryItemKind.service;
  bool get _supportsStock => !_isService;
  bool get _supportsMargin => !_isService;

  String get _priceLabel => _isService
      ? (_serviceHourly ? 'Tarifa por hora' : 'Precio del servicio')
      : 'Precio de venta';

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _fmtMoney(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _fmtPct(double v) => v.toStringAsFixed(2);

  void _recalcMargins() {
    if (!_calcMargin || !_supportsMargin) {
      setState(() {
        _profitMoney = null;
        _markupPct = null;
        _marginPct = null;
      });
      return;
    }

    final price = _parseDouble(_price);
    final cost = _parseDouble(_cost);

    if (price == null || cost == null || price <= 0 || cost < 0) {
      setState(() {
        _profitMoney = null;
        _markupPct = null;
        _marginPct = null;
      });
      return;
    }

    final profit = price - cost;

    double? markup;
    if (cost > 0) markup = (profit / cost) * 100.0;

    final margin = (profit / price) * 100.0;

    setState(() {
      _profitMoney = profit;
      _markupPct = markup;
      _marginPct = margin;
    });
  }

  bool _proCloudFrom(AsyncValue<dynamic> entAsync) {
    final ent = entAsync.asData?.value;
    if (ent == null) return false;
    // ent es Entitlements (dynamic por seguridad acá)
    try {
      return ent.tier == PlanTier.pro && ent.cloudSync == true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();

    final item = widget.initial;
    _kind = item?.kind ?? InventoryItemKind.articulo;

    if (item != null) {
      _name.text = item.name;
      _unit.text = item.unit ?? '';
      _price.text = item.salePrice.toString();
      _cost.text = item.cost?.toString() ?? '';
      _min.text = item.minStock?.toString() ?? '';
      _sku.text = item.sku ?? '';
      _useSku = (item.sku ?? '').isNotEmpty;
      _calcMargin = item.calcMargin;
      _serviceHourly = (item.pricingMode ?? '') == 'hourly';
    }

    _price.addListener(_recalcMargins);
    _cost.addListener(_recalcMargins);

    // primer cálculo (si venía activado)
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcMargins());
  }

  @override
  void dispose() {
    _price.removeListener(_recalcMargins);
    _cost.removeListener(_recalcMargins);

    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    _cost.dispose();
    _min.dispose();
    super.dispose();
  }

  void _onKindChanged(InventoryItemKind v) {
    setState(() {
      _kind = v;
      if (_isService) {
        _unit.clear();
        _min.clear();
        _cost.clear();
        _useSku = false;
        _sku.clear();
        _calcMargin = false;
      } else {
        _serviceHourly = false;
      }
    });
    _recalcMargins();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre requerido.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    // En callbacks usa ref.read (no watch)
    final proCloud = (uid == null)
        ? false
        : _proCloudFrom(ref.read(entitlementsProvider(uid)));

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = widget.initial?.id ?? 'p_$now';

    final skuText = _sku.text.trim();
    final sku = (proCloud && _useSku && skuText.isNotEmpty) ? skuText : null;

    final cost = _parseDouble(_cost);
    final price = _parseDouble(_price) ?? 0.0;

    // Si calcMargin está ON, exigimos costo válido para poder calcular
    if (!_isService && proCloud && _calcMargin) {
      if (cost == null || cost <= 0 || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para calcular margen, ingresa Costo y Precio válidos.')),
        );
        return;
      }
    }

    final item = InventoryItem(
      id: id,
      name: name,
      sku: sku,
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      salePrice: price,
      cost: _supportsStock ? cost : null,
      stock: _isService ? 0 : (widget.initial?.stock ?? 0),
      minStock: _supportsStock ? _parseDouble(_min) : null,
      updatedAtMs: now,
      dirty: true,
      kind: _kind,
      pricingMode: _isService ? (_serviceHourly ? 'hourly' : 'fixed') : null,
      calcMargin: (proCloud && _supportsMargin) ? _calcMargin : false,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    final entAsync = (uid == null) ? null : ref.watch(entitlementsProvider(uid));
    final proCloud = (entAsync == null) ? false : _proCloudFrom(entAsync);

    // Si deja de ser proCloud, apagamos calcMargin y SKU
    if (!proCloud && (_calcMargin || _useSku)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _calcMargin = false;
          _useSku = false;
          _sku.clear();
        });
        _recalcMargins();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar ítem' : 'Nuevo ítem'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InventoryItemKind>(
                value: _kind,
                isExpanded: true,
                items: InventoryItemKind.values
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.label),
                        ))
                    .toList(),
                onChanged: (v) => v == null ? null : _onKindChanged(v),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Papel A4 75g',
            ),
          ),
          const SizedBox(height: 12),

          // SKU PRO+Cloud
          if (_supportsStock) ...[
            if (proCloud) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SKU (PRO + Cloud Sync)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: _useSku,
                    onChanged: (v) {
                      setState(() => _useSku = v);
                      if (!v) _sku.clear();
                    },
                  ),
                ],
              ),
              if (_useSku) ...[
                TextField(
                  controller: _sku,
                  decoration: const InputDecoration(
                    labelText: 'SKU del ítem',
                    hintText: 'Ej: INS-001',
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Opcional. Actívalo si quieres un código interno.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              Text(
                'SKU (PRO + Cloud Sync)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Disponible solo en Plan PRO con Cloud Sync activo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
          ],

          if (_supportsStock) ...[
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unidad (opcional)',
                hintText: 'u, kg, m...',
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_isService) ...[
            Row(
              children: [
                const Expanded(child: Text('Cobro', style: TextStyle(fontWeight: FontWeight.w700))),
                const Text('Por hora'),
                const SizedBox(width: 8),
                Switch(
                  value: _serviceHourly,
                  onChanged: (v) => setState(() => _serviceHourly = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _priceLabel),
          ),
          const SizedBox(height: 12),

          // Costo + Márgenes (solo para no-service)
          if (!_isService) ...[
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Costo'),
            ),
            const SizedBox(height: 12),

            // Switch Calcular margen (PRO+Cloud)
            if (proCloud) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Calcular margen',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch(
                    value: _calcMargin,
                    onChanged: (v) {
                      setState(() => _calcMargin = v);
                      _recalcMargins();
                    },
                  ),
                ],
              ),

              if (_calcMargin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Márgenes calculados',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _profitMoney == null
                          ? Text(
                              'Ingresa Costo y Precio para ver el cálculo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ganancia: Bs ${_fmtMoney(_profitMoney!)}'),
                                const SizedBox(height: 4),
                                Text(_markupPct == null
                                    ? 'Markup (sobre costo): —'
                                    : 'Markup (sobre costo): ${_fmtPct(_markupPct!)}%'),
                                const SizedBox(height: 4),
                                Text('Margen (sobre precio): ${_fmtPct(_marginPct!)}%'),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              Text(
                'Calcular margen (PRO + Cloud Sync)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Disponible solo en Plan PRO con Cloud Sync activo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Stock mínimo (si aplica)
          if (_supportsStock) ...[
            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stock mínimo (opcional)'),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
