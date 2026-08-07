import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/customer.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../providers/work_day_provider.dart';
import '../../../providers/customer_balance_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../core/utils/balance_formatter.dart';
import '../../../providers/global_refresh_provider.dart';

final _txRepoProvider = Provider((_) => TransactionRepository());

class SummaryTab extends ConsumerStatefulWidget {
  final Customer customer;
  final String? workDayId;
  const SummaryTab({Key? key, required this.customer, this.workDayId}) : super(key: key);

  @override
  ConsumerState<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<SummaryTab> {
  double _salesTotal = 0;
  double _returnsTotal = 0;
  double _collectionsTotal = 0;
  List<Map<String, dynamic>> _productSummary = [];
  bool _loading = true;

  String? get _effectiveWorkDayId => widget.workDayId ?? ref.read(currentWorkDayProvider).value?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final wdId = _effectiveWorkDayId;
    final repo = ref.read(_txRepoProvider);
    final cid = widget.customer.id!;
    final distributions = await repo.getDistributionsByCustomer(cid, workDayId: wdId);
    final returns = await repo.getReturnsByCustomer(cid, workDayId: wdId);
    final collections = await repo.getCollectionsByCustomer(cid, workDayId: wdId);

    final products = ref.read(productsProvider).value ?? [];
    
    double sales = 0, rets = 0, colls = 0;
    Map<String, Map<String, dynamic>> pSummaryMap = {};
    for (var p in products) {
      if (p.id != null) {
        pSummaryMap[p.id!] = {
          'name': p.name,
          'dist_qty': 0,
          'dist_price': 0.0,
          'ret_qty': 0,
          'ret_price': 0.0,
        };
      }
    }

    for (var d in distributions) {
      sales += (d.quantity ?? 0).toDouble() * d.price;
      if (pSummaryMap.containsKey(d.productId)) {
        pSummaryMap[d.productId]!['dist_qty'] = (pSummaryMap[d.productId]!['dist_qty'] as int) + (d.quantity ?? 0);
        pSummaryMap[d.productId]!['dist_price'] = (pSummaryMap[d.productId]!['dist_price'] as double) + ((d.quantity ?? 0) * d.price);
      }
    }
    for (var r in returns) {
      rets += (r.quantity ?? 0).toDouble() * r.price;
      if (pSummaryMap.containsKey(r.productId)) {
        pSummaryMap[r.productId]!['ret_qty'] = (pSummaryMap[r.productId]!['ret_qty'] as int) + (r.quantity ?? 0);
        pSummaryMap[r.productId]!['ret_price'] = (pSummaryMap[r.productId]!['ret_price'] as double) + ((r.quantity ?? 0) * r.price);
      }
    }
    for (var c in collections) colls += c.amount;

    final productSummaryList = pSummaryMap.values.where((p) => (p['dist_qty'] as int) > 0 || (p['ret_qty'] as int) > 0).toList();

    if (mounted) {
      setState(() {
        _salesTotal = sales;
        _returnsTotal = rets;
        _collectionsTotal = colls;
        _productSummary = productSummaryList;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalRefreshProvider, (_, __) => _loadData());
    
    final net = _salesTotal - _returnsTotal;
    final balance = net - _collectionsTotal;
    final info = BalanceFormatter.format(balance);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRow('إجمالي التوزيع', _salesTotal, AppTheme.primary, Icons.local_shipping_outlined),
                  const SizedBox(height: 10),
                  _buildRow('إجمالي الراجع', _returnsTotal, AppTheme.warning, Icons.undo_rounded),
                  const SizedBox(height: 10),
                  _buildRow('الصافي (مبيعات فعلية)', net, AppTheme.textPrimary, Icons.calculate_outlined),
                  const SizedBox(height: 10),
                  _buildRow('المحصّل', _collectionsTotal, AppTheme.success, Icons.payments_outlined),
                  const SizedBox(height: 20),

                  // Product Summary Section
                  if (_productSummary.isNotEmpty) ...[
                    const Text('تفاصيل الأصناف لهذا العميل', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    ..._productSummary.map((p) {
                      final pName = p['name'] as String;
                      final dQty = (p['dist_qty'] as int).toString();
                      final dPrice = p['dist_price'] as double;
                      final rQty = (p['ret_qty'] as int).toString();
                      final rPrice = p['ret_price'] as double;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('توزيع: $dQty  |  راجع: $rQty', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${(dPrice - rPrice).toStringAsFixed(2)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                const Text('الصافي', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],

                  // Balance
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: info.color.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        Text(
                          info.text,
                          style: TextStyle(
                            color: info.color,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${info.amount} ريال',
                          style: TextStyle(
                            color: info.color,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text('${value.toStringAsFixed(2)} ريال',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
