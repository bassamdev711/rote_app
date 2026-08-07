import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/balance_formatter.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../providers/global_refresh_provider.dart';
import '../day_load_details_screen.dart';

class DaySummaryTab extends ConsumerStatefulWidget {
  final String workDayId;
  final String date;
  const DaySummaryTab({Key? key, required this.workDayId, required this.date}) : super(key: key);

  @override
  ConsumerState<DaySummaryTab> createState() => _DaySummaryTabState();
}

class _DaySummaryTabState extends ConsumerState<DaySummaryTab>
    with AutomaticKeepAliveClientMixin {
  final _txRepo = TransactionRepository();
  Map<String, double> _summary = {};
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await _txRepo.getDaySummary(widget.workDayId);
    final products = await _txRepo.getDayProductSummary(widget.workDayId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _products = products;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(globalRefreshProvider, (_, __) => _load());
    if (_loading) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── بطاقة الإجمالي ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _statItem('التوزيع', _summary['totalDistribution'] ?? 0, AppTheme.primary, Icons.local_shipping_outlined)),
                  _vDivider(),
                  Expanded(child: _statItem('الراجع', _summary['totalReturn'] ?? 0, AppTheme.warning, Icons.keyboard_return_rounded)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _statItem('التحصيل', _summary['totalCollection'] ?? 0, AppTheme.success, Icons.payments_outlined)),
                  _vDivider(),
                  Expanded(child: Builder(builder: (_) {
                    final remaining = (_summary['remaining'] as num?)?.toDouble() ?? 0.0;
                    final info = BalanceFormatter.format(remaining);
                    return Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: info.color, size: 20),
                        const SizedBox(height: 4),
                        Text(info.text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(info.amount, style: TextStyle(color: info.color, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('ريال', style: TextStyle(color: info.color, fontSize: 10)),
                      ],
                    );
                  })),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── تفاصيل الأصناف ──
        if (_products.isNotEmpty) ...[
          const Text('تفاصيل الأصناف', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15)),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.2),
              5: FlexColumnWidth(1.2),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _headerCell('الصنف'),
                  _headerCell('توزيع'),
                  _headerCell('عميل'),
                  _headerCell('مخبز'),
                  _headerCell('تالف'),
                  _headerCell('الصافي'),
                ],
              ),
              // Rows
              ..._products.map((p) {
                final dQty = (p['dist_qty'] as num).toInt();
                final dPrice = (p['dist_price'] as num).toDouble();
                final rQty = (p['ret_qty'] as num).toInt();
                final rPrice = (p['ret_price'] as num).toDouble();
                final sretQty = (p['sret_qty'] as num?)?.toInt() ?? 0;
                final sretPrice = (p['sret_price'] as num?)?.toDouble() ?? 0.0;
                final dmgDist = (p['dmg_dist_qty'] as num?)?.toInt() ?? 0;
                final dmgBakery = (p['dmg_bakery_qty'] as num?)?.toInt() ?? 0;
                final dmgQty = dmgDist + dmgBakery;
                final net = dPrice - rPrice;
                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  children: [
                    _dataCell(p['name'] as String, bold: true),
                    _dataCell('$dQty\n${dPrice.toStringAsFixed(0)}'),
                    _dataCell('$rQty\n${rPrice.toStringAsFixed(0)}', color: AppTheme.warning),
                    _dataCell('$sretQty\n${sretPrice.toStringAsFixed(0)}', color: AppTheme.danger),
                    _dataCell('$dmgQty\n-', color: Colors.orange),
                    _dataCell('${net.toStringAsFixed(0)}', color: AppTheme.primary, bold: true),
                  ],
                );
              }).toList(),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ── زر الحمولة ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardBackground,
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
              elevation: 0,
            ),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('تفاصيل حمولة اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => DayLoadDetailsScreen(workDayId: widget.workDayId, date: widget.date),
            )),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text('ريال', style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 50, color: const Color(0xFFE2E8F0));

  static Widget _headerCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary), textAlign: TextAlign.center),
  );

  static Widget _dataCell(String text, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(text,
        style: TextStyle(fontSize: 11, color: color ?? AppTheme.textPrimary, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.center),
  );
}
