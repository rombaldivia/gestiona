enum SaleDocumentType {
  nit,
  ci;

  String get label {
    switch (this) {
      case SaleDocumentType.nit:
        return 'NIT';
      case SaleDocumentType.ci:
        return 'CI';
    }
  }

  static SaleDocumentType? fromString(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'nit':
        return SaleDocumentType.nit;
      case 'ci':
        return SaleDocumentType.ci;
      default:
        return null;
    }
  }
}
