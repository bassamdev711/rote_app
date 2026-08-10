import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/supplier.dart';
import '../../../models/supplier_product.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../../core/utils/app_utils.dart';

// ─── Provider لجلب الأصناف المرتبطة بمخبز معين ───────────────────────────────
final _linkedProductsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, supplierId) async {
    ref.watch(globalRefreshProvider);
    final repo = ref.read(supplierRepositoryProvider);
    return repo.getProductsForSupplier(supplierId);
  },
);

class SupplierProductsScreen extends ConsumerStatefulWidget {
  final Supplier supplier;
  const SupplierProductsScreen(
      {Key? key, required this.supplier})
      : super(key: key);

  @override
  ConsumerState<SupplierProductsScreen> createState() =>
      _SupplierProductsScreenState();
}

class _SupplierProductsScreenState
    extends ConsumerState<SupplierProductsScreen> {
  /// خريطة productId → TextEditingController لسعر التكلفة
  final Map<String, TextEditingController> _controllers = {};

  /// خريطة productId → sp_id (الـ id في جدول supplier_products)، null = غير مرتبط
  final Map<String, String?> _spIds = {};

  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── تهيئة الـ controllers من بيانات قاعدة البيانات ─────────────────────
  void _initControllers(
      List<Product> allProducts, List<Map<String, dynamic>> linked) {
    if (_initialized) return;
    _initialized = true;

    // بناء خريطة سريعة: productId → بيانات الربط
    final linkedMap = {
      for (final sp in linked)
        sp['product_id'] as String: sp,
    };

    for (final p in allProducts) {
      if (p.id == null) continue;
      final pid = p.id!;
      final spData = linkedMap[pid];
      if (spData != null) {
        _spIds[pid] = spData['sp_id'] as String?;
        final price = spData['cost_price'];
        _controllers[pid] = TextEditingController(
          text: price != null
              ? (price as num).toStringAsFixed(3)
              : '',
        );
      } else {
        _spIds[pid] = null;
        _controllers[pid] = TextEditingController(text: '');
      }
    }
  }

  // ─── حفظ كل التغييرات دفعةً واحدة ───────────────────────────────────────
  Future<void> _saveAll(List<Product> allProducts) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepositoryProvider);
      int changes = 0;

      for (final p in allProducts) {
        if (p.id == null) continue;
        final pid = p.id!;
        final rawText = (_controllers[pid]?.text ?? '').trim();
        final price = AppUtils.tryParseDouble(rawText);
        final existingSpId = _spIds[pid];

        if (price != null && price >= 0 && rawText.isNotEmpty) {
          // ─ حقل ممتلئ ─
          if (existingSpId == null) {
            // ربط جديد
            await repo.insertSupplierProduct(SupplierProduct(
              supplierId: widget.supplier.id!,
              productId: pid,
              costPrice: price,
            ));
          } else {
            // تعديل سعر موجود
            await repo.updateSupplierProduct(SupplierProduct(
              id: existingSpId,
              supplierId: widget.supplier.id!,
              productId: pid,
              costPrice: price,
            ));
          }
          changes++;
        } else if (rawText.isEmpty && existingSpId != null) {
          // ─ حقل فارغ وكان مرتبطاً → حذف الربط ─
          await repo.deleteSupplierProduct(existingSpId);
          changes++;
        }
        // حقل فارغ + غير مرتبط → لا شيء
      }

      ref.read(globalRefreshProvider.notifier).refresh();
      // إعادة التهيئة عند العودة لشاشة المخبز
      setState(() {
        _initialized = false;
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changes > 0
                ? 'تم الحفظ بنجاح ($changes تغيير)'
                : 'لا توجد تغييرات'),
            backgroundColor:
                changes > 0 ? AppTheme.success : AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // نراقب globalRefresh لإعادة جلب البيانات بعد الحفظ
    ref.listen(globalRefreshProvider, (_, __) {
      setState(() => _initialized = false);
    });

    final allProductsAsync = ref.watch(productsProvider);
    final linkedAsync =
        ref.watch(_linkedProductsProvider(widget.supplier.id!));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('أصناف ${widget.supplier.name}'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: allProductsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('خطأ: $e',
                style: const TextStyle(color: AppTheme.danger))),
        data: (allProducts) => linkedAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('خطأ: $e',
                  style: const TextStyle(color: AppTheme.danger))),
          data: (linked) {
            _initControllers(allProducts, linked);

            if (allProducts.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد أصناف. أضف أصنافاً أولاً من شاشة الأصناف.',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: [
                // ─── رأس الشاشة ─────────────────────────────────────
                _buildHeader(allProducts, linked),
                // ─── قائمة الأصناف ──────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: allProducts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = allProducts[i];
                      if (p.id == null) return const SizedBox.shrink();
                      return _buildProductRow(p);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // ─── زر اعتماد الأسعار العائم ────────────────────────────────────────
      floatingActionButton: allProductsAsync.value != null
          ? FloatingActionButton.extended(
              onPressed: _saving
                  ? null
                  : () => _saveAll(allProductsAsync.value!),
              backgroundColor:
                  _saving ? AppTheme.textSecondary : AppTheme.success,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline,
                      color: Colors.white),
              label: Text(
                _saving ? 'جارٍ الحفظ...' : 'اعتماد الأسعار',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  // ─── رأس الشاشة: إحصائيات سريعة ─────────────────────────────────────────
  Widget _buildHeader(List<Product> all, List<Map<String, dynamic>> linked) {
    final linkedCount = linked.length;
    final totalCount = all.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.08),
            AppTheme.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined,
              color: AppTheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplier.name,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  '$linkedCount مرتبط من $totalCount صنف',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // مؤشر نسبة الربط
          _buildLinkIndicator(linkedCount, totalCount),
        ],
      ),
    );
  }

  Widget _buildLinkIndicator(int linked, int total) {
    if (total == 0) return const SizedBox.shrink();
    final ratio = linked / total;
    final color = ratio == 1.0
        ? AppTheme.success
        : ratio > 0.5
            ? AppTheme.warning
            : AppTheme.textSecondary;
    return Column(
      children: [
        Text(
          '${(ratio * 100).round()}%',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text('مرتبط',
            style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  // ─── صف الصنف الواحد ─────────────────────────────────────────────────────
  Widget _buildProductRow(Product p) {
    final pid = p.id!;
    final ctrl = _controllers[pid]!;
    final isLinked = _spIds[pid] != null;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final hasValue = ctrl.text.trim().isNotEmpty;
        final borderColor = hasValue
            ? AppTheme.success
            : isLinked
                ? AppTheme.danger // كان مرتبطاً وتم تفريغه
                : const Color(0xFFE2E8F0);
        final bgColor = hasValue
            ? AppTheme.success.withOpacity(0.04)
            : AppTheme.cardBackground;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // ─── مؤشر حالة الربط ────────────────────────────────
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasValue
                        ? AppTheme.success
                        : (isLinked
                            ? AppTheme.danger
                            : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 12),
                // ─── اسم الصنف ───────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      if ((p.unitName ?? '').isNotEmpty)
                        Text(
                          '${p.unitName} · ${p.itemsPerUnit ?? '-'} حبة',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // ─── حقل سعر التكلفة ─────────────────────────────────
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'السعر',
                      hintStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      suffixText: 'ر',
                      suffixStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: hasValue
                          ? AppTheme.success.withOpacity(0.06)
                          : AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
