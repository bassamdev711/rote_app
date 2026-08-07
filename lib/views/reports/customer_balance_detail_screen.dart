import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/balance_formatter.dart';
import '../../repositories/transaction_repository.dart';
import 'customer_day_transactions_screen.dart';

class CustomerBalanceDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double totalBalance;

  const CustomerBalanceDetailScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.totalBalance,
  }) : super(key: key);

  @override
  State<CustomerBalanceDetailScreen> createState() => _CustomerBalanceDetailScreenState();
}

class _CustomerBalanceDetailScreenState extends State<CustomerBalanceDetailScreen> {
  final TransactionRepository _repo = TransactionRepository();
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = await _repo.getCustomerBalancePerDay(widget.customerId);
    if (mounted) {
      setState(() {
        _days = days;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.customerName),
        backgroundColor: AppTheme.background,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي الرصيد المتبقي', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Builder(builder: (context) {
                  final info = BalanceFormatter.format(widget.totalBalance);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${info.amount} ريال',
                        style: TextStyle(color: info.color, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(info.text, style: TextStyle(color: info.color, fontSize: 11)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : _days.isEmpty
              ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _days.length,
                  itemBuilder: (context, index) {
                    final day = _days[index];
                    final date = day['date'] as String;
                    final totalDist = (day['total_dist'] as num).toDouble();
                    final totalRet = (day['total_ret'] as num).toDouble();
                    final totalCol = (day['total_col'] as num).toDouble();
                    final dayBalance = (day['day_balance'] as num).toDouble();
                    final workDayId = day['work_day_id'] as String;
                    final info = BalanceFormatter.format(dayBalance);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDayTransactionsScreen(
                              customerId: widget.customerId,
                              customerName: widget.customerName,
                              workDayId: workDayId,
                              date: date,
                              totalDist: totalDist,
                              totalRet: totalRet,
                              totalCol: totalCol,
                              dayBalance: dayBalance,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: info.color.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(date, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: info.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    info.text,
                                    style: TextStyle(
                                      color: info.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Color(0xFF2A2A2A)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statItem('توزيع', totalDist, AppTheme.primary),
                                _statItem('راجع', totalRet, AppTheme.warning),
                                _statItem('تحصيل', totalCol, AppTheme.success),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('اضغط لعرض تفاصيل اليوم', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_left, size: 14, color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value.toStringAsFixed(3),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
