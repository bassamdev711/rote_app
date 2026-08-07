import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/work_day.dart';
import '../../repositories/work_day_repository.dart';
import '../../providers/work_day_provider.dart';
import 'pdf_report_dialog.dart';
import 'tabs/day_summary_tab.dart';
import 'tabs/day_customers_tab.dart';
import 'tabs/day_profit_tab.dart';

class DayDetailScreen extends ConsumerWidget {
  final WorkDay workDay;
  const DayDetailScreen({Key? key, required this.workDay}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('يوم: ${workDay.date}'),
          backgroundColor: AppTheme.background,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'PDF',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => PdfReportDialog(workDay: workDay),
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'إجمالي'),
              Tab(icon: Icon(Icons.people_outline, size: 18), text: 'العملاء'),
              Tab(icon: Icon(Icons.attach_money_rounded, size: 18), text: 'الأرباح'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DaySummaryTab(workDayId: workDay.id!, date: workDay.date),
            DayCustomersTab(workDay: workDay),
            DayProfitTab(workDayId: workDay.id!),
          ],
        ),
      ),
    );
  }

  void _confirmClose(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إغلاق اليوم'),
        content: const Text('هل أنت متأكد من إغلاق هذا اليوم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await WorkDayRepository().closeWorkDay(workDay.id!);
              ref.invalidate(currentWorkDayProvider);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
