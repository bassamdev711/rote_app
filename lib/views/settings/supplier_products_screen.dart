import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/supplier.dart';
import '../../../models/supplier_product.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../core/utils/app_utils.dart';

class SupplierProductsScreen extends ConsumerStatefulWidget {
  final Supplier supplier;
  const SupplierProductsScreen({Key? key, required this.supplier}) : super(key: key);

  @override
  ConsumerState<SupplierProductsScreen> createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends ConsumerState<SupplierProductsScreen> {
  void _showAddProductDialog(List<Map<String, dynamic>> existingProducts) {
    final allProducts = ref.read(productsProvider).value ?? [];
    // Filter out products already linked
    final linkedProductIds = existingProducts.map((e) => e['product_id'] as String).toSet();
    final availableProducts = allProducts.where((p) => !linkedProductIds.contains(p.id)).toList();

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ربط جميع المنتجات المتاحة بهذا المخبز')));
      return;
    }

    String? selectedProductId = availableProducts.first.id;
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBackground,
              title: const Text('ربط منتج بالمخبز', style: TextStyle(color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    dropdownColor: AppTheme.cardBackground,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: availableProducts.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, style: const TextStyle(color: AppTheme.textPrimary)),
                    )).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedProductId = val);
                    },
                    decoration: const InputDecoration(labelText: 'المنتج', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'سعر التكلفة (الشراء)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedProductId == null) return;
                    String priceText = priceCtrl.text.trim();
                    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
                    const englishDigits = '0123456789';
                    for (int i = 0; i < arabicDigits.length; i++) {
                      priceText = priceText.replaceAll(arabicDigits[i], englishDigits[i]);
                    }
                    final price = AppUtils.tryParseDouble(priceText);
                    if (price == null || price < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال سعر صحيح')));
                      return;
                    }

                    try {
                      final repo = ref.read(supplierRepositoryProvider);
                      await repo.insertSupplierProduct(SupplierProduct(
                        supplierId: widget.supplier.id!,
                        productId: selectedProductId!,
                        costPrice: price,
                      ));
                      
                      ref.read(globalRefreshProvider.notifier).refresh();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('ربط', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(supplierProductsProvider(widget.supplier.id!.toString()));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('منتجات ${widget.supplier.name}'),
        backgroundColor: AppTheme.background,
      ),
      floatingActionButton: productsState.value != null ? FloatingActionButton(
        onPressed: () => _showAddProductDialog(productsState.value!),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ) : null,
      body: productsState.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('لا توجد منتجات مربوطة بهذا المخبز', style: TextStyle(color: AppTheme.textSecondary)));
          }
          return ListView.builder(
            itemCount: products.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) {
              final sp = products[i];
              return Card(
                color: AppTheme.cardBackground,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(sp['product_name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text('سعر التكلفة: ${sp['cost_price']}', style: const TextStyle(color: AppTheme.success)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      final repo = ref.read(supplierRepositoryProvider);
                      await repo.deleteSupplierProduct(sp['sp_id'] as String);
                      ref.read(globalRefreshProvider.notifier).refresh();
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => Center(child: Text('خطأ: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
