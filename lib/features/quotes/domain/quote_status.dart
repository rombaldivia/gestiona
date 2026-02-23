enum QuoteStatus {
  draft,
  sent,
  accepted,
  cancelled;

  String get label {
    switch (this) {
      case QuoteStatus.draft:
        return 'Borrador';
      case QuoteStatus.sent:
        return 'Enviada';
      case QuoteStatus.accepted:
        return 'Aceptada';
      case QuoteStatus.cancelled:
        return 'Anulada';
    }
  }

  static QuoteStatus fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'sent':
        return QuoteStatus.sent;
      case 'accepted':
        return QuoteStatus.accepted;
      case 'cancelled':
        return QuoteStatus.cancelled;
      case 'draft':
      default:
        return QuoteStatus.draft;
    }
  }
}
