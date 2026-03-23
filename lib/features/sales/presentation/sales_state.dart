import '../domain/sale.dart';
import '../domain/sale_status.dart';

class SalesState {
  const SalesState({
    required this.sales,
    this.query = '',
    this.filterStatus,
  });

  final List<Sale> sales;
  final String query;
  final SaleStatus? filterStatus;

  SalesState copyWith({
    List<Sale>? sales,
    String? query,
    SaleStatus? filterStatus,
    bool clearFilter = false,
  }) {
    return SalesState(
      sales: sales ?? this.sales,
      query: query ?? this.query,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  List<Sale> get visible {
    final q = query.trim().toLowerCase();

    Iterable<Sale> it = sales;

    if (filterStatus != null) {
      it = it.where((x) => x.status == filterStatus);
    }

    if (q.isNotEmpty) {
      it = it.where((x) {
        final a = (x.customerNameOrBusinessName ?? '').toLowerCase();
        final b = (x.documentNumber ?? '').toLowerCase();
        final c = x.numberLabel.toLowerCase();
        return a.contains(q) || b.contains(q) || c.contains(q);
      });
    }

    final list = it.toList();
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list;
  }
}
