import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/quote.dart';
import '../domain/quote_line.dart';

class QuotePdf {
  static Future<Uint8List> build({
    required Quote quote,
    required List<QuoteLine> lines,
    required double totalBob,
  }) async {
    final doc = pw.Document();

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        build: (context) => [
          pw.Text(
            'COTIZACIÓN #${quote.sequence}-${quote.year}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Fecha: $dateStr', style: pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Text(
            'Cliente: ${(quote.customerName ?? '').trim().isEmpty ? '(Sin nombre)' : quote.customerName!.trim()}',
            style: pw.TextStyle(fontSize: 11.5),
          ),
          if ((quote.customerPhone ?? '').trim().isNotEmpty)
            pw.Text('Tel: ${quote.customerPhone!.trim()}',
                style: pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),

          pw.TableHelper.fromTextArray(
            headers: const ['Ítem', 'Cant.', 'P. Unit (Bs)', 'Subtotal (Bs)'],
            data: lines.map((l) {
              final qtyStr = (l.qty == l.qty.roundToDouble())
                  ? l.qty.toStringAsFixed(0)
                  : l.qty.toStringAsFixed(2);
              return [
                l.nameSnapshot,
                qtyStr,
                l.unitPriceBobSnapshot.toStringAsFixed(2),
                l.lineTotalBob.toStringAsFixed(2),
              ];
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            headerStyle: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 10.5),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),

          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL: Bs ${totalBob.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),

          if ((quote.notes ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Notas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(quote.notes!.trim()),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
