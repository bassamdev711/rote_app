import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/product_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../core/utils/app_utils.dart';
import '../../core/theme/app_theme.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(productsProvider);
    final suppliersState = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: productsState.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('لا توجد أصناف حالياً', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProductCard(
                  product: product,
                  onEdit: () => _showEditProductDialog(context, ref, product),
                  onDelete: () => _confirmDelete(context, ref, product),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddProductDialog(context, ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  // ─── حذف مع تأكيد ────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الصنف "${product.name}"؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(productsProvider.notifier).deleteProduct(product.id!);
    }
  }

  // ─── نموذج الإضافة ────────────────────────────────────────────────────────
  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة صنف جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الصنف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newProduct = Product(
                  name: nameController.text.trim(),
                  defaultPrice: 0,
                  createdAt: DateTime.now().toIso8601String(),
                );
                ref.read(productsProvider.notifier).addProduct(newProduct);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ─── نموذج التعديل ────────────────────────────────────────────────────────
  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final nameController = TextEditingController(text: product.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل الصنف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم الصنف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final updated = product.copyWith(
                name: name,
                updatedAt: DateTime.now().toIso8601String(),
                syncStatus: 'pending',
                unitName: null, // Clear out unit name
                itemsPerUnit: null, // Clear out items per unit
              );
              ref.read(productsProvider.notifier).updateProduct(updated);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة الصنف ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // أيقونة الصنف
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            // اسم الصنف
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
            // زر تعديل
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppTheme.primary, size: 22),
              tooltip: 'تعديل',
              onPressed: onEdit,
            ),
            // زر حذف
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.danger, size: 22),
              tooltip: 'حذف',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
