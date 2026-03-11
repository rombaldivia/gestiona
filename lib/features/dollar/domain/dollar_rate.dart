class DollarRate {
  const DollarRate({
    required this.venta,
    required this.updatedAtIso,
    this.source = 'binance',
  });

  final double venta;
  final String updatedAtIso;
  final String source;
}
