import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/customer.dart';
import '../../../models/product.dart';
import '../../../models/distribution.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/work_day_provider.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../repositories/customer_repository.dart';
import '../../../models/customer_price.dart';
import '../../../providers/daily_inventory_provider.dart';
import '../../../providers/distributor_provider.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../../repositories/supplier_repository.dart';
import '../../../repositories/inventory_load_repository.dart';
import '../../../core/utils/app_utils.dart';

final _txRepoProvider = Provider((_) => TransactionRepository());

// ─────────────────────────────────────────────────────────────────────────────
// Helper: loads supplier names from DB given a list of supplier IDs
// ─────────────────────────────────────────────────────────────────────────────
Future<Map<String, String>> fetchSupplierNamesByIds(List<String> ids) async {
  if (ids.isEmpty) return {};
  final db = await DBHelper.instance.database;
  final placeholder = ids.map((_) => '?').join(',');
  final rows = await db.rawQuery('SELECT id, name FROM suppliers WHERE id IN ($placeholder)', ids);
  return {for (final r in rows) r['id'] as String: r['name'] as String};
}

// ─────────────────────────────────────────────────────────────────────────────
// DistributionTab
// ─────────────────────────────────────────────────────────────────────────────
class DistributionTab extends ConsumerStatefulWidget {
  final Customer customer;
  final String? workDayId;
  final bool isClosed;
  const DistributionTab({Key? key, required this.customer, this.workDayId, this.isClosed = false}) : super(key: key);

  @override
  ConsumerState<DistributionTab> createState() => _DistributionTabState();
}

class _DistributionTabState extends ConsumerState<DistributionTab> {
  List<Distribution> _distributions = [];
  List<CustomerPrice> _customerPrices = [];
  Map<String, String> _productNames = {};
  bool _loading = true;

