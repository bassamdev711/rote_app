import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/supplier_payment.dart';

class SupplierStatementPdfGenerator {
  static Future<void> generateAndOpen({
    required String supplierName,
    required double balance,
    required List<SupplierPayment> payments,
  }) async {
    final pdf = pw.Document();

    final ttf = await PdfGoogleFonts.cairoRegular();
    final ttfBold = await PdfGoogleFonts.cairoBold();

    final date = DateTime.now();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    String balanceLabel;
    PdfColor balanceColor;
    if (balance > 0) {
      balanceLabel = 'مدين: لك';
      balanceColor = PdfColors.green700;
    } else if (balance < 0) {
      balanceLabel = 'دائن: عليك';
      balanceColor = PdfColors.red700;
    } else {
      balanceLabel = 'الرصيد مصفر';
      balanceColor = PdfColors.grey700;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('كشف حساب مخبز', style: pw.TextStyle(font: ttfBold, fontSize: 20, color: PdfColors.white)),
                      pw.Text(dateStr, style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.white)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('المخبز: $supplierName', style: pw.TextStyle(font: ttf, fontSize: 14, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Balance Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: balanceColor, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('الرصيد التراكمي', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Text(balanceLabel, style: pw.TextStyle(font: ttfBold, fontSize: 14, color: balanceColor)),
                    ],
                  ),
                  pw.Text(
                    '${balance.abs().toStringAsFixed(2)} ريال',
                    style: pw.TextStyle(font: ttfBold, fontSize: 24, color: balanceColor),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            pw.Text('سجل الحركات والدفعات', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
            pw.SizedBox(height: 8),

            if (payments.isEmpty)
              pw.Center(child: pw.Text('لا توجد حركات مسجلة', style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey600)))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(font: ttfBold, fontSize: 10),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                },
                headers: ['المبلغ (ريال)', 'النوع', 'التاريخ والوقت', 'ملاحظات'],
                data: payments.map((p) {
                  final dt = DateTime.tryParse(p.createdAt)?.toLocal() ?? DateTime.now();
                  final dStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                  final tStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  final amountSign = p.amount < 0 ? '-' : '+';
                  
                  return [
                    '$amountSign${p.amount.abs().toStringAsFixed(2)}',
                    p.type,
                    '$dStr $tStr',
                    p.notes ?? '-',
                  ];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'statement_${supplierName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
