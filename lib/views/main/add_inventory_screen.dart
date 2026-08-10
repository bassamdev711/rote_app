import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_load.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/work_day_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/global_refresh_provider.dart';

class AddInventoryScreen extends ConsumerStatefulWidget {
  const AddInventoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends ConsumerState<AddInventoryScreen> {
  final _qtyCtrl = TextEditingController();
  Map<String, dynamic>? _selectedProduct;
  List<Map<String, dynamic>> _allLoads = [];
  bool _loadingHistory = false;

  Future<void> _loadHistory(String workDayId) async {
    setState(() => _loadingHistory = true);
    final repo = ref.read(inventoryLoadRepositoryProvider);
    final data = await repo.getLoadsWithProductName(workDayId);
    if (mounted) setState(() { _allLoads = data; _loadingHistory = false; });
  }

  // ─── تعديل كمية سجل حمولة ──────────────────────────────────────────────────
  Future<void> _showEditLoadDialog(Map<String, dynamic> load, String workDayId) async {
    final oldQty = load['initial_quantity'] is String
        ? int.tryParse(load['initial_quantity'].toString()) ?? 0
        : (load['initial_quantity'] as num?)?.toInt() ?? 0;
    final qtyCtrl = TextEditingController(text: oldQty.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الكمية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية الحالية: $oldQty',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية الجديدة'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'لا يمكن تخفيض الكمية إلى أقل مما تم توزيعه فعلاً',
                style: TextStyle(color: AppTheme.primary, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعديل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newQty = AppUtils.tryParseInt(qtyCtrl.text.trim()) ?? 0;
    if (newQty <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال كمية أكبر من صفر'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }
    if (newQty == oldQty) return; // لا تغيير

    try {
      final repo = ref.read(inventoryLoadRepositoryProvider);
      final updatedLoad = InventoryLoad(
        id: load['id'] as String?,
        workDayId: load['work_day_id'] as String,
        productId: load['product_id'] as String,
        supplierId: load['supplier_id'] as String,
        initialQuantity: newQty,
        costPrice: (load['cost_price'] as num?)?.toDouble() ?? 0.0,
        createdAt: load['created_at'] as String,
      );
      await repo.update(updatedLoad);
      ref.read(globalRefreshProvider.notifier).refresh();
      await _loadHistory(workDayId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تعديل الكمية من $oldQty إلى $newQty ✓'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) msg = msg.substring(11);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ لا يمكن التعديل: $msg'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ─── حذف سجل حمولة ───────────────────────────────────────────────────────
  Future<void> _deleteLoad(Map<String, dynamic> load, String workDayId) async {
    final qty = load['initial_quantity'] is String
        ? int.tryParse(load['initial_quantity'].toString()) ?? 0
        : (load['initial_quantity'] as num?)?.toInt() ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سجل الحمولة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد حذف هذا السجل ($qty حبة)؟',
                style: const TextStyle(color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'لا يمكن الحذف إذا كانت الكمية الكلية بعد الحذف\nأقل مما تم توزيعه فعلاً',
                style: TextStyle(color: AppTheme.danger, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(inventoryLoadRepositoryProvider);
      await repo.delete(load['id'] as String);
      ref.read(globalRefreshProvider.notifier).refresh();
      await _loadHistory(workDayId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السجل ✓'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) msg = msg.substring(11);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ لا يمكن الحذف: $msg'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _addLoad(String workDayId, String supplierId, dynamic costPriceRaw) async {
    double costPrice = (costPriceRaw as num?)?.toDouble() ?? 0.0;
    String qtyText = _qtyCtrl.text.trim();
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    for (int i = 0; i < arabicDigits.length; i++) {
      qtyText = qtyText.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    final qty = AppUtils.tryParseInt(qtyText) ?? 0;
    if (qty <= 0 || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صنفاً وأدخل كمية صحيحة')));
      return;
    }
    final repo = ref.read(inventoryLoadRepositoryProvider);
    await repo.insert(InventoryLoad(
      workDayId: workDayId,
      productId: _selectedProduct!['product_id'] as String,
      supplierId: supplierId,
      initialQuantity: qty,
      costPrice: costPrice,
      createdAt: DateTime.now().toIso8601String(),
    ));
    _qtyCtrl.clear();
    ref.read(globalRefreshProvider.notifier).refresh();
    await _loadHistory(workDayId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة ${qty} للحمولة ✓'), backgroundColor: AppTheme.success));
    }
  }

  String _formatTime(String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final workDay = ref.watch(currentWorkDayProvider).value;
    final suppliersState = ref.watch(suppliersProvider);

    if (workDay == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('إضافة حمولة'), backgroundColor: AppTheme.background),
        body: const Center(child: Text('لا يوجد يوم عمل مفتوح', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    if (_allLoads.isEmpty && !_loadingHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory(workDay.id!));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('إضافة حمولة للموزع'),
        backgroundColor: AppTheme.background,
      ),
      body: suppliersState.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(child: Text('لا توجد مخابز مضافة.\nيرجى إضافة مخابز من الإعدادات.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)));
          }
          return DefaultTabController(
            length: suppliers.length,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: TabBar(
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    indicator: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.primary,
                    dividerColor: Colors.transparent,
                    onTap: (_) => setState(() { _selectedProduct = null; _qtyCtrl.clear(); }),
                    tabs: suppliers.map((s) => Tab(
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primary, width: 1.5),
                        ),
                        child: Center(
                          child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: suppliers.map((supplier) {
                      return _buildSupplierTab(supplier.id!, workDay.id!);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Widget _buildSupplierTab(String supplierId, String workDayId) {
    final productsState = ref.watch(supplierProductsProvider(supplierId.toString()));
    
    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('لم يتم ربط أي منتجات بهذا المخبز', style: TextStyle(color: AppTheme.textSecondary)));
        }

        final Map<String, int> productTotals = {};
        for (final load in _allLoads.where((l) => l['supplier_id'] == supplierId)) {
          final pid = load['product_id'] as String;
          final qty = load['initial_quantity'] != null 
              ? (load['initial_quantity'] is String 
                  ? int.tryParse(load['initial_quantity']) ?? 0 
                  : (load['initial_quantity'] as num).toInt())
              : 0;
          productTotals[pid] = (productTotals[pid] ?? 0) + qty;
        }

        final selectedLoads = _selectedProduct == null
            ? <Map<String, dynamic>>[]
            : _allLoads.where((l) => l['supplier_id'] == supplierId && l['product_id'] == _selectedProduct!['product_id']).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر الصنف', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: products.map((p) {
                  final isSelected = _selectedProduct?['product_id'] == p['product_id'];
                  final total = productTotals[p['product_id']] ?? 0;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedProduct = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : const Color(0xFF2A2A2A),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(p['product_name'] as String, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          if (total > 0) ...[
                            const SizedBox(height: 4),
                            Text('الإجمالي: $total', style: TextStyle(color: isSelected ? Colors.white70 : AppTheme.success, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProduct == null ? 'اختر صنفاً أولاً' : 'إضافة لـ ${_selectedProduct!['product_name']} (التكلفة: ${_selectedProduct!['cost_price']})',
                      style: TextStyle(color: _selectedProduct == null ? AppTheme.textSecondary : AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            enabled: _selectedProduct != null,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'الكمية',
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _selectedProduct == null ? null : () => _addLoad(workDayId, supplierId, _selectedProduct!['cost_price']),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), backgroundColor: AppTheme.primary, disabledBackgroundColor: AppTheme.surface),
                          child: const Icon(Icons.add, size: 24, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedProduct != null) ...[
                Row(
                  children: [
                    const Icon(Icons.history, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text('سجل التحميل: ${_selectedProduct!['product_name']}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loadingHistory)
                  const SizedBox.shrink()
                else if (selectedLoads.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
                    child: const Center(child: Text('لا يوجد سجل', style: TextStyle(color: AppTheme.textSecondary))),
                  )
                else
                  ...selectedLoads.map((load) {
                    final qty = load['initial_quantity'] is String
                        ? int.tryParse(load['initial_quantity'].toString()) ?? 0
                        : (load['initial_quantity'] as num?)?.toInt() ?? 0;
                    final timeStr = _formatTime(load['created_at'] as String? ?? '');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // الوقت
                            Text(timeStr,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 13)),
                            const Spacer(),
                            // الكمية
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$qty حبة',
                                style: const TextStyle(
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // زر التعديل
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppTheme.primary, size: 19),
                              tooltip: 'تعديل الكمية',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () =>
                                  _showEditLoadDialog(load, workDayId),
                            ),
                            // زر الحذف
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.danger, size: 19),
                              tooltip: 'حذف السجل',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () => _deleteLoad(load, workDayId),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}
