import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../providers/global_refresh_provider.dart';

class DayProfitTab extends ConsumerStatefulWidget {
  final String workDayId;
  const DayProfitTab({Key? key, required this.workDayId}) : super(key: key);

  @override
  ConsumerState<DayProfitTab> createState() => _DayProfitTabState();
}

class _DayProfitTabState extends ConsumerState<DayProfitTab>
    with AutomaticKeepAliveClientMixin {
  final _txRepo = TransactionRepository();
  List<Map<String, dynamic>> _supplierProfits = [];
  double _totalProfit = 0;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _txRepo.getDayProfitBySupplierFIFO(widget.workDayId);
    double total = 0;
    for (var s in data) total += (s['total_profit'] != null ? (s['total_profit'] is String ? double.tryParse(s['total_profit'].toString()) ?? 0.0 : (s['total_profit'] as num).toDouble()) : 0.0);
    if (mounted) {
      setState(() {
        _supplierProfits = data;
        _totalProfit = total;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(globalRefreshProvider, (_, __) => _load());
    if (_loading) return const SizedBox.shrink();

    if (_supplierProfits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 56, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('لا توجد بيانات أرباح لهذا اليوم',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── إجمالي الربح ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _totalProfit >= 0
                  ? [AppTheme.success.withValues(alpha: 0.15), AppTheme.success.withValues(alpha: 0.05)]
                  : [AppTheme.danger.withValues(alpha: 0.15), AppTheme.danger.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (_totalProfit >= 0 ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _totalProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: _totalProfit >= 0 ? AppTheme.success : AppTheme.danger,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text('إجمالي صافي الربح',
                  style: TextStyle(
                      color: _totalProfit >= 0 ? AppTheme.success : AppTheme.danger,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${_totalProfit.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _totalProfit >= 0 ? AppTheme.success : AppTheme.danger)),
              const SizedBox(height: 4),
              Text('حساب FIFO لكل مخبز',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── تفصيل لكل مخبز ──
        ..._supplierProfits.map((supplier) {
          final sName = supplier['supplier_name'] as String;
          final sProfit = supplier['total_profit'] != null ? (supplier['total_profit'] is String ? double.tryParse(supplier['total_profit'].toString()) ?? 0.0 : (supplier['total_profit'] as num).toDouble()) : 0.0;
          final sRevenue = supplier['total_revenue'] != null ? (supplier['total_revenue'] is String ? double.tryParse(supplier['total_revenue'].toString()) ?? 0.0 : (supplier['total_revenue'] as num).toDouble()) : 0.0;
          final sCost = supplier['total_cost'] != null ? (supplier['total_cost'] is String ? double.tryParse(supplier['total_cost'].toString()) ?? 0.0 : (supplier['total_cost'] as num).toDouble()) : 0.0;
          final products = supplier['products'] as List<Map<String, dynamic>>;
          final isPos = sProfit >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isPos ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // رأس المخبز
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isPos ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (isPos ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.store_rounded, size: 16,
                            color: isPos ? AppTheme.success : AppTheme.danger),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(sName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                fontSize: 14)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${sProfit.toStringAsFixed(2)} ريال',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isPos ? AppTheme.success : AppTheme.danger)),
                          Text('تكلفة: ${sCost.toStringAsFixed(1)} | توزيع: ${sRevenue.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),

                // تفاصيل الأصناف
                ...products.map((p) {
                  final pName = p['product_name'] as String;
                  final allocQty = (p['allocated_qty'] != null ? (p['allocated_qty'] is String ? (double.tryParse(p['allocated_qty'].toString()) ?? 0.0) : (p['allocated_qty'] as num).toDouble()) : 0.0).toInt();
                  final sellPrice = p['avg_sell_price'] != null ? (p['avg_sell_price'] is String ? double.tryParse(p['avg_sell_price'].toString()) ?? 0.0 : (p['avg_sell_price'] as num).toDouble()) : 0.0;
                  final costPrice = p['cost_price'] != null ? (p['cost_price'] is String ? double.tryParse(p['cost_price'].toString()) ?? 0.0 : (p['cost_price'] as num).toDouble()) : 0.0;
                  final pProfit = p['profit'] != null ? (p['profit'] is String ? double.tryParse(p['profit'].toString()) ?? 0.0 : (p['profit'] as num).toDouble()) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                'توزيع: $allocQty حبة  ·  تكلفة: ${costPrice.toStringAsFixed(2)}  ·  بيع: ${sellPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${pProfit.toStringAsFixed(2)} ر',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: pProfit >= 0 ? AppTheme.success : AppTheme.danger)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
