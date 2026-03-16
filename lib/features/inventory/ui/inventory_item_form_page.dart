import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../domain/inventory_item.dart';

class InventoryItemFormPage extends StatefulWidget {
  const InventoryItemFormPage({
    super.key,
    this.initial,
    this.existing,
    this.proCloud = false,
  });

  final InventoryItem? initial;
  final InventoryItem? existing;
  final bool proCloud;

  @override
  State<InventoryItemFormPage> createState() => _InventoryItemFormPageState();
}

class _InventoryItemFormPageState extends State<InventoryItemFormPage> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _unit = TextEditingController();
  final _price = TextEditingController();
  final _costBob = TextEditingController();
  final _costUsd = TextEditingController();
  final _markup = TextEditingController();
  final _min = TextEditingController();

  // USD Protector manual
  final _usdRateManual = TextEditingController();

  bool _useSku = false;
  InventoryItemKind _kind = InventoryItemKind.articulo;
  bool _serviceHourly = false;
  bool _calcMargin = false;
  bool _updating = false;

  bool _effectivePro = false;

  // PRO: moneda costo y tasa por item
  String _costCurrency = 'bob';
  double? _usdRate;
  DateTime? _usdRateAt;
  bool _fetchingRate = false;
  String _usdRateSource = 'bo.dolarapi/binance'; // o 'manual'

  // PRO: protector
  bool _protectMargin = false;
  double? _protectedUsdRateAtSave;

  InventoryItem? get _it => widget.initial ?? widget.existing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bool scopePro = false;
    try {
      final ent = EntitlementsScope.of(context);
      scopePro = ent.tier == PlanTier.pro;
    } catch (_) {
      scopePro = false;
    }
    final newEffective = scopePro || widget.proCloud;

    if (_effectivePro != newEffective) {
      setState(() {
        _effectivePro = newEffective;
        if (!_effectivePro) {
          _useSku = false;
          _calcMargin = false;
          _sku.clear();
          _markup.clear();

          _costCurrency = 'bob';
          _usdRate = null;
          _usdRateAt = null;
          _usdRateSource = 'bo.dolarapi/binance';
          _usdRateManual.clear();
          _costUsd.clear();

          _protectMargin = false;
          _protectedUsdRateAtSave = null;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();

    final it = _it;
    if (it != null) {
      _kind = it.kind;
      _name.text = it.name;
      _sku.text = it.sku ?? '';
      _useSku = (it.sku != null && it.sku!.trim().isNotEmpty);
      _unit.text = it.unit ?? '';
      _price.text = it.salePrice?.toString() ?? '';
      _costBob.text = it.cost?.toString() ?? '';
      _min.text = it.minStock?.toString() ?? '';
      _calcMargin = it.calcMargin;
      _serviceHourly = (it.pricingMode ?? '') == 'hourly';

      _costCurrency = it.costCurrency;
      if (it.costUsd != null) _costUsd.text = it.costUsd.toString();

      _usdRate = it.usdRate;
      _usdRateSource = it.usdRateSource;
      if (_usdRate != null) _usdRateManual.text = _usdRate!.toStringAsFixed(2);

      if (it.usdRateUpdatedAtMs != null) {
        _usdRateAt = DateTime.fromMillisecondsSinceEpoch(
          it.usdRateUpdatedAtMs!,
        );
      }

      _protectMargin = it.protectMargin;
      _protectedUsdRateAtSave = it.protectedUsdRateAtSave;

      final c = it.cost;
      final p = it.salePrice;
      if (_calcMargin && c != null && c > 0 && p != null) {
        final pct = ((p - c) / c) * 100.0;
        _markup.text = _fmtPct(pct);
      }
    }

    _costBob.addListener(_onCostChanged);
    _costUsd.addListener(_onCostChanged);
    _price.addListener(_onPriceChanged);
    _markup.addListener(_onMarkupChanged);

    _usdRateManual.addListener(_onManualRateChanged);
  }

  @override
  void dispose() {
    _costBob.removeListener(_onCostChanged);
    _costUsd.removeListener(_onCostChanged);
    _price.removeListener(_onPriceChanged);
    _markup.removeListener(_onMarkupChanged);
    _usdRateManual.removeListener(_onManualRateChanged);

    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    _costBob.dispose();
    _costUsd.dispose();
    _markup.dispose();
    _min.dispose();
    _usdRateManual.dispose();
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

  String _fmtMoney(double v) =>
      (v == v.roundToDouble()) ? v.toInt().toString() : v.toStringAsFixed(2);

  String _fmtPct(double v) {
    if (v.isNaN || v.isInfinite) return '';
    return v.toStringAsFixed(2);
  }

  bool get _supportsStock =>
      _kind == InventoryItemKind.insumo || _kind == InventoryItemKind.articulo;

  bool get _supportsMargin =>
      _kind == InventoryItemKind.insumo || _kind == InventoryItemKind.articulo;

  String get _priceLabel {
    switch (_kind) {
      case InventoryItemKind.articulo:
        return 'Precio de venta';
      case InventoryItemKind.insumo:
        return 'Precio por uso (opcional)';
      case InventoryItemKind.servicio:
        return _serviceHourly ? 'Tarifa por hora' : 'Precio fijo';
    }
  }

  double? _effectiveCostBobForMath() {
    if (_kind == InventoryItemKind.servicio) return null;

    if (!_effectivePro || _costCurrency == 'bob') {
      return _parseDouble(_costBob);
    }

    final usd = _parseDouble(_costUsd);
    if (usd == null || usd <= 0) return null;
    if (_usdRate == null || _usdRate! <= 0) return null;
    return usd * _usdRate!;
  }

  void _onCostChanged() {
    if (_updating) return;
    if (!_supportsMargin) return;
    if (!_calcMargin) return;

    final cost = _effectiveCostBobForMath();
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

    final cost = _effectiveCostBobForMath();
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

    final cost = _effectiveCostBobForMath();
    final price = _parseDouble(_price);
    if (cost == null || cost <= 0) return;
    if (price == null) return;

    final pct = ((price - cost) / cost) * 100.0;
    _setTextSilently(_markup, _fmtPct(pct));
  }

  void _onManualRateChanged() {
    if (!_effectivePro) return;
    if (_updating) return;

    final r = _parseDouble(_usdRateManual);
    if (r == null || r <= 0) return;

    setState(() {
      _usdRate = r;
      _usdRateAt = DateTime.now();
      _usdRateSource = 'manual';
      if (_protectMargin) {
        _protectedUsdRateAtSave ??= r;
      }
    });

    if (_protectMargin && _calcMargin) {
      _onCostChanged();
    }
  }

  void _setKind(InventoryItemKind k) {
    setState(() {
      _kind = k;

      if (_kind == InventoryItemKind.servicio) {
        _unit.clear();
        _min.clear();
        _calcMargin = false;
        _markup.clear();

        _costCurrency = 'bob';
        _usdRate = null;
        _usdRateAt = null;
        _usdRateSource = 'bo.dolarapi/binance';
        _usdRateManual.clear();
        _costUsd.clear();
        _protectMargin = false;
        _protectedUsdRateAtSave = null;
      } else {
        _serviceHourly = false;
      }

      if (!_effectivePro) {
        _useSku = false;
        _calcMargin = false;
        _sku.clear();
        _markup.clear();
        _costCurrency = 'bob';
        _usdRate = null;
        _usdRateAt = null;
        _usdRateSource = 'bo.dolarapi/binance';
        _usdRateManual.clear();
        _costUsd.clear();
        _protectMargin = false;
        _protectedUsdRateAtSave = null;
      }
    });
  }

  Future<void> _fetchBinanceRate({required bool applyProtector}) async {
    setState(() => _fetchingRate = true);
    try {
      final uri = Uri.parse('https://bo.dolarapi.com/v1/dolares/binance');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final venta = data['venta'];
      final fecha = data['fechaActualizacion'];

      final rate = (venta is num)
          ? venta.toDouble()
          : double.tryParse('$venta');
      final dt = (fecha is String) ? DateTime.tryParse(fecha) : null;

      if (rate == null || rate <= 0) {
        throw Exception('Tasa inválida: $venta');
      }

      setState(() {
        _usdRate = rate;
        _usdRateAt = dt ?? DateTime.now();
        _usdRateSource = 'bo.dolarapi/binance';
        _setTextSilently(_usdRateManual, rate.toStringAsFixed(2));
        if (applyProtector) {
          _protectedUsdRateAtSave ??= rate;
        }
      });

      if (_protectMargin && _calcMargin) _onCostChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tasa Binance: ${rate.toStringAsFixed(2)} Bs/USD'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo traer tasa Binance: $e')),
      );
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
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
    final id = _it?.id ?? 'p_$now';

    final skuText = _sku.text.trim();
    final sku = (_effectivePro && _useSku && skuText.isNotEmpty)
        ? skuText
        : null;

    final price = _parseDouble(_price);

    double? costBob;
    double? costUsd;
    double? usdRate;
    int? usdRateUpdatedAtMs;
    String costCurrency = 'bob';

    if (_kind != InventoryItemKind.servicio) {
      usdRate = _usdRate;
      usdRateUpdatedAtMs = _usdRateAt?.millisecondsSinceEpoch;

      if (_effectivePro && _costCurrency == 'usd') {
        costCurrency = 'usd';
        costUsd = _parseDouble(_costUsd);

        if (costUsd != null && costUsd > 0) {
          if (usdRate == null || usdRate <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Falta tasa USD→Bs. Usa Binance o manual.'),
              ),
            );
            return;
          }
          costBob = costUsd * usdRate;
        } else {
          costBob = null;
        }
      } else {
        costCurrency = 'bob';
        costBob = _parseDouble(_costBob);
        costUsd = null;

        if (_effectivePro && _protectMargin) {
          if (usdRate == null || usdRate <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Activas USD Protector, pero falta tasa.'),
              ),
            );
            return;
          }
        }
      }
    }

    final calcMargin = (_supportsMargin && _effectivePro) ? _calcMargin : false;

    final item = InventoryItem(
      id: id,
      name: name,
      sku: sku,
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      salePrice: price,
      cost: costBob,
      stock: _kind == InventoryItemKind.servicio ? 0 : (_it?.stock ?? 0),
      minStock: _supportsStock ? _parseDouble(_min) : null,
      updatedAtMs: now,
      dirty: true,
      kind: _kind,
      pricingMode: _kind == InventoryItemKind.servicio
          ? (_serviceHourly ? 'hourly' : 'fixed')
          : null,
      calcMargin: calcMargin,

      costCurrency: costCurrency,
      costUsd: costUsd,
      usdRate: usdRate,
      usdRateUpdatedAtMs: usdRateUpdatedAtMs,
      usdRateSource: _usdRateSource,

      protectMargin: _effectivePro ? _protectMargin : false,
      protectedUsdRateAtSave: _effectivePro ? _protectedUsdRateAtSave : null,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final editing = _it != null;

    final convertedBob = (_effectivePro && _costCurrency == 'usd')
        ? _effectiveCostBobForMath()
        : null;

    final showUsdProtector =
        _effectivePro && _kind != InventoryItemKind.servicio;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _save(); },
      child: Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar ítem' : 'Nuevo ítem'),
        leading: BackButton(onPressed: _save),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // DEBUG
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              'DEBUG: effectivePro=$_effectivePro | kind=${_kind.label} | costCurrency=$_costCurrency | usdRate=${_usdRate?.toStringAsFixed(2) ?? "null"} | source=$_usdRateSource | protectMargin=$_protectMargin',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),

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
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),

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
                  Text(_effectivePro ? 'Usar SKU' : 'Usar SKU (PRO)'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useSku,
                    onChanged: _effectivePro
                        ? (v) {
                            setState(() => _useSku = v);
                            if (!v) _sku.clear();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
          if (_useSku && _effectivePro) ...[
            TextField(
              controller: _sku,
              decoration: const InputDecoration(labelText: 'SKU del ítem'),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 12),
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

          if (_kind == InventoryItemKind.servicio) ...[
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
                    const Text('Por hora'),
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

          if (_kind != InventoryItemKind.servicio) ...[
            if (_effectivePro) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Moneda del costo (PRO)',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _costCurrency,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'bob', child: Text('Bs')),
                      DropdownMenuItem(value: 'usd', child: Text('USD')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _costCurrency = v);
                      _onCostChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _priceLabel),
          ),
          const SizedBox(height: 12),

          if (_kind != InventoryItemKind.servicio) ...[

            if (!_effectivePro || _costCurrency == 'bob') ...[
              TextField(
                controller: _costBob,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo (Bs) (opcional)',
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              TextField(
                controller: _costUsd,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Costo (USD) (PRO)',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

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
                    Text(
                      _effectivePro
                          ? 'Calcular margen'
                          : 'Calcular margen (PRO)',
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _calcMargin,
                      onChanged: _effectivePro
                          ? (v) {
                              setState(() => _calcMargin = v);
                              if (!v) _markup.clear();
                              if (v) _onPriceChanged();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (_calcMargin && _effectivePro) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _markup,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '% margen',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 12),
            ],
          ],


          if (showUsdProtector) ...[
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'USD Protector (PRO)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _fetchingRate
                      ? null
                      : () => _fetchBinanceRate(applyProtector: true),
                  icon: _fetchingRate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download),
                  label: const Text('Traer Binance'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _usdRateManual,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tasa USD→Bs (manual)',
                hintText: 'Ej: 9.21',
              ),
            ),
            const SizedBox(height: 8),

            Text(
              _usdRate == null
                  ? 'Tasa activa: (vacío)'
                  : 'Tasa activa: ${_usdRate!.toStringAsFixed(2)} Bs/USD',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _usdRateAt == null
                  ? 'Fuente: $_usdRateSource'
                  : 'Fuente: $_usdRateSource • ${_usdRateAt!.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mantener margen si cambia el dólar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: _protectMargin,
                  onChanged: (v) {
                    setState(() {
                      _protectMargin = v;
                      if (v && _usdRate != null) {
                        _protectedUsdRateAtSave ??= _usdRate;
                      }
                      if (!v) _protectedUsdRateAtSave = null;
                    });
                  },
                ),
              ],
            ),
            if (_protectMargin) ...[
              Text(
                _protectedUsdRateAtSave == null
                    ? 'Protección activa (falta fijar tasa base)'
                    : 'Tasa base fijada: ${_protectedUsdRateAtSave!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],

            if (convertedBob != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  'Costo convertido (Bs): ${_fmtMoney(convertedBob)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          if (_supportsStock) ...[
            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Stock mínimo (alerta)',
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}