  String? get _effectiveWorkDayId => widget.workDayId ?? ref.read(currentWorkDayProvider).value?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final wdId = _effectiveWorkDayId;
    if (wdId == null) { setState(() => _loading = false); return; }
    final txRepo = ref.read(_txRepoProvider);
    final custRepo = CustomerRepository();
    final data = await txRepo.getDistributionsByCustomer(widget.customer.id!, workDayId: wdId);
    final prices = await custRepo.getCustomerPrices(widget.customer.id!);
    final ps = await ref.read(productsProvider.future);
    final Map<String, String> names = {};
    for (var p in ps) { if (p.id != null) names[p.id!] = p.name; }
    if (mounted) setState(() { _distributions = data; _customerPrices = prices; _productNames = names; _loading = false; });
  }

  void _invalidateProviders() {
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'م' : 'ص';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workDayId == null) ref.watch(dailyInventoryProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const SizedBox.shrink()
          : _distributions.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.local_shipping_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('لا يوجد توزيع لهذا العميل', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _distributions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = _distributions[i];
                    final productName = _productNames[d.productId] ?? 'صنف #${d.productId}';
                    return InkWell(
                      onTap: widget.isClosed ? null : () => _showDistributionForm(context, existingDist: d),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.local_shipping, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Expanded(child: Text(productName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))),
                            ]),
                            const SizedBox(height: 4),
                            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                              Text('الكمية: ${d.quantity}  |  السعر: ${d.price.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(_formatTime(d.createdAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ]),
                            ]),
                          ])),
                          Text('${((d.quantity ?? 0) * d.price).toStringAsFixed(2)} ريال',
                              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (!widget.isClosed) const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: widget.isClosed ? null : FloatingActionButton.extended(
        onPressed: () => _showDistributionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('توزيع جديد'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showDistributionForm(BuildContext context, {Distribution? existingDist}) async {
    final wdId = _effectiveWorkDayId;
    if (wdId == null) return;

    final invRepo = ref.read(inventoryLoadRepositoryProvider);
    final loads = await invRepo.getLoadsForWorkDay(wdId);

    if (loads.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حمولة لهذا اليوم. قم بتحميل البضاعة أولاً.')));
      return;
    }

    final products = await ref.read(productsProvider.future);

    // Fetch all transactions to calculate actual remaining inventory per supplier
    final txRepo = ref.read(_txRepoProvider);
    final suppRepo = SupplierRepository();
    final allDistributions = await txRepo.getDistributionsByWorkDay(wdId);
    final allReturns = await txRepo.getReturnsByWorkDay(wdId);
    final allDamaged = await suppRepo.getDamagedItemsForWorkDay(wdId);
    final allSuppReturns = await suppRepo.getReturnsForWorkDay(wdId);
    
    Map<String, int> supplierRemaining = {};
    for (var l in loads) {
      final key = "${l.supplierId}_${l.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) + (l.initialQuantity as num).toInt();
    }
    for (var d in allDistributions) {
      final key = "${d.supplierId}_${d.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) - (d.quantity as num).toInt();
    }
    for (var r in allReturns) {
      final key = "${r.supplierId}_${r.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) + (r.quantity as num).toInt();
    }
    for (var d in allDamaged) {
      final key = "${d.supplierId}_${d.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) - (d.quantity as num).toInt();
    }
    for (var sr in allSuppReturns) {
      final key = "${sr.supplierId}_${sr.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) - (sr.quantity as num).toInt();
    }
    
    if (existingDist != null) {
      final key = "${existingDist.supplierId}_${existingDist.productId}";
      supplierRemaining[key] = (supplierRemaining[key] ?? 0) + (existingDist.quantity as num).toInt();
    }

    // Unique supplier IDs from loads
    final supplierIds = loads.map((l) => l.supplierId).toSet().toList();
    final supplierNames = await fetchSupplierNamesByIds(supplierIds);

    final isEdit = existingDist != null;

    // Default supplier
    String selectedSupplierId = (isEdit &&
        existingDist.supplierId.isNotEmpty &&
        existingDist.supplierId != 'unknown' &&
        supplierIds.contains(existingDist.supplierId))
        ? existingDist.supplierId
        : supplierIds.first;

    Product? selected;
    final qtyCtrl = TextEditingController(text: isEdit ? existingDist.quantity.toString() : '');
    final priceCtrl = TextEditingController();

    double _getPriceForProduct(Product p) {
      final cp = _customerPrices.where((c) => c.productId == p.id).firstOrNull;
      return cp?.customPrice ?? p.defaultPrice;
    }

    // Pre-select product for edit
    if (isEdit) {
      final suppLoads = loads.where((l) => l.supplierId == selectedSupplierId).toList();
      final pIds = suppLoads.map((l) => l.productId).toSet();
      final suppProducts = products.where((p) => p.id != null && pIds.contains(p.id)).toList();
      selected = suppProducts.where((p) => p.id == existingDist.productId).firstOrNull ?? suppProducts.firstOrNull;
      priceCtrl.text = existingDist.price.toString();
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final suppLoads = loads.where((l) => l.supplierId == selectedSupplierId).toList();
          final pIds = suppLoads.map((l) => l.productId).toSet();
          final suppProducts = products.where((p) => p.id != null && pIds.contains(p.id)).toList();

          // Reset selected product if it's not in the new supplier's products
          if (selected != null && !pIds.contains(selected!.id)) {
            selected = suppProducts.firstOrNull;
            if (selected != null && !isEdit) {
              priceCtrl.text = _getPriceForProduct(selected!).toStringAsFixed(3);
            }
          }
          if (selected == null && suppProducts.isNotEmpty && !isEdit) {
            selected = suppProducts.first;
            priceCtrl.text = _getPriceForProduct(selected!).toStringAsFixed(3);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Expanded(child: Text(isEdit ? 'تعديل التوزيع' : 'توزيع جديد',
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('حذف التوزيع'),
                            content: const Text('هل أنت متأكد من حذف هذا التوزيع؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await ref.read(_txRepoProvider).deleteDistribution(existingDist.id!);
                            _loadData(); _invalidateProviders();
                          } catch (e) {
                            if (mounted) _showErrorDialog(context, e.toString());
                          }
                        }
                      },
                    ),
                ]),
                const SizedBox(height: 14),

                // ── Supplier Tabs ─────────────────────────────────────
                if (supplierIds.length > 1) ...[
                  const Text('المخبز', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: supplierIds.map((sId) {
                        final isActive = selectedSupplierId == sId;
                        return GestureDetector(
                          onTap: () => setS(() { selectedSupplierId = sId; selected = null; }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? AppTheme.primary : const Color(0xFF3A3A3A),
                                width: isActive ? 2 : 1,
                              ),
                              boxShadow: isActive
                                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                                  : [],
                            ),
                            child: Text(
                              supplierNames[sId] ?? sId,
                              style: TextStyle(
                                color: isActive ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (supplierIds.length == 1) ...[
                  // Single supplier — just show a label
                  Row(children: [
                    const Icon(Icons.storefront_outlined, size: 15, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text('المخبز: ${supplierNames[supplierIds.first] ?? supplierIds.first}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ]),
                  const SizedBox(height: 16),
                ],

                // ── Products ──────────────────────────────────────────
                const Text('اختر الصنف', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                suppProducts.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
                        child: const Text('لا توجد أصناف لهذا المخبز في حمولة اليوم',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      )
                    : Wrap(
                        spacing: 8, runSpacing: 8,
                        children: suppProducts.map((p) {
                          final isSelected = selected?.id == p.id;
                          final supplierLoad = supplierRemaining["${selectedSupplierId}_${p.id}"] ?? 0;
                          return GestureDetector(
                            onTap: () => setS(() {
                              selected = p;
                              if (isEdit && p.id == existingDist!.productId && existingDist.supplierId == selectedSupplierId) {
                                priceCtrl.text = existingDist.price.toString();
                              } else {
                                priceCtrl.text = _getPriceForProduct(p).toStringAsFixed(3);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary : AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primary : const Color(0xFF2A2A2A),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 5, offset: const Offset(0, 2))]
                                    : [],
                              ),
                              child: Text(
                                '${p.name} · المتبقي: $supplierLoad',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _field(qtyCtrl, 'الكمية', '0', TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _priceDisplay(priceCtrl.text)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selected == null) {
                        _showErrorDialog(ctx, 'الرجاء اختيار صنف');
                        return;
                      }
                      final qty = AppUtils.tryParseInt(qtyCtrl.text) ?? 0;
                      final price = AppUtils.tryParseDouble(priceCtrl.text) ?? 0;
                      if (qty <= 0) {
                        _showErrorDialog(ctx, 'الرجاء إدخال كمية صحيحة أكبر من صفر');
                        return;
                      }

                      try {
                        if (isEdit) {
                          await ref.read(_txRepoProvider).updateDistribution(Distribution(
                            id: existingDist.id,
                            workDayId: existingDist.workDayId,
                            customerId: existingDist.customerId,
                            productId: selected!.id!,
                            supplierId: selectedSupplierId,
                            quantity: qty,
                            price: price,
                            createdAt: existingDist.createdAt,
                          ));
                        } else {
                          await ref.read(_txRepoProvider).insertDistribution(Distribution(
                            workDayId: wdId,
                            customerId: widget.customer.id!,
                            productId: selected!.id!,
                            supplierId: selectedSupplierId,
                            quantity: qty,
                            price: price,
                            createdAt: DateTime.now().toIso8601String(),
                          ));
                        }
                        Navigator.pop(ctx);
                        _loadData(); _invalidateProviders();
                      } catch (e) {
                        String msg = e.toString();
                        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
                        _showErrorDialog(ctx, msg);
                      }
                    },
                    child: Text(isEdit ? 'حفظ التعديل' : 'حفظ التوزيع'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (alertCtx) => AlertDialog(
        title: const Text('تنبيه', style: TextStyle(color: AppTheme.warning)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(alertCtx), child: const Text('حسناً'))],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, TextInputType type, {bool readOnly = false}) {
    return TextField(
      controller: ctrl, keyboardType: type, readOnly: readOnly,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        filled: readOnly, fillColor: readOnly ? AppTheme.surface : null,
      ),
    );
  }

  Widget _priceDisplay(String price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('السعر', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Text('$price ريال',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
