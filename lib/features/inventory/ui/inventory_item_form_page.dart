import 'package:flutter/material.dart';

import '../domain/inventory_item.dart';

class InventoryItemFormPage extends StatefulWidget {
  const InventoryItemFormPage({super.key, this.initial});

  final InventoryItem? initial;

  @override
  State<InventoryItemFormPage> createState() => _InventoryItemFormPageState();
}

class _InventoryItemFormPageState extends State<InventoryItemFormPage> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _unit = TextEditingController();

  // Reutilizamos salePrice como "precio" según tipo
  final _price = TextEditingController(); // venta / uso / tarifa
  final _cost = TextEditingController();

  final _markup = TextEditingController(); // % margen (solo si calcMargin ON)
  final _min = TextEditingController();

  bool _useSku = false;

  InventoryItemKind _kind = InventoryItemKind.articulo;

  // Servicio: fixed vs hourly
  bool _serviceHourly = false;

  // Insumo/Artículo: activar cálculo de margen
  bool _calcMargin = false;

  bool _updating = false;

  @override
  void initState() {
    super.initState();

    final it = widget.initial;
    if (it != null) {
      _kind = it.kind;

      _name.text = it.name;
      _sku.text = it.sku ?? '';
      _useSku = (it.sku != null && it.sku!.trim().isNotEmpty);

      _unit.text = it.unit ?? '';

      _price.text = it.salePrice?.toString() ?? '';
      _cost.text = it.cost?.toString() ?? '';
      _min.text = it.minStock?.toString() ?? '';

      _calcMargin = it.calcMargin;

      _serviceHourly = (it.pricingMode ?? '') == 'hourly';

      // Si calcMargin ON y tenemos costo+precio, precargamos % margen
      final c = it.cost;
      final p = it.salePrice;
      if (_calcMargin && c != null && c > 0 && p != null) {
        final pct = ((p - c) / c) * 100.0;
        _markup.text = _fmtPct(pct);
      }
    }

    _cost.addListener(_onCostChanged);
    _price.addListener(_onPriceChanged);
    _markup.addListener(_onMarkupChanged);
  }

  @override
  void dispose() {
    _cost.removeListener(_onCostChanged);
    _price.removeListener(_onPriceChanged);
    _markup.removeListener(_onMarkupChanged);

    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    _cost.dispose();
    _markup.dispose();
    _min.dispose();
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  void _setTextSilently(TextEditingController c, String v) {
    _updating = true;
    c.text = v;
    c.selection = TextSelection.collapsed(offset: c.text.length);
    _updating = false;
  }

  String _fmtMoney(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _fmtPct(double v) {
    if (v.isNaN || v.isInfinite) return '';
    return v.toStringAsFixed(2);
  }

  bool get _supportsStock =>
      _kind == InventoryItemKind.insumo || _kind == InventoryItemKind.articulo;

  bool get _supportsMargin =>
      _kind == InventoryItemKind.insumo || _kind == InventoryItemKind.articulo;

  String get _priceLabel {
    return switch (_kind) {
      InventoryItemKind.articulo => 'Precio de venta',
      InventoryItemKind.insumo => 'Precio por uso (opcional)',
      InventoryItemKind.service =>
        _serviceHourly ? 'Tarifa por hora' : 'Precio fijo',
    };
  }

  void _onCostChanged() {
    if (_updating) return;
    if (!_supportsMargin) return;
    if (!_calcMargin) return;

    final cost = _parseDouble(_cost);
    if (cost == null || cost <= 0) return;

    final markup = _parseDouble(_markup);
    final price = _parseDouble(_price);

    if (markup != null) {
      final newPrice = cost * (1.0 + markup / 100.0);
      _setTextSilently(_price, _fmtMoney(newPrice));
      return;
    }

    if (price != null) {
      final pct = ((price - cost) / cost) * 100.0;
      _setTextSilently(_markup, _fmtPct(pct));
      return;
    }
  }

  void _onMarkupChanged() {
    if (_updating) return;
    if (!_supportsMargin) return;
    if (!_calcMargin) return;

    final cost = _parseDouble(_cost);
    final markup = _parseDouble(_markup);
    if (cost == null || cost <= 0) return;
    if (markup == null) return;

    final newPrice = cost * (1.0 + markup / 100.0);
    _setTextSilently(_price, _fmtMoney(newPrice));
  }

  void _onPriceChanged() {
    if (_updating) return;
    if (!_supportsMargin) return;
    if (!_calcMargin) return;

    final cost = _parseDouble(_cost);
    final price = _parseDouble(_price);
    if (cost == null || cost <= 0) return;
    if (price == null) return;

    final pct = ((price - cost) / cost) * 100.0;
    _setTextSilently(_markup, _fmtPct(pct));
  }

  void _setKind(InventoryItemKind k) {
    setState(() {
      _kind = k;

      // Ajustes suaves al cambiar tipo (sin romper)
      if (_kind == InventoryItemKind.service) {
        _unit.clear();
        _min.clear();
        _calcMargin = false;
        _markup.clear();
      } else {
        // Insumo/Artículo
        // El servicio por hora ya no aplica
        _serviceHourly = false;
      }
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nombre requerido.')));
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = widget.initial?.id ?? 'p_$now';

    final skuText = _sku.text.trim();
    final sku = (_useSku && skuText.isNotEmpty) ? skuText : null;

    final cost = _parseDouble(_cost);
    final price = _parseDouble(_price);

    final item = InventoryItem(
      id: id,
      name: name,
      sku: sku,
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      salePrice: price,
      cost: cost,
      stock: _kind == InventoryItemKind.service
          ? 0
          : (widget.initial?.stock ?? 0),
      minStock: _supportsStock ? _parseDouble(_min) : null,
      updatedAtMs: now,
      dirty: true,
      kind: _kind,
      pricingMode: _kind == InventoryItemKind.service
          ? (_serviceHourly ? 'hourly' : 'fixed')
          : null,
      calcMargin: _supportsMargin ? _calcMargin : false,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar ítem' : 'Nuevo ítem'),
        actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tipo
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
                    .map(
                      (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _setKind(v);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Impresión / Vinil / Resma A4 75g',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // SKU toggle + field
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SKU',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                children: [
                  const Text('Usar SKU'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useSku,
                    onChanged: (v) {
                      setState(() => _useSku = v);
                      if (!v) _sku.clear();
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_useSku) ...[
            TextField(
              controller: _sku,
              decoration: const InputDecoration(
                labelText: 'SKU del ítem',
                hintText: 'Ej: PAP-A4-75',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'Opcional. Actívalo si quieres usar un código interno.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],

          // Unidad (solo Insumo/Artículo)
          if (_supportsStock) ...[
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unidad (opcional)',
                hintText: 'u, kg, m, resma, ml...',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Servicio: por hora o fijo
          if (_kind == InventoryItemKind.service) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cobro',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('Cobrar por hora'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _serviceHourly,
                      onChanged: (v) => setState(() => _serviceHourly = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Precio / Costo / Margen
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _priceLabel,
              hintText: 'Ej: 50',
            ),
          ),
          const SizedBox(height: 12),

          if (_kind != InventoryItemKind.service) ...[
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo (opcional)',
                hintText: 'Ej: 35',
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Check calcular margen (Insumo/Artículo)
          if (_supportsMargin) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Margen',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    const Text('Calcular margen'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _calcMargin,
                      onChanged: (v) {
                        setState(() => _calcMargin = v);
                        if (!v) _markup.clear();
                        // si lo prende y ya hay costo+precio, calcula %
                        if (v) {
                          _onPriceChanged();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (_calcMargin) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _markup,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '% margen',
                  suffixText: '%',
                  hintText: 'Ej: 30',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: llena “Costo + %” o “Costo + Precio”. El otro se ajusta solo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 12),
            ],
          ],

          // Stock mínimo (solo Insumo/Artículo)
          if (_supportsStock) ...[
            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Stock mínimo (alerta)',
                hintText: 'Ej: 5',
              ),
            ),
            if (editing) ...[
              const SizedBox(height: 18),
              Text(
                'Stock actual: ${widget.initial!.stock} ${widget.initial!.unit ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
