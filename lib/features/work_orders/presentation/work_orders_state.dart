import '../domain/work_order.dart';
import '../domain/work_order_status.dart';

class WorkOrdersState {
  const WorkOrdersState({
    required this.orders,
    this.filterStatus,
    this.query = '',
  });

  final List<WorkOrder> orders;
  final WorkOrderStatus? filterStatus;
  final String query;

  List<WorkOrder> get visible {
    var list = [...orders];
    if (filterStatus != null) {
      list = list.where((o) => o.status == filterStatus).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((o) {
        final name = (o.customerName ?? '').toLowerCase();
        final num  = 'OT #${o.sequence}-${o.year}'.toLowerCase();
        return name.contains(q) || num.contains(q);
      }).toList();
    }
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list;
  }

  WorkOrdersState copyWith({
    List<WorkOrder>? orders,
    WorkOrderStatus? filterStatus,
    bool clearFilter = false,
    String? query,
  }) {
    return WorkOrdersState(
      orders:       orders ?? this.orders,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
      query:        query ?? this.query,
    );
  }
}
