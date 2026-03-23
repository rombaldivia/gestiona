import '../../quotes/domain/quote_line.dart';
import 'sale_document_type.dart';
import 'sale_status.dart';

class Sale {
  Sale({
    required this.id,
    required this.sequence,
    required this.year,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.status,
    this.documentType,
    this.documentNumber,
    this.customerNameOrBusinessName,
    this.customerPhone,
    this.customerEmail,
    this.notes,
    required this.currency,
    required this.lines,
    this.stockApplied = false,
  });

  final String id;
  final int sequence;
  final int year;
  final int createdAtMs;
  final int updatedAtMs;
  final SaleStatus status;

  final SaleDocumentType? documentType;
  final String? documentNumber;
  final String? customerNameOrBusinessName;
  final String? customerPhone;
  final String? customerEmail;
  final String? notes;

  final String currency;
  final List<QuoteLine> lines;

  /// true = ya descontó/revirtió stock según corresponda
  final bool stockApplied;

  String get numberLabel => 'VTA-$sequence-$year';

  double get subtotalBob =>
      lines.fold(0.0, (sum, line) => sum + line.lineTotalBob);

  double get totalBob => subtotalBob;

  Sale copyWith({
    String? id,
    int? sequence,
    int? year,
    int? createdAtMs,
    int? updatedAtMs,
    SaleStatus? status,
    SaleDocumentType? documentType,
    String? documentNumber,
    String? customerNameOrBusinessName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
    String? currency,
    List<QuoteLine>? lines,
    bool? stockApplied,
  }) {
    return Sale(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      year: year ?? this.year,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      status: status ?? this.status,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      customerNameOrBusinessName:
          customerNameOrBusinessName ?? this.customerNameOrBusinessName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
      lines: lines ?? this.lines,
      stockApplied: stockApplied ?? this.stockApplied,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence': sequence,
        'year': year,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'status': status.name,
        'documentType': documentType?.name,
        'documentNumber': documentNumber,
        'customerNameOrBusinessName': customerNameOrBusinessName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'notes': notes,
        'currency': currency,
        'lines': lines.map((e) => e.toJson()).toList(),
        'stockApplied': stockApplied,
      };

  factory Sale.fromJson(Map<String, dynamic> map) {
    int toIntSafe(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

    final rawLines = (map['lines'] as List? ?? const []);
    final lines = rawLines
        .map((e) => QuoteLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Sale(
      id: (map['id'] ?? '').toString(),
      sequence: toIntSafe(map['sequence'], 0),
      year: toIntSafe(map['year'], DateTime.now().year),
      createdAtMs: toIntSafe(map['createdAtMs'], 0),
      updatedAtMs: toIntSafe(map['updatedAtMs'], 0),
      status: SaleStatus.fromString(map['status']?.toString()),
      documentType: SaleDocumentType.fromString(map['documentType']?.toString()),
      documentNumber: map['documentNumber']?.toString(),
      customerNameOrBusinessName:
          map['customerNameOrBusinessName']?.toString(),
      customerPhone: map['customerPhone']?.toString(),
      customerEmail: map['customerEmail']?.toString(),
      notes: map['notes']?.toString(),
      currency: (map['currency'] ?? 'BOB').toString(),
      lines: lines,
      stockApplied: map['stockApplied'] == true,
    );
  }
}
