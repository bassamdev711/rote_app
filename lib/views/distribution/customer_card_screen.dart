import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/customer.dart';
import 'tabs/distribution_tab.dart';
import 'tabs/return_tab.dart';
import 'tabs/collection_tab.dart';
import 'tabs/summary_tab.dart';

class CustomerCardScreen extends ConsumerWidget {
  final Customer customer;
  final String? workDayId;
  final bool isClosed;
  const CustomerCardScreen({Key? key, required this.customer, this.workDayId, this.isClosed = false}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              if (customer.neighborhood != null && customer.neighborhood!.isNotEmpty)
                Text(customer.neighborhood!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          bottom: TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: const Color(0xFFE2E8F0),
            tabs: const [
              Tab(text: 'توزيع', icon: Icon(Icons.local_shipping_outlined, size: 18)),
              Tab(text: 'راجع', icon: Icon(Icons.undo_rounded, size: 18)),
              Tab(text: 'تحصيل', icon: Icon(Icons.payments_outlined, size: 18)),
              Tab(text: 'ملخص', icon: Icon(Icons.bar_chart_rounded, size: 18)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DistributionTab(customer: customer, workDayId: workDayId, isClosed: isClosed),
            ReturnTab(customer: customer, workDayId: workDayId, isClosed: isClosed),
            CollectionTab(customer: customer, workDayId: workDayId, isClosed: isClosed),
            SummaryTab(customer: customer, workDayId: workDayId),
          ],
        ),
      ),
    );
  }
}
