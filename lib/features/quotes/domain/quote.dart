import 'quote_line.dart';
import 'quote_status.dart';

class Quote {
  Quote({
    required this.id,
    required this.sequence,
    required this.year,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.status,
    this.customerName,
    this.customerPhone,
    this.notes,
    required this.currency,
    required this.lines,
    this.sourceQuoteId,
    this.sourceMode, // "duplicate" | "requote"
  });

  final String id;

  /// Correlativo humano: 1,2,3...
  final int sequence;

  /// Para reset anual del correlativo (recomendado)
  final int year;

  final int createdAtMs;
  final int updatedAtMs;
  final QuoteStatus status;

  final String? customerName;

  /// ✅ nuevo: para WhatsApp
  final String? customerPhone;

  final String? notes;

  final String currency; // "BOB" por ahora
  final List<QuoteLine> lines;

  // versionado
  final String? sourceQuoteId;
  final String? sourceMode;

  double get subtotalBob => lines.fold(0.0, (a, l) => a + l.lineTotalBob);
  double get totalBob => subtotalBob;

  Quote copyWith({
    String? id,
    int? sequence,
    int? year,
    int? createdAtMs,
    int? updatedAtMs,
    QuoteStatus? status,
    String? customerName,
    String? customerPhone,
    String? notes,
    String? currency,
    List<QuoteLine>? lines,
    String? sourceQuoteId,
    String? sourceMode,
  }) {
    return Quote(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      year: year ?? this.year,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
      lines: lines ?? this.lines,
      sourceQuoteId: sourceQuoteId ?? this.sourceQuoteId,
      sourceMode: sourceMode ?? this.sourceMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence': sequence,
        'year': year,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'status': status.name,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'notes': notes,
        'currency': currency,
        'lines': lines.map((e) => e.toJson()).toList(),
        'sourceQuoteId': sourceQuoteId,
        'sourceMode': sourceMode,
      };

  factory Quote.fromJson(Map<String, dynamic> m) {
    final lines = (m['lines'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((e) => QuoteLine.fromJson(e))
        .toList();

    int toIntSafe(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

    return Quote(
      id: (m['id'] ?? '').toString(),
      sequence: toIntSafe(m['sequence'], 0),
      year: toIntSafe(m['year'], DateTime.now().year),
      createdAtMs: toIntSafe(m['createdAtMs'], 0),
      updatedAtMs: toIntSafe(m['updatedAtMs'], 0),
      status: QuoteStatus.fromString(m['status']?.toString()),
      customerName: m['customerName']?.toString(),
      customerPhone: m['customerPhone']?.toString(),
      notes: m['notes']?.toString(),
      currency: (m['currency'] ?? 'BOB').toString(),
      lines: lines,
      sourceQuoteId: m['sourceQuoteId']?.toString(),
      sourceMode: m['sourceMode']?.toString(),
    );
  }
}
