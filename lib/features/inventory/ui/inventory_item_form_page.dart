import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dollar/data/dollar_repository.dart';
import '../../dollar/presentation/dollar_providers.dart';
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
  final _price = TextEditingController(); // precio base
  final _cost = TextEditingController();
  final _min = TextEditingController();

  late InventoryItemKind _kind;

  bool _useSku = false;
  bool _calcMargin = false;
  bool _serviceHourly = false;

  // NUEVO: protector dólar por ítem (solo insumo/artículo)
  bool _protectDollar = false;

  bool get _isService => _kind == InventoryItemKind.service;
  bool get _supportsStock => !_isService;
  bool get _supportsMargin => !_isService;
  bool get _supportsDollarProtection => !_isService; // solo insumo/artículo (no servicio)

  String get _priceLabel => _isService
      ? (_serviceHourly ? 'Tarifa por hora' : 'Precio del servicio')
      : 'Precio de venta (base)';

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  bool _isProCloud(String? uid) {
    if (uid == null) return false;
    final entAsync = ref.watch(entitlementsProvider(uid));
    final ent = entAsync.asData?.value; // Riverpod 3.1.0
    if (ent != null) return ent.tier == PlanTier.pro && ent.cloudSync;
    return entAsync.maybeWhen(
      data: (e) => e.tier == PlanTier.pro && e.cloudSync,
      orElse: () => false,
    );
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

      // NUEVO (por ítem)
      _protectDollar = item.dollarProtected;
    }
  }

  @override
  void dispose() {
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

        // Servicio no usa protección dólar
        _protectDollar = false;
      } else {
        _serviceHourly = false;
      }
    });
  }

  Future<void> _toggleProtectDollar({
    required bool value,
    required bool proCloud,
    required String uid,
  }) async {
    if (!proCloud) {
      setState(() => _protectDollar = false);
      return;
    }

    // Si lo activan, aseguramos que exista tasa base en user doc.
    if (value) {
      try {
        final repo = ref.read(dollarRepositoryProvider);

        // si el usuario no tiene base, la crea; si ya tiene, solo refresh.
        final st = await ref.read(dollarProtectionProvider(uid).future);
        if (!st.enabled || st.baseRate == null) {
          await repo.enableAndSetBase(uid);
        } else {
          await repo.refreshLast(uid);
        }

        setState(() => _protectDollar = true);
      } catch (e) {
        setState(() => _protectDollar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo activar protector dólar: $e')),
          );
        }
      }
      return;
    }

    // Si desactivan, solo desmarca el ítem (no desactiva global del usuario)
    setState(() => _protectDollar = false);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre requerido.')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final proCloud = _isProCloud(uid);

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = widget.initial?.id ?? 'p_$now';

    final skuText = _sku.text.trim();
    final sku = (proCloud && _useSku && skuText.isNotEmpty) ? skuText : null;

    final cost = _parseDouble(_cost);
    final price = _parseDouble(_price) ?? 0.0;

    final item = InventoryItem(
      id: id,
      name: name,
      sku: sku,
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      salePrice: price, // aquí guardamos el BASE si hay protección dólar
      cost: _supportsStock ? cost : null,
      stock: _isService ? 0 : (widget.initial?.stock ?? 0),
      minStock: _supportsStock ? _parseDouble(_min) : null,
      updatedAtMs: now,
      dirty: true,
      kind: _kind,
      pricingMode: _isService ? (_serviceHourly ? 'hourly' : 'fixed') : null,
      calcMargin: (proCloud && _supportsMargin) ? _calcMargin : false,

      // NUEVO: solo PRO+Cloud y solo insumo/artículo
      dollarProtected: (proCloud && _supportsDollarProtection) ? _protectDollar : false,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final proCloud = _isProCloud(uid);

    // Estado global del dólar (solo si PRO+Cloud)
    final dollarStateAsync = (proCloud && uid != null)
        ? ref.watch(dollarProtectionProvider(uid))
        : const AsyncValue<DollarProtectionState>.data(
            DollarProtectionState(enabled: false),
          );

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

          // SKU PRO+Cloud (solo insumo/artículo)
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

          // Precio BASE
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _priceLabel),
          ),
          const SizedBox(height: 12),

          // Margen (PRO+Cloud) solo insumo/artículo
          if (_supportsMargin) ...[
            if (proCloud) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text('Calcular margen (PRO)', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Switch(
                    value: _calcMargin,
                    onChanged: (v) => setState(() => _calcMargin = v),
                  ),
                ],
              ),
              Text(
                'Si está activo, podrás usar costo vs precio para ver margen (en % y/o Bs).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                'Calcular margen (PRO)',
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

          // Costos/stock (solo insumo/artículo)
          if (!_isService) ...[
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Costo (opcional)'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stock mínimo (opcional)'),
            ),
            const SizedBox(height: 12),
          ],

          // =========================
          // PRO: Protector de dólar (solo insumo/artículo)
          // =========================
          if (_supportsDollarProtection) ...[
            if (proCloud && uid != null) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text('Protector de dólar (PRO)', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Switch(
                    value: _protectDollar,
                    onChanged: (v) => _toggleProtectDollar(value: v, proCloud: proCloud, uid: uid),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Si lo activas, este ítem usará el factor (Actual/Base) del usuario para ajustar precios.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),

              // Preview de ajuste (solo si switch está on)
              if (_protectDollar) ...[
                dollarStateAsync.when(
                  data: (st) {
                    double? base = st.baseRate;
                    double? last = st.lastRate;

                    final basePrice = _parseDouble(_price);
                    final adjusted = (basePrice != null)
                        ? DollarRepository.adjustAmount(baseAmount: basePrice, baseRate: base, lastRate: last)
                        : null;

                    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tasa Base: ${fmt(base)} Bs/USD'),
                          Text('Tasa Actual: ${fmt(last)} Bs/USD'),
                          const SizedBox(height: 6),
                          Text(
                            'Precio ajustado: ${fmt(adjusted)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final repo = ref.read(dollarRepositoryProvider);
                                  await repo.refreshLast(uid);
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error al actualizar tasa: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Actualizar tasa'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (err, st) => Text('Error dólar: $err'),
                ),
                const SizedBox(height: 12),
              ],
            ] else ...[
              Text(
                'Protector de dólar (PRO)',
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
        ],
      ),
    );
  }
}
