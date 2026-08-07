import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/work_day_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/inventory_load_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../core/database/db_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/global_refresh_provider.dart';

class DayLoadDetailsScreen extends ConsumerStatefulWidget {
  final String workDayId;
  final String date;

  const DayLoadDetailsScreen({
    Key? key,
    required this.workDayId,
    required this.date,
  }) : super(key: key);

  @override
  ConsumerState<DayLoadDetailsScreen> createState() => _DayLoadDetailsScreenState();
}

class _DayLoadDetailsScreenState extends ConsumerState<DayLoadDetailsScreen> {
  // supplierID -> productID -> stats map
  Map<String, Map<String, Map<String, dynamic>>> _supplierData = {};
  Map<String, String> _supplierNames = {};
  bool _loading = true;
  Set<String> _expandedSuppliers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final invRepo = InventoryLoadRepository();
    final txRepo = TransactionRepository();
    final suppRepo = SupplierRepository();

    final loads = await invRepo.getLoadsForWorkDay(widget.workDayId);
    final allDist = await txRepo.getDistributionsByWorkDay(widget.workDayId);
    final allRet = await txRepo.getReturnsByWorkDay(widget.workDayId);
    final allDamaged = await suppRepo.getDamagedItemsForWorkDay(widget.workDayId);
    final allSuppRet = await suppRepo.getReturnsForWorkDay(widget.workDayId);

    // Fetch supplier & product names from DB
    final db = await DBHelper.instance.database;
    final supplierIds = loads.map((l) => l.supplierId).toSet().toList();
    final productIds = loads.map((l) => l.productId).toSet().toList();

    Map<String, String> names = {};
    Map<String, String> productNames = {};

    if (supplierIds.isNotEmpty) {
      final nameRows = await db.rawQuery(
          'SELECT id, name FROM suppliers WHERE id IN (${supplierIds.map((_) => '?').join(',')})',
          supplierIds);
      names = {for (var r in nameRows) r['id'] as String: r['name'] as String};
    }

    if (productIds.isNotEmpty) {
      final prodRows = await db.rawQuery(
          'SELECT id, name FROM products WHERE id IN (${productIds.map((_) => '?').join(',')})',
          productIds);
      productNames = {for (var r in prodRows) r['id'] as String: r['name'] as String};
    }

    // Build: supplierId -> productId -> stats
    final Map<String, Map<String, Map<String, dynamic>>> data = {};

    for (var l in loads) {
      final sId = l.supplierId;
      final pId = l.productId;
      data.putIfAbsent(sId, () => {});
      data[sId]!.putIfAbsent(pId, () => {
        'name': productNames[pId] ?? pId,
        'load': 0, 'dist': 0, 'ret': 0, 'damaged_dist': 0, 'damaged_bakery': 0, 'suppRet': 0,
      });
      data[sId]![pId]!['load'] = (data[sId]![pId]!['load'] as int) + (l.initialQuantity as num).toInt();
    }

    for (var d in allDist) {
      final key = data[d.supplierId]?[d.productId];
      if (key != null) key['dist'] = (key['dist'] as int) + (d.quantity as num).toInt();
    }
    for (var r in allRet) {
      final key = data[r.supplierId]?[r.productId];
      if (key != null) key['ret'] = (key['ret'] as int) + (r.quantity as num).toInt();
    }
    for (var d in allDamaged) {
      final key = data[d.supplierId]?[d.productId];
      if (key != null) {
        if (d.isChargedToDistributor == 1) {
          key['damaged_dist'] = (key['damaged_dist'] as int) + (d.quantity as num).toInt();
        } else {
          key['damaged_bakery'] = (key['damaged_bakery'] as int) + (d.quantity as num).toInt();
        }
      }
    }
    for (var sr in allSuppRet) {
      final key = data[sr.supplierId]?[sr.productId];
      if (key != null) key['suppRet'] = (key['suppRet'] as int) + (sr.quantity as num).toInt();
    }

