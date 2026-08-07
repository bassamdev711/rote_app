import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/balance_formatter.dart';
import '../../models/customer.dart';
import '../../providers/customer_statement_provider.dart';
import '../../core/utils/pdf_generator.dart';
import '../../providers/distributor_provider.dart';

class CustomerStatementScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerStatementScreen({Key? key, required this.customer}) : super(key: key);

  @override
  ConsumerState<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends ConsumerState<CustomerStatementScreen> {
  String _timeFilter = 'today'; // 'today', 'week', 'month', 'custom'
  String? _customStartDate;
  String? _customEndDate;

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.cardBackground,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStartDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _customEndDate = DateFormat('yyyy-MM-dd').format(picked.end);
        _timeFilter = 'custom';
      });
    } else if (_timeFilter == 'custom' && _customStartDate == null) {
      setState(() {
        _timeFilter = 'today';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = CustomerStatementParams(
      customerId: widget.customer.id!,
      timeFilter: _timeFilter,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
    );
    final statementAsync = ref.watch(customerStatementProvider(params));
    final distributorName = ref.watch(distributorNameProvider).value ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('كشف حساب العميل'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () async {
              try {
                final items = await ref.read(customerStatementProvider(params).future);
                if (items.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا توجد حركات للتصدير')),
                    );
                  }
                  return;
                }
                
                String periodText = '';
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (_timeFilter == 'today') periodText = 'اليوم ($today)';
                else if (_timeFilter == 'week') periodText = 'الأسبوع (حتى $today)';
                else if (_timeFilter == 'month') periodText = 'هذا الشهر (حتى $today)';
                else if (_timeFilter == 'custom') periodText = 'من $_customStartDate إلى $_customEndDate';
                
                final distributorName = ref.read(distributorNameProvider).value ?? '';
                await PdfGenerator.generateCustomerStatementReport(widget.customer, items, periodText, distributorName);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(distributorName),
          _buildFilter(),
          Expanded(
            child: statementAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('لا توجد حركات في هذه الفترة', style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                double totalDist = 0;
                double totalCol = 0;
                double totalRet = 0;

                for (var item in items) {
                  if (item.type == 'distribution') totalDist += item.amount;
                  if (item.type == 'collection') totalCol += item.amount;
                  if (item.type == 'return') totalRet += item.amount;
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          return _buildTimelineItem(item);
                        },
                      ),
                    ),
                    _buildFooter(totalDist, totalCol, totalRet),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String distributorName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Icon(Icons.person, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          Text(
            widget.customer.name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (widget.customer.neighborhood != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.customer.neighborhood!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'موزع: $distributorName',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildFilterBtn('اليوم', 'today'),
          _buildFilterBtn('الأسبوع', 'week'),
          _buildFilterBtn('الشهر', 'month'),
          _buildFilterBtn('مخصص', 'custom'),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, String value) {
    final bool isSelected = _timeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (value == 'custom') {
            _selectCustomDateRange();
          } else {
            setState(() => _timeFilter = value);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(item) {
    IconData icon;
    Color color;
    String title;
    String subtitle = '';

    if (item.type == 'distribution') {
      icon = Icons.local_shipping;
      color = AppTheme.danger;
      title = 'توزيع ${item.productName ?? ''}';
      subtitle = 'الكمية: ${item.quantity}';
    } else if (item.type == 'return') {
      icon = Icons.keyboard_return;
      color = AppTheme.warning;
      title = 'مرتجع ${item.productName ?? ''}';
      subtitle = 'الكمية: ${item.quantity}';
    } else {
      icon = Icons.attach_money;
      color = AppTheme.success;
      title = 'تحصيل نقدي';
    }

    final date = DateTime.tryParse(item.createdAt);
    final dateStr = date != null ? DateFormat('yyyy-MM-dd hh:mm a').format(date) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
                const SizedBox(height: 4),
                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${item.amount.toStringAsFixed(2)} ريال',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double dist, double col, double ret) {
    final double remaining = dist - col - ret;
    final bool hasDebt = remaining > 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي التوزيع:', style: TextStyle(color: AppTheme.textSecondary)),
                Text('${dist.toStringAsFixed(2)} ريال', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المرتجعات والتحصيل:', style: TextStyle(color: AppTheme.textSecondary)),
                Text('${(col + ret).toStringAsFixed(2)} ريال', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (context) {
                  final info = BalanceFormatter.format(remaining);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صافي المتبقي:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(info.text, style: TextStyle(color: info.color, fontSize: 12)),
                    ],
                  );
                }),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Builder(builder: (context) {
                      final info = BalanceFormatter.format(remaining);
                      return Text(
                        '${info.amount} ريال',
                        style: TextStyle(
                          color: info.color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
