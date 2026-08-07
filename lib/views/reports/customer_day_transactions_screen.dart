import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/balance_formatter.dart';
import '../../repositories/transaction_repository.dart';

class CustomerDayTransactionsScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String workDayId;
  final String date;
  final double totalDist;
  final double totalRet;
  final double totalCol;
  final double dayBalance;

  const CustomerDayTransactionsScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.workDayId,
    required this.date,
    required this.totalDist,
    required this.totalRet,
    required this.totalCol,
    required this.dayBalance,
  }) : super(key: key);

  @override
  State<CustomerDayTransactionsScreen> createState() => _CustomerDayTransactionsScreenState();
}

class _CustomerDayTransactionsScreenState extends State<CustomerDayTransactionsScreen> {
  final TransactionRepository _repo = TransactionRepository();
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _repo.getCustomerDayTransactions(widget.customerId, widget.workDayId);
    if (mounted) {
      setState(() {
        _transactions = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = BalanceFormatter.format(widget.dayBalance);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.date, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        backgroundColor: AppTheme.background,
      ),
      body: Column(
        children: [
          // ملخص اليوم لهذا العميل
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  info.color.withValues(alpha: 0.15),
                  AppTheme.cardBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: info.color.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('التوزيع', widget.totalDist, AppTheme.primary, Icons.local_shipping_outlined),
                    _summaryItem('الراجع', widget.totalRet, AppTheme.warning, Icons.undo_rounded),
                    _summaryItem('التحصيل', widget.totalCol, AppTheme.success, Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      info.isZero ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      color: info.color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.isZero 
                          ? 'مسوّى بالكامل ✓'
                          : '${info.text}: ${info.amount} ريال',
                      style: TextStyle(
                        color: info.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // رأس قسم الحركات
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.list_alt_outlined, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text('سجل الحركات', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // قائمة الحركات
          Expanded(
            child: _loading
                ? const SizedBox.shrink()
                : _transactions.isEmpty
                    ? const Center(
                        child: Text('لا توجد حركات مسجلة', style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          final type = tx['type'] as String;
                          final qty = (tx['quantity'] as num?)?.toInt() ?? 0;
                          final price = (tx['price'] as num?)?.toDouble() ?? 0;
                          final productName = tx['product_name'] as String? ?? '';
                          final createdAt = tx['created_at'] as String? ?? '';

                          String timeStr = '';
                          if (createdAt.isNotEmpty) {
                            final dt = DateTime.tryParse(createdAt);
                            if (dt != null) {
                              timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            }
                          }

                          final isDistribution = type == 'توزيع';
                          final isReturn = type == 'راجع';
                          final isCollection = type == 'تحصيل';

                          Color typeColor = isDistribution
                              ? AppTheme.primary
                              : isReturn
                                  ? AppTheme.warning
                                  : AppTheme.success;

                          IconData typeIcon = isDistribution
                              ? Icons.local_shipping_outlined
                              : isReturn
                                  ? Icons.undo_rounded
                                  : Icons.payments_outlined;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(typeIcon, color: typeColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCollection
                                            ? 'تحصيل نقدي'
                                            : '$productName',
                                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if (!isCollection)
                                        Text(
                                          '$qty × ${price.toStringAsFixed(3)} ريال',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      isCollection
                                          ? '+${price.toStringAsFixed(3)} ريال'
                                          : isDistribution
                                              ? '${(qty * price).toStringAsFixed(3)} ريال'
                                              : '-${(qty * price).toStringAsFixed(3)} ريال',
                                      style: TextStyle(
                                        color: typeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '$type${timeStr.isNotEmpty ? ' • $timeStr' : ''}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(3),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
