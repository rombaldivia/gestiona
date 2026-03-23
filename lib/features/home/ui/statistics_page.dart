import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../company/presentation/company_scope.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../quotes/domain/quote.dart';
import '../../quotes/domain/quote_status.dart';
import '../../quotes/presentation/quotes_controller.dart';
import '../../work_orders/domain/work_order.dart';
import '../../work_orders/domain/work_order_status.dart';
import '../../work_orders/presentation/work_orders_controller.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = CompanyScope.of(context);

    final quotesState = ref.watch(quotesControllerProvider);
    final ordersState = ref.watch(workOrdersControllerProvider);
    final items = ref.watch(inventoryItemsProvider);

    final quotes = quotesState.value?.quotes ?? const <Quote>[];
    final orders = ordersState.value?.orders ?? const <WorkOrder>[];

    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month, 1);
    final endMonth = DateTime(now.year, now.month + 1, 1);
    final startWeek = _startOfWeek(now);
    final endWeek = startWeek.add(const Duration(days: 7));
    final start90d = now.subtract(const Duration(days: 90));

    final monthQuotes = quotes.where((q) => _inRange(q.createdAtMs, startMonth, endMonth)).toList();
    final weekQuotes = quotes.where((q) => _inRange(q.createdAtMs, startWeek, endWeek)).toList();

    final acceptedMonth = monthQuotes.where((q) => q.status == QuoteStatus.accepted).toList();
    final sentMonth = monthQuotes.where((q) => q.status == QuoteStatus.sent).toList();
    final draftMonth = monthQuotes.where((q) => q.status == QuoteStatus.draft).toList();

    final totalQuotedMonth = monthQuotes.fold<double>(0, (sum, q) => sum + q.totalBob);
    final totalAcceptedMonth = acceptedMonth.fold<double>(0, (sum, q) => sum + q.totalBob);

    final conversionPct = monthQuotes.isEmpty
        ? 0.0
        : (acceptedMonth.length / monthQuotes.length) * 100.0;

    final closedOrdersMonth = orders.where((o) {
      final closed = o.status == WorkOrderStatus.done || o.status == WorkOrderStatus.delivered;
      return closed && _inRange(o.updatedAtMs, startMonth, endMonth);
    }).length;

    final activeOrders = orders.where((o) {
      return o.status == WorkOrderStatus.pending || o.status == WorkOrderStatus.inProgress;
    }).length;

    final lateOrders = orders.where((o) {
      if (o.deliveryAtMs == null) return false;
      final due = DateTime.fromMillisecondsSinceEpoch(o.deliveryAtMs!);
      final closed = o.status == WorkOrderStatus.done || o.status == WorkOrderStatus.delivered;
      return !closed && due.isBefore(now);
    }).length;

    final lowStock = items.where((i) {
      if (!i.tracksStock) return false;
      if (i.minStock == null) return false;
      return i.stock <= i.minStock!;
    }).length;

    final weeklyBars = _buildWeeklyBars(weekQuotes, startWeek);
    final topClients = _buildTopClients(quotes, start90d);
    final topServices = _buildTopServices(quotes, start90d);

    final isLoading = (quotesState.isLoading && quotes.isEmpty) ||
        (ordersState.isLoading && orders.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.companyName,
                        style: AppTextStyles.title.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Datos reales basados en cotizaciones, órdenes de trabajo e inventario.',
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nota: mientras no exista ventas/facturación final, el monto comercial se calcula desde cotizaciones aceptadas.',
                        style: AppTextStyles.label.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(label: 'Mes actual'),
                          _InfoChip(label: '${monthQuotes.length} cotizaciones'),
                          _InfoChip(label: '$activeOrders OTs activas'),
                          if (lowStock > 0) _InfoChip(label: '$lowStock stock bajo', color: AppColors.warning),
                          if (lateOrders > 0) _InfoChip(label: '$lateOrders atrasadas', color: AppColors.error),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Cotizado del mes',
                        value: _fmtBob(totalQuotedMonth),
                        hint: '${monthQuotes.length} cotizaciones',
                        color: AppColors.quotes,
                        icon: Icons.request_quote_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Aceptado del mes',
                        value: _fmtBob(totalAcceptedMonth),
                        hint: '${acceptedMonth.length} aceptadas',
                        color: AppColors.success,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Conversión',
                        value: '${conversionPct.toStringAsFixed(0)}%',
                        hint: '${acceptedMonth.length} de ${monthQuotes.length}',
                        color: AppColors.primaryLight,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'OTs cerradas',
                        value: '$closedOrdersMonth',
                        hint: '$activeOrders activas ahora',
                        color: AppColors.workOrders,
                        icon: Icons.engineering_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        label: 'Enviadas',
                        value: '${sentMonth.length}',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniMetricCard(
                        label: 'Borradores',
                        value: '${draftMonth.length}',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniMetricCard(
                        label: 'Stock bajo',
                        value: '$lowStock',
                        color: lowStock > 0 ? AppColors.warning : AppColors.inventory,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const _SectionTitle(title: 'Cotizado esta semana'),
                const SizedBox(height: 10),
                _WeeklyRevenueChart(data: weeklyBars),

                const SizedBox(height: 18),
                const _SectionTitle(title: 'Top clientes (últimos 90 días)'),
                const SizedBox(height: 10),
                if (topClients.isEmpty)
                  const _EmptyCard(message: 'Todavía no hay clientes con cotizaciones aceptadas.')
                else
                  _ClientRankingCard(items: topClients),

                const SizedBox(height: 18),
                const _SectionTitle(title: 'Servicios / productos destacados (últimos 90 días)'),
                const SizedBox(height: 10),
                if (topServices.isEmpty)
                  const _EmptyCard(message: 'Todavía no hay líneas aceptadas para analizar.')
                else
                  _ServiceRankingCard(items: topServices),
              ],
            ),
    );
  }
}

