import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/work_day.dart';
import '../../repositories/work_day_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/utils/balance_formatter.dart';
import '../../providers/global_refresh_provider.dart';
import 'day_detail_screen.dart';
import 'pdf_report_dialog.dart';

class DaysReviewScreen extends ConsumerStatefulWidget {
  const DaysReviewScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DaysReviewScreen> createState() => _DaysReviewScreenState();
}

class _DaysReviewScreenState extends ConsumerState<DaysReviewScreen> {
  final WorkDayRepository _workDayRepo = WorkDayRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  List<WorkDay> _closedDays = [];
  Map<String, Map<String, double>> _summaries = {};
  bool _loading = true;
  DateTimeRange? _filterRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = await _workDayRepo.getAllClosedDays();
    // Also include the currently open day if exists
    final db2 = WorkDayRepository();
    final activeDay = await db2.getActiveWorkDay();
    final allDays = [
      if (activeDay != null) activeDay,
      ...days,
    ];
    final Map<String, Map<String, double>> summaries = {};
    for (var d in allDays) {
      if (d.id != null) {
        summaries[d.id!] = await _txRepo.getDaySummary(d.id!);
      }
    }
    if (mounted) {
      setState(() {
        _closedDays = allDays;
        _summaries = summaries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalRefreshProvider, (_, __) => _loadData());

    List<WorkDay> filteredDays = _closedDays;
    if (_filterRange != null) {
      filteredDays = _closedDays.where((day) {
        try {
          final dt = DateTime.parse(day.date);
          final start = _filterRange!.start;
          final end = _filterRange!.end;
          final dateOnly = DateTime(dt.year, dt.month, dt.day);
          final startOnly = DateTime(start.year, start.month, start.day);
          final endOnly = DateTime(end.year, end.month, end.day);
          return (dateOnly.isAtSameMomentAs(startOnly) || dateOnly.isAfter(startOnly)) &&
                 (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly));
        } catch (e) {
          return true;
        }
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مراجعة الأيام'),
            if (_filterRange != null)
              Text(
                'من ${_filterRange!.start.toString().substring(0, 10)} إلى ${_filterRange!.end.toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary),
              ),
          ],
        ),
        backgroundColor: AppTheme.background,
        actions: [
          if (_filterRange != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined, color: AppTheme.danger, size: 22),
              tooltip: 'إلغاء الفلتر',
              onPressed: () => setState(() => _filterRange = null),
            ),
          IconButton(
            icon: Icon(Icons.date_range, color: _filterRange != null ? AppTheme.primary : AppTheme.textPrimary),
            tooltip: 'تصفية بالتاريخ',
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _filterRange,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primary,
                        onPrimary: Colors.white,
                        onSurface: AppTheme.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null) setState(() => _filterRange = range);
            },
          ),
        ],
      ),
      body: _loading
          ? const SizedBox.shrink()
          : filteredDays.isEmpty
              ? Center(
                  child: Text(
                    _filterRange != null ? 'لا توجد أيام في هذه الفترة' : 'لا توجد أيام مغلقة حتى الآن',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDays.length,
                  itemBuilder: (context, index) {
                    final day = filteredDays[index];
                    final summary = _summaries[day.id];
                    if (summary == null) return const SizedBox();

                    final remaining = summary['remaining'] ?? 0;
                    final info = BalanceFormatter.format(remaining);
                    final isOpen = !day.isClosed;

                    final color = isOpen
                        ? AppTheme.primary
                        : info.color;
                    final icon = isOpen
                        ? Icons.lock_open_rounded
                        : (remaining <= 0)
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded;

                    return Card(
                      color: AppTheme.cardBackground,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color.withOpacity(0.6), width: 2),
                      ),
                      elevation: 3,
                      shadowColor: color.withOpacity(0.2),
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DayDetailScreen(workDay: day),
                          ));
                          _loadData(); // Refresh after returning
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(icon, color: color, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'يوم: ${day.date}',
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (isOpen) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('مفتوح', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      InkWell(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            isScrollControlled: true,
                                            builder: (_) => PdfReportDialog(workDay: day),
                                          );
                                        },
                                        child: const Icon(Icons.picture_as_pdf, color: AppTheme.danger, size: 20),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Color(0xFF2A2A2A), height: 1),
                              const SizedBox(height: 12),
                              if (summary != null)
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _infoCol('صافي التوزيع', summary['totalDistribution']! - summary['totalReturn']!, valueColor: AppTheme.primary),
                                        _infoCol('التحصيل', summary['totalCollection']!, valueColor: AppTheme.success),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _infoCol('الراجع', summary['totalSupplierReturn'] ?? 0, valueColor: AppTheme.warning),
                                        _infoCol(info.text, double.parse(info.amount), valueColor: info.color),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoCol(String title, double value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title, 
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${value.toStringAsFixed(2)} ريال',
              style: TextStyle(color: valueColor ?? AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
