import '../domain/quote.dart';
import '../domain/quote_status.dart';

class QuotesState {
  const QuotesState({
    required this.quotes,
    this.query = '',
    this.filterStatus,
  });

  final List<Quote> quotes;

  /// Texto de búsqueda
  final String query;

  /// null = Todas
  final QuoteStatus? filterStatus;

  QuotesState copyWith({
    List<Quote>? quotes,
    String? query,
    QuoteStatus? filterStatus,
    bool clearFilter = false,
  }) {
    return QuotesState(
      quotes: quotes ?? this.quotes,
      query: query ?? this.query,
      filterStatus: clearFilter ? null : (filterStatus ?? this.filterStatus),
    );
  }

  List<Quote> get filtered => _computeVisible();
  List<Quote> get visible => _computeVisible();

  List<Quote> _computeVisible() {
    final q = query.trim().toLowerCase();

    Iterable<Quote> it = quotes;

    if (filterStatus != null) {
      it = it.where((x) => x.status == filterStatus);
    }

    if (q.isNotEmpty) {
      it = it.where((x) {
        final a = (x.customerName ?? '').toLowerCase();
        final b = x.id.toLowerCase();
        final c = 'cot #${x.sequence}'.toLowerCase();
        return a.contains(q) || b.contains(q) || c.contains(q);
      });
    }

    final list = it.toList();
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list;
  }
}
