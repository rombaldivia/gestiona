enum SaleStatus {
  draft,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case SaleStatus.draft:
        return 'Borrador';
      case SaleStatus.completed:
        return 'Completada';
      case SaleStatus.cancelled:
        return 'Anulada';
    }
  }

  static SaleStatus fromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'draft':
        return SaleStatus.draft;
      case 'completed':
        return SaleStatus.completed;
      case 'cancelled':
        return SaleStatus.cancelled;
      default:
        return SaleStatus.draft;
    }
  }
}
