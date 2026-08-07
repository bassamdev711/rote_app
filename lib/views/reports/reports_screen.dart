import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/work_day_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../core/utils/balance_formatter.dart';
import 'customer_balance_detail_screen.dart';
import '../main/tabs/day_profit_tab.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionRepository _repo = TransactionRepository();

  List<Map<String, dynamic>> _customersWithBalance = [];
  List<Map<String, dynamic>> _daySummary = [];
  List<Map<String, dynamic>> _supplierProfits = [];
  bool _loadingBalance = true;
  bool _loadingDaySummary = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBalanceData();
    _tabController.addListener(() {
      if (_tabController.index == 1 && _loadingDaySummary) {
        _loadDaySummary();
      }
    });
  }

  Future<void> _loadBalanceData() async {
    final data = await _repo.getAllCustomersWithBalance();
    if (mounted) {
      setState(() {
        _customersWithBalance = data;
        _loadingBalance = false;
      });
    }
  }

  Future<void> _loadDaySummary() async {
    final workDay = ref.read(currentWorkDayProvider).value;
    if (workDay == null) {
      if (mounted) setState(() => _loadingDaySummary = false);
      return;
    }
    final data = await _repo.getDaySummaryPerCustomer(workDay.id!);
    final profits = await _repo.getDayProfitBySupplierFIFO(workDay.id!);
    if (mounted) {
      setState(() {
        _daySummary = data;
        _supplierProfits = profits;
        _loadingDaySummary = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workDayAsync = ref.watch(currentWorkDayProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: AppTheme.background,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _loadingBalance ? 'التحصيل' : 'التحصيل (${_customersWithBalance.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.today_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('ملخص اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('الأرباح', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCollectionsTab(),
          _buildDaySummaryTab(workDayAsync),
          workDayAsync.value != null ? DayProfitTab(workDayId: workDayAsync.value!.id!) : const Center(child: Text('لا يوجد يوم مفتوح')),
        ],
      ),
    );
  }

  Widget _buildCollectionsTab() {
    if (_loadingBalance) {
      return const SizedBox.shrink();
    }
    if (_customersWithBalance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            const Text('ممتاز! لا توجد ديون متبقية', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('جميع العملاء سووا حساباتهم', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    final totalDebts = _customersWithBalance.fold<double>(
      0, (s, c) => s + (c['balance'] as num).toDouble(),
    );

    return RefreshIndicator(
      onRefresh: _loadBalanceData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي الديون:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalDebts.toStringAsFixed(2)} ريال',
                      style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('العملاء المدينين', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${_customersWithBalance.length}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ..._customersWithBalance.map((c) {
            final balance = (c['balance'] as num).toDouble();
            final info = BalanceFormatter.format(balance);
            final name = c['name'] as String;
            final neighborhood = c['neighborhood'] as String? ?? '';
            final id = c['id'] as String;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerBalanceDetailScreen(
                      customerId: id,
                      customerName: name,
                      totalBalance: balance,
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
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0] : '؟',
                          style: TextStyle(color: info.color, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          if (neighborhood.isNotEmpty)
                            Text(neighborhood, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${info.amount} ريال',
                          style: TextStyle(color: info.color, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(info.text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDaySummaryTab(AsyncValue<dynamic> workDayAsync) {
    final workDay = workDayAsync.value;

    if (workDayAsync.isLoading) {
      return const SizedBox.shrink();
    }

    if (workDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('لا يوجد يوم مفتوح', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('ابدأ يوم عمل جديد لعرض الملخص', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_loadingDaySummary) {
      _loadDaySummary();
      return const SizedBox.shrink();
    }

    if (_daySummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('لم تُسجَّل أي حركات اليوم بعد', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    final totalCol = _daySummary.fold<double>(0, (s, c) => s + (c['total_col'] as num).toDouble());
    final totalRemaining = _daySummary.fold<double>(0, (s, c) => s + (c['remaining'] as num).toDouble());

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppTheme.cardBackground,
            child: const TabBar(
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'الملخص العام'),
                Tab(text: 'العملاء'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFinancialSubTab(workDay.date, totalCol, totalRemaining),
                _buildCustomersSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSubTab(String date, double totalCol, double totalRemaining) {
    return RefreshIndicator(
      onRefresh: _loadDaySummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cash and Credit Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('صندوق اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCol('التحصيل النقدي', totalCol, AppTheme.success),
                    Builder(builder: (context) {
                      final info = BalanceFormatter.format(totalRemaining);
                      return _statCol('المتبقي (آجل)', double.parse(info.amount), info.color);
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Owed to Bakeries Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store_outlined, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    const Text('المطلوب للمخابز', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const Divider(height: 24),
                ..._supplierProfits.map((supplier) {
                  final sName = supplier['supplier_name'] as String;
                  final sCost = supplier['total_cost'] != null ? (supplier['total_cost'] is String ? double.tryParse(supplier['total_cost'].toString()) ?? 0.0 : (supplier['total_cost'] as num).toDouble()) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(sName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        Text('${sCost.toStringAsFixed(1)} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersSubTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _daySummary.length,
      itemBuilder: (context, index) {
        final c = _daySummary[index];
        final name = c['name'] as String;
        final neighborhood = c['neighborhood'] as String? ?? '';
        final dist = (c['total_dist'] as num).toDouble();
        final ret = (c['total_ret'] as num).toDouble();
        final col = (c['total_col'] as num).toDouble();
        final remaining = (c['remaining'] as num).toDouble();
        final info = BalanceFormatter.format(remaining);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: info.color.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (neighborhood.isNotEmpty)
                        Text(neighborhood, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                        fontSize: 12,
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
                  _statCol('توزيع', dist, AppTheme.primary),
                  _statCol('راجع', ret, AppTheme.warning),
                  _statCol('تحصيل', col, AppTheme.success),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCol(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
