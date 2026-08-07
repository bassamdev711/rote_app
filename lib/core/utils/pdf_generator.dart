import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:roti_app/models/work_day.dart';
import '../../providers/daily_inventory_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../models/supplier.dart';
import '../../models/customer.dart';
import '../../models/customer_statement_item.dart';
import 'balance_formatter.dart';

class PdfGenerator {
  // ─── Shared helpers ──────────────────────────────────────────────────────────

  static String _formatTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final h = dt.toLocal().hour.toString().padLeft(2, '0');
    final m = dt.toLocal().minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static pw.Widget _buildHeader({
    required pw.Font font,
    required pw.Font fontBold,
    required String distributorName,
    required String supplierName,
    required String date,
    required String reportTitle,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          gradient: const pw.LinearGradient(
            colors: [PdfColors.blue900, PdfColors.blue700],
          ),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(reportTitle,
                    style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
                pw.Text(date,
                    style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey300)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('الموزع: $distributorName',
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('المخبز: $supplierName',
                    style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static List<List<String>> _buildTableRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final type = row['type']?.toString() ?? '';
      final time = _formatTime(row['time']?.toString());
      final customer = row['customer_name']?.toString() ?? '';
      final product = row['product_name']?.toString() ?? '';
      final supplier = row['supplier_name']?.toString() ?? '—';

      String qty = '—';
      String value = '—';

      if (type == 'توزيع') {
        final q = row['dist_qty'];
        final p = row['price'];
        qty = (q != null && q != 0) ? q.toString() : '—';
        value = (p != null && p != 0) ? (p as num).toStringAsFixed(2) : '—';
      } else if (type == 'راجع' || type == 'راجع مخبز' || type.startsWith('تالف')) {
        final q = row['ret_qty'];
        final p = row['price'];
        qty = (q != null && q != 0) ? q.toString() : '—';
        value = (p != null && p != 0) ? (p as num).toStringAsFixed(2) : '—';
      } else if (type == 'تحصيل') {
        final col = row['col_amount'];
        qty = '—';
        value = (col != null && col != 0) ? (col as num).toStringAsFixed(2) : '—';
      }

      final productDisplay = (type == 'تحصيل' || product.isEmpty) ? '—' : product;

      return [value, qty, productDisplay, type, customer, supplier, time];
    }).toList();
  }

  static pw.Widget _buildSummaryRow(pw.Font font, pw.Font fontBold,
      double dist, double ret, double col) {
    final net = dist - ret;
    final remaining = net - col;
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _summaryItem(font, fontBold, 'إجمالي التوزيع', dist, PdfColors.blue800),
            _summaryItem(font, fontBold, 'الراجع', ret, PdfColors.orange700),
            _summaryItem(font, fontBold, 'الصافي', net, PdfColors.green800),
            _summaryItem(font, fontBold, 'التحصيل', col, PdfColors.teal700),
            _summaryItem(font, fontBold, 'المتبقي', remaining,
                remaining > 0 ? PdfColors.red700 : PdfColors.green800),
          ],
        ),
      ),
    );
  }

  static pw.Widget _summaryItem(
      pw.Font font, pw.Font fontBold, String label, double value, PdfColor color) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text(label,
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
      pw.SizedBox(height: 3),
      pw.Text('${value.toStringAsFixed(2)} ر',
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: color)),
    ]);
  }

  // ─── تقرير الموزع (كامل اليوم) ─────────────────────────────────────────────

  static Future<void> generateDistributorReport(
      WorkDay day, String distributorName) async {
    final repo = TransactionRepository();
    final details = await repo.getDetailedDayData(day.id!);
    final summary = await repo.getDaySummary(day.id!);

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final rows = _buildTableRows(details);
    final totalDist = summary['totalDistribution'] ?? 0;
    final totalRet = summary['totalReturn'] ?? 0;
    final totalCol = summary['totalCollection'] ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildHeader(
            font: font,
            fontBold: fontBold,
            distributorName: distributorName.isEmpty ? '—' : distributorName,
            supplierName: 'جميع المخابز',
            date: day.date,
            reportTitle: 'تقرير الموزع اليومي',
          ),
          pw.SizedBox(height: 16),
          _buildSummaryRow(font, fontBold, totalDist, totalRet, totalCol),
          pw.SizedBox(height: 16),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text('سجل الحركات',
                style: pw.TextStyle(font: fontBold, fontSize: 13)),
          ),
          pw.SizedBox(height: 8),
          rows.isEmpty
              ? pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text('لا توجد حركات لهذا اليوم',
                      style: pw.TextStyle(font: font, color: PdfColors.grey500)),
                )
              : pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.TableHelper.fromTextArray(
                    headers: ['القيمة', 'الكمية', 'الصنف', 'الحركة', 'العميل', 'المخبز', 'الوقت'],
                    data: rows,
                    headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9),
                    cellAlignment: pw.Alignment.centerRight,
                    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(50),
                      1: const pw.FixedColumnWidth(35),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FixedColumnWidth(45),
                      4: const pw.FlexColumnWidth(2),
                      5: const pw.FlexColumnWidth(1.5),
                      6: const pw.FixedColumnWidth(35),
                    },
                  ),
                ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'تقرير_الموزع_${day.date}.pdf',
    );
  }

  // ─── تقرير المخبز (مفلتر بالمخبز) ─────────────────────────────────────────

  static Future<void> generateSupplierReport(
      WorkDay day, Supplier supplier, String distributorName) async {
    final repo = TransactionRepository();
    final details = await repo.getDetailedDayDataBySupplier(day.id!, supplier.id!);
    final summary = await repo.getDaySummaryForSupplier(day.id!, supplier.id!);

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final rows = _buildTableRows(details).map((row) {
      // عمود المخبز هو الفهرس 5، نملأه باسم المخبز
      final updated = List<String>.from(row);
      updated[5] = supplier.name;
      return updated;
    }).toList();
    final totalDist = summary['totalDistribution'] ?? 0;
    final totalRet = summary['totalReturn'] ?? 0;
    final totalCol = summary['totalCollection'] ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildHeader(
            font: font,
            fontBold: fontBold,
            distributorName: distributorName.isEmpty ? '—' : distributorName,
            supplierName: supplier.name,
            date: day.date,
            reportTitle: 'تقرير مخبز ${supplier.name}',
          ),
          pw.SizedBox(height: 16),
          _buildSummaryRow(font, fontBold, totalDist, totalRet, totalCol),
          pw.SizedBox(height: 16),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text('سجل حركات ${supplier.name}',
                style: pw.TextStyle(font: fontBold, fontSize: 13)),
          ),
          pw.SizedBox(height: 8),
          rows.isEmpty
              ? pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text('لا توجد حركات لهذا المخبز في هذا اليوم',
                      style: pw.TextStyle(font: font, color: PdfColors.grey500)),
                )
              : pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.TableHelper.fromTextArray(
                    headers: ['القيمة', 'الكمية', 'الصنف', 'الحركة', 'العميل', 'المخبز', 'الوقت'],
                    data: rows,
                    headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9),
                    cellAlignment: pw.Alignment.centerRight,
                    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(50),
                      1: const pw.FixedColumnWidth(35),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FixedColumnWidth(45),
                      4: const pw.FlexColumnWidth(2),
                      5: const pw.FlexColumnWidth(1.5),
                      6: const pw.FixedColumnWidth(35),
                    },
                  ),
                ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'تقرير_${supplier.name}_${day.date}.pdf',
    );
  }



  static Future<void> generateCustomerStatementReport(
      Customer customer, List<CustomerStatementItem> items, String periodText, String distributorName) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    
    double totalDist = 0;
    double totalCol = 0;
    double totalRet = 0;

    final List<List<String>> rows = items.map((item) {
      String type = '';
      String product = item.productName ?? '—';
      String qty = item.quantity?.toString() ?? '—';
      
      if (item.type == 'distribution') {
        type = 'توزيع';
        totalDist += item.amount;
      } else if (item.type == 'return') {
        type = 'مرتجع';
        totalRet += item.amount;
      } else {
        type = 'تحصيل';
        totalCol += item.amount;
        product = '—';
        qty = '—';
      }

      final date = DateTime.tryParse(item.createdAt);
      final dateStr = date != null ? DateFormat('yyyy-MM-dd hh:mm a').format(date) : '';

      return [item.amount.toStringAsFixed(2), qty, product, type, dateStr];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'تاريخ الطباعة: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.blue900, PdfColors.blue700],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('كشف حركة وحسابات العميل',
                          style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // يمين: معلومات العميل
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('العميل: ${customer.name}',
                              style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.white)),
                          pw.Text('الموزع: $distributorName',
                              style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.white)),
                          if (customer.neighborhood != null && customer.neighborhood!.isNotEmpty)
                            pw.Text('المنطقة: ${customer.neighborhood}',
                                style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.white)),
                        ],
                      ),
                      // يسار: الفترة
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('الفترة: $periodText',
                              style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey300)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          _buildSummaryRow(font, fontBold, totalDist, totalRet, totalCol),
          pw.SizedBox(height: 16),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text('سجل الحركات',
                style: pw.TextStyle(font: fontBold, fontSize: 13)),
          ),
          pw.SizedBox(height: 8),
          rows.isEmpty
              ? pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text('لا توجد حركات في هذه الفترة',
                      style: pw.TextStyle(font: font, color: PdfColors.grey500)),
                )
              : pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.TableHelper.fromTextArray(
                    headers: ['القيمة', 'الكمية', 'الصنف', 'الحركة', 'التاريخ والوقت'],
                    data: rows,
                    headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    cellStyle: pw.TextStyle(font: font, fontSize: 9),
                    cellAlignment: pw.Alignment.centerRight,
                    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(60),
                      1: const pw.FixedColumnWidth(40),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FixedColumnWidth(60),
                      4: const pw.FlexColumnWidth(2),
                    },
                  ),
                ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'كشف_حساب_${customer.name}_$periodText.pdf',
    );
  }

  static Future<void> generateAllCustomersReport(
      List<Map<String, dynamic>> customersData, String filterTypeTitle, String distributorName) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();
    
    double totalAllPaid = 0;
    double totalAllRemaining = 0;

    int index = 1;
    final List<List<String>> rows = customersData.map((data) {
      Customer c = data['customer'];
      double bal = data['balance'] ?? 0.0;
      double paid = data['totalPaid'] ?? 0.0;
      
      totalAllPaid += paid;
      totalAllRemaining += bal;
      
      String status = bal > 0 ? 'مدين' : 'مسدد';
      String phoneStr = c.phone != null && c.phone!.isNotEmpty ? c.phone! : '—';

      return [
        status,
        bal.toStringAsFixed(2),
        paid.toStringAsFixed(2),
        phoneStr,
        c.name,
        (index++).toString(),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'تاريخ الطباعة: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey500),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.blue900, PdfColors.blue700],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('تقرير العملاء',
                          style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
                      pw.Text(filterTypeTitle,
                          style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey300)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('الموزع: $distributorName',
                        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.TableHelper.fromTextArray(
              headers: ['حالة الحساب', 'إجمالي المتبقي', 'إجمالي المدفوع', 'رقم الهاتف', 'اسم العميل', 'الرقم'],
              data: rows,
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FixedColumnWidth(30),
              },
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Text('عدد العملاء', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                    pw.SizedBox(height: 3),
                    pw.Text('${customersData.length}', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue800)),
                  ]),
                  _summaryItem(font, fontBold, 'إجمالي المدفوع', totalAllPaid, PdfColors.green800),
                  _summaryItem(font, fontBold, 'إجمالي المتبقي', totalAllRemaining, totalAllRemaining > 0 ? PdfColors.red700 : PdfColors.teal700),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'تقرير_العملاء.pdf',
    );
  }
}