bool _inRange(int ms, DateTime start, DateTime endExclusive) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return !d.isBefore(start) && d.isBefore(endExclusive);
}

DateTime _startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final weekday = local.weekday; // lun=1 ... dom=7
  return local.subtract(Duration(days: weekday - 1));
}

List<_WeekBarDatum> _buildWeeklyBars(List<Quote> quotes, DateTime startWeek) {
  final totals = List<double>.filled(7, 0);
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  for (final q in quotes) {
    final d = DateTime.fromMillisecondsSinceEpoch(q.createdAtMs);
    final index = d.weekday - 1;
    if (index >= 0 && index < 7) {
      totals[index] += q.totalBob;
    }
  }

  return List.generate(7, (i) {
    return _WeekBarDatum(label: labels[i], amount: totals[i]);
  });
}

List<_ClientMetric> _buildTopClients(List<Quote> quotes, DateTime startDate) {
  final map = <String, _ClientAgg>{};

  for (final q in quotes) {
    if (q.status != QuoteStatus.accepted) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(q.createdAtMs);
    if (d.isBefore(startDate)) continue;

    final rawName = (q.customerName ?? '').trim();
    final name = rawName.isEmpty ? 'Cliente sin nombre' : rawName;

    final agg = map.putIfAbsent(name, () => _ClientAgg());
    agg.total += q.totalBob;
    agg.count += 1;
  }

  final list = map.entries.map((e) {
    return _ClientMetric(
      name: e.key,
      totalBob: e.value.total,
      quotesCount: e.value.count,
    );
  }).toList();

  list.sort((a, b) => b.totalBob.compareTo(a.totalBob));
  return list.take(5).toList();
}

List<_ServiceMetric> _buildTopServices(List<Quote> quotes, DateTime startDate) {
  final map = <String, _ServiceAgg>{};

  for (final q in quotes) {
    if (q.status != QuoteStatus.accepted) continue;
    final d = DateTime.fromMillisecondsSinceEpoch(q.createdAtMs);
    if (d.isBefore(startDate)) continue;

    for (final line in q.lines) {
      final name = line.nameSnapshot.trim().isEmpty
          ? 'Ítem sin nombre'
          : line.nameSnapshot.trim();

      final agg = map.putIfAbsent(name, () => _ServiceAgg());
      agg.revenue += line.lineTotalBob;
      agg.qty += line.qty;
    }
  }

  final list = map.entries.map((e) {
    return _ServiceMetric(
      name: e.key,
      revenueBob: e.value.revenue,
      qty: e.value.qty,
    );
  }).toList();

  list.sort((a, b) => b.revenueBob.compareTo(a.revenueBob));
  return list.take(5).toList();
}

String _fmtBob(num value) => 'Bs ${_fmtNum(value, decimals: 0)}';

String _fmtQty(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return _fmtNum(value, decimals: 2);
}

String _fmtNum(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final s = parts[0];
  final negative = s.startsWith('-');
  final digits = negative ? s.substring(1) : s;

  final chunks = <String>[];
  for (int i = digits.length; i > 0; i -= 3) {
    final start = math.max(0, i - 3);
    chunks.insert(0, digits.substring(start, i));
  }

  final intPart = '${negative ? '-' : ''}${chunks.join('.')}';
  if (decimals == 0) return intPart;
  return '$intPart,${parts[1]}';
}

class _ClientAgg {
  double total = 0;
  int count = 0;
}

class _ServiceAgg {
  double revenue = 0;
  double qty = 0;
}

class _WeekBarDatum {
  const _WeekBarDatum({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;
}

class _ClientMetric {
  const _ClientMetric({
    required this.name,
    required this.totalBob,
    required this.quotesCount,
  });

  final String name;
  final double totalBob;
  final int quotesCount;
}

class _ServiceMetric {
  const _ServiceMetric({
    required this.name,
    required this.revenueBob,
    required this.qty,
  });

  final String name;
  final double revenueBob;
  final double qty;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.title.copyWith(fontSize: 15),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String hint;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.label.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headline.copyWith(
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: AppTextStyles.body.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              color: color,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WeeklyRevenueChart extends StatelessWidget {
  const _WeeklyRevenueChart({required this.data});

  final List<_WeekBarDatum> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<double>(
      1,
      (previousValue, element) => math.max(previousValue, element.amount),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: SizedBox(
        height: 230,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((item) {
            final factor = maxValue <= 0 ? 0.0 : item.amount / maxValue;
            final barHeight = item.amount <= 0 ? 12.0 : 24.0 + (136.0 * factor);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.amount <= 0 ? '0' : _fmtNum(item.amount, decimals: 0),
                      style: AppTextStyles.label.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: AppTextStyles.label.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ClientRankingCard extends StatelessWidget {
  const _ClientRankingCard({required this.items});

  final List<_ClientMetric> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                items[i].name,
                style: AppTextStyles.title.copyWith(fontSize: 14),
              ),
              subtitle: Text(
                '${items[i].quotesCount} cotizaciones aceptadas',
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
              trailing: Text(
                _fmtBob(items[i].totalBob),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceRankingCard extends StatelessWidget {
  const _ServiceRankingCard({required this.items});

  final List<_ServiceMetric> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                items[i].name,
                style: AppTextStyles.title.copyWith(fontSize: 14),
              ),
              subtitle: Text(
                'Cantidad: ${_fmtQty(items[i].qty)}',
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
              trailing: Text(
                _fmtBob(items[i].revenueBob),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