    if (mounted) {
      setState(() {
        _supplierData = data;
        _supplierNames = names;
        _expandedSuppliers = data.keys.toSet();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalRefreshProvider, (_, __) => _loadData());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل الحمولة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('يوم: ${widget.date}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        backgroundColor: AppTheme.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _supplierData.isEmpty
              ? const Center(
                  child: Text('لا توجد حمولات مسجلة في هذا اليوم',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _supplierData.entries.map((entry) {
                    final supplierId = entry.key;
                    final products = entry.value;
                    final supplierName = _supplierNames[supplierId] ?? supplierId;
                    final isExpanded = _expandedSuppliers.contains(supplierId);

                    int totalLoad = 0, totalDist = 0, totalRet = 0, totalRemaining = 0;
                    int totalDamagedDist = 0, totalDamagedBakery = 0;
                    for (var p in products.values) {
                      final load = p['load'] as int;
                      final dist = p['dist'] as int;
                      final ret = p['ret'] as int;
                      final damagedDist = p['damaged_dist'] as int;
                      final damagedBakery = p['damaged_bakery'] as int;
                      final suppRet = p['suppRet'] as int;
                      totalLoad += load;
                      totalDist += dist;
                      totalRet += ret;
                      totalDamagedDist += damagedDist;
                      totalDamagedBakery += damagedBakery;
                      totalRemaining += (load + ret - dist - damagedDist - damagedBakery - suppRet);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          // ── Supplier Header ──
                          GestureDetector(
                            onTap: () => setState(() {
                              if (isExpanded) {
                                _expandedSuppliers.remove(supplierId);
                              } else {
                                _expandedSuppliers.add(supplierId);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(16),
                                  bottom: isExpanded ? Radius.zero : const Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.storefront_outlined, color: AppTheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(supplierName,
                                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('${products.length} صنف', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  _chip('حمولة', totalLoad, AppTheme.textPrimary),
                                  const SizedBox(width: 8),
                                  _chip('وزّع', totalDist, AppTheme.primary),
                                  const SizedBox(width: 8),
                                  _chip('متبقي', totalRemaining, totalRemaining > 0 ? AppTheme.warning : AppTheme.success),
                                  const SizedBox(width: 8),
                                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: AppTheme.textSecondary, size: 20),
                                ],
                              ),
                            ),
                          ),

                          // ── ملخص التالف ──
                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Text('تالف الموزع: $totalDamagedDist', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Container(width: 1, height: 16, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                                  Row(
                                    children: [
                                      const Icon(Icons.store_mall_directory_outlined, size: 16, color: AppTheme.danger),
                                      const SizedBox(width: 6),
                                      Text('تالف المخبز: $totalDamagedBakery', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          // ── Product Table ──
                          if (isExpanded) ...[
                            // Header row
                            Container(
                              color: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  const Expanded(flex: 3, child: Text('الصنف', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                                  _th('حمولة'),
                                  _th('توزيع'),
                                  _th('راجع'),
                                  _th('متبقي'),
                                ],
                              ),
                            ),
                            // Data rows
                            ...products.entries.toList().asMap().entries.map((mapEntry) {
                              final idx = mapEntry.key;
                              final p = mapEntry.value.value;
                              final load = p['load'] as int;
                              final dist = p['dist'] as int;
                              final ret = p['ret'] as int;
                              final damagedDist = p['damaged_dist'] as int;
                              final damagedBakery = p['damaged_bakery'] as int;
                              final suppRet = p['suppRet'] as int;
                              final remaining = load + ret - dist - damagedDist - damagedBakery - suppRet;

                              return Container(
                                color: idx.isOdd
                                    ? AppTheme.surface.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(p['name'] as String,
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                    _td(load.toString(), AppTheme.textPrimary),
                                    _td(dist.toString(), AppTheme.primary),
                                    _td(ret == 0 ? '—' : ret.toString(), AppTheme.warning),
                                    _td(remaining.toString(),
                                        remaining > 0 ? const Color(0xFFEF4444) : AppTheme.success,
                                        bold: true),
                                  ],
                                ),
                              );
                            }),

                            // Totals footer
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text('الإجمالي', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                  _td(totalLoad.toString(), AppTheme.textPrimary, bold: true),
                                  _td(totalDist.toString(), AppTheme.primary, bold: true),
                                  _td(totalRet == 0 ? '—' : totalRet.toString(), AppTheme.warning, bold: true),
                                  _td(totalRemaining.toString(),
                                      totalRemaining > 0 ? const Color(0xFFEF4444) : AppTheme.success,
                                      bold: true),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _th(String text) => Expanded(
        flex: 2,
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _td(String text, Color color, {bool bold = false}) => Expanded(
        flex: 2,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
