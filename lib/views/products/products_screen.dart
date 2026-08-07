import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/product_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../core/utils/app_utils.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final suppliersState = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الأصناف')),
      body: productsState.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('لا توجد أصناف'));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('الوحدة: ${product.unitName ?? "-"} (${product.itemsPerUnit ?? "-"} حبة)'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    ref.read(productsProvider.notifier).deleteProduct(product.id!);
                  },
                ),
              );
            },
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final suppliers = suppliersState.value ?? [];
          if (suppliers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يجب إضافة مخبز أولاً من الإعدادات قبل إضافة الأصناف')),
            );
          } else {
            _showAddProductDialog(context, ref, suppliers);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref, List<Supplier> suppliers) {
    final nameController = TextEditingController();
    final costPriceController = TextEditingController();
    final sellingPriceController = TextEditingController(); // Added Selling Price
    final unitNameController = TextEditingController();
    final itemsPerUnitController = TextEditingController();
    Supplier? selectedSupplier = suppliers.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة صنف جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم الصنف (مثال: روتي)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Supplier>(
                      value: selectedSupplier,
                      decoration: const InputDecoration(labelText: 'المخبز (المورد)'),
                      items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (s) => setState(() => selectedSupplier = s),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costPriceController,
                      decoration: const InputDecoration(labelText: 'سعر التكلفة (من المخبز)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitNameController,
                      decoration: const InputDecoration(labelText: 'اسم الوحدة الكبيرة (اختياري، مثال: شدة)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemsPerUnitController,
                      decoration: const InputDecoration(labelText: 'عدد الحبات داخل الوحدة'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty && costPriceController.text.isNotEmpty && selectedSupplier != null) {
                      final newProduct = Product(
                        name: nameController.text,
                        defaultPrice: 0,
                        unitName: unitNameController.text,
                        itemsPerUnit: AppUtils.tryParseInt(itemsPerUnitController.text),
                        createdAt: DateTime.now().toIso8601String(),
                      );
                      final costPrice = AppUtils.tryParseDouble(costPriceController.text) ?? 0;
                      ref.read(productsProvider.notifier).addProductWithSupplier(newProduct, selectedSupplier!.id!, costPrice);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
