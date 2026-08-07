import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/damaged_item.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/work_day_provider.dart';
import '../../providers/daily_inventory_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/inventory_load_repository.dart';
import '../../providers/global_refresh_provider.dart';

class DamagedItemsScreen extends ConsumerStatefulWidget {
  const DamagedItemsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DamagedItemsScreen> createState() => _DamagedItemsScreenState();
}

class _DamagedItemsScreenState extends ConsumerState<DamagedItemsScreen> {
  final _qtyCtrl = TextEditingController();
  Map<String, dynamic>? _selectedProduct;
  List<DamagedItem> _allReturns = [];
  bool _loadingHistory = false;
  bool _isChargedToDistributor = true;
  Map<String, int> _supplierRemaining = {};

  Future<void> _loadHistory(String workDayId) async {
    setState(() => _loadingHistory = true);
    final repo = SupplierRepository();
    final data = await repo.getDamagedItemsForWorkDay(workDayId);

    // حساب المتبقي الفعلي لكل مخبز على حدة
    final invRepo = InventoryLoadRepository();
    final loads = await invRepo.getLoadsForWorkDay(workDayId);
    final txRepo = TransactionRepository();
    final allDist = await txRepo.getDistributionsByWorkDay(workDayId);
    final allRet = await txRepo.getReturnsByWorkDay(workDayId);
    final allDamaged = await repo.getDamagedItemsForWorkDay(workDayId);
    final allSuppRet = await repo.getReturnsForWorkDay(workDayId);

    final Map<String, int> remaining = {};
    for (var l in loads) {
      final key = '${l.supplierId}_${l.productId}';
      remaining[key] = (remaining[key] ?? 0) + (l.initialQuantity as num).toInt();
    }
    for (var d in allDist) {
      final key = '${d.supplierId}_${d.productId}';
      remaining[key] = (remaining[key] ?? 0) - (d.quantity as num).toInt();
    }
    for (var r in allRet) {
      final key = '${r.supplierId}_${r.productId}';
      remaining[key] = (remaining[key] ?? 0) + (r.quantity as num).toInt();
    }
    for (var d in allDamaged) {
      final key = '${d.supplierId}_${d.productId}';
      remaining[key] = (remaining[key] ?? 0) - (d.quantity as num).toInt();
    }
    for (var sr in allSuppRet) {
      final key = '${sr.supplierId}_${sr.productId}';
      remaining[key] = (remaining[key] ?? 0) - (sr.quantity as num).toInt();
    }

    if (mounted) setState(() { _allReturns = data; _loadingHistory = false; _supplierRemaining = remaining; });
  }

  Future<void> _addReturn(String workDayId, String supplierId, dynamic costPriceRaw) async {
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
    final key = '${supplierId}_${_selectedProduct!['product_id']}';
    final currentRemaining = _supplierRemaining[key] ?? 0;
    if (qty > currentRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية تتجاوز المتبقي في العهدة ($currentRemaining)'), backgroundColor: AppTheme.danger));
      return;
    }
    try {
      final repo = SupplierRepository();
      await repo.insertDamagedItem(DamagedItem(
        id: '',
        workDayId: workDayId,
        productId: _selectedProduct!['product_id'] as String,
        supplierId: supplierId,
        quantity: qty,
        costPrice: costPrice,
        isChargedToDistributor: _isChargedToDistributor ? 1 : 0,
        createdAt: DateTime.now().toIso8601String(),
      ));
      _qtyCtrl.clear();
      ref.read(globalRefreshProvider.notifier).refresh();
      await _loadHistory(workDayId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل التالف بنجاح ✓'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.danger));
      }
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
        appBar: AppBar(title: const Text('تسجيل التالف / العجز'), backgroundColor: AppTheme.background),
        body: const Center(child: Text('لا يوجد يوم عمل مفتوح', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    if (_allReturns.isEmpty && !_loadingHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory(workDay.id!));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('تسجيل التالف / العجز'),
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
                TabBar(
                  isScrollable: true,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  onTap: (_) => setState(() { _selectedProduct = null; _qtyCtrl.clear(); }),
                  tabs: suppliers.map((s) => Tab(text: s.name)).toList(),
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
    final productsState = ref.watch(supplierProductsProvider(supplierId));
    
    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('لم يتم ربط أي منتجات بهذا المخبز', style: TextStyle(color: AppTheme.textSecondary)));
        }

        final selectedReturns = _selectedProduct == null
            ? <DamagedItem>[]
            : _allReturns.where((r) => r.supplierId == supplierId && r.productId == _selectedProduct!['product_id']).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر الصنف التالف / المفقود:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: products.map((p) {
                  final isSelected = _selectedProduct?['product_id'] == p['product_id'];
                  final pId = p['product_id'] as String;
                  final remaining = _supplierRemaining['${supplierId}_$pId'] ?? 0;
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
                          const SizedBox(height: 4),
                          Text('المتبقي: $remaining', style: TextStyle(color: remaining > 0 ? (isSelected ? Colors.white70 : AppTheme.danger) : (isSelected ? Colors.white54 : AppTheme.success), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('من يتحمل التكلفة؟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isChargedToDistributor = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isChargedToDistributor ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isChargedToDistributor ? AppTheme.primary : Colors.transparent),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.person, color: _isChargedToDistributor ? AppTheme.primary : AppTheme.textSecondary),
                              const SizedBox(height: 4),
                              Text('الموزع (عجز)', style: TextStyle(color: _isChargedToDistributor ? AppTheme.primary : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isChargedToDistributor = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isChargedToDistributor ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: !_isChargedToDistributor ? AppTheme.primary : Colors.transparent),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.factory, color: !_isChargedToDistributor ? AppTheme.primary : AppTheme.textSecondary),
                              const SizedBox(height: 4),
                              Text('المخبز (تالف)', style: TextStyle(color: !_isChargedToDistributor ? AppTheme.primary : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProduct == null ? 'اختر صنفاً أولاً' : 'إرجاع لـ ${_selectedProduct!['product_name']}',
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
                          onPressed: _selectedProduct == null ? null : () => _addReturn(workDayId, supplierId, _selectedProduct!['cost_price']),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), backgroundColor: AppTheme.danger, disabledBackgroundColor: AppTheme.surface),
                          child: const Icon(Icons.delete_sweep, size: 24, color: Colors.white),
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
                    Text('سجل التوالف: ${_selectedProduct!['product_name']}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loadingHistory)
                  const SizedBox.shrink()
                else if (selectedReturns.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2A2A2A))),
                    child: const Center(child: Text('لا يوجد توالف سابقة', style: TextStyle(color: AppTheme.textSecondary))),
                  )
                else
                  ...selectedReturns.map((ret) {
                    final timeStr = _formatTime(ret.createdAt);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2))),
                      child: Row(
                        children: [
                          Expanded(child: Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary))),
                          Text('${ret.quantity} حبة', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Icon(ret.isChargedToDistributor == 1 ? Icons.person : Icons.factory, color: AppTheme.textSecondary, size: 16),
                        ],
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
