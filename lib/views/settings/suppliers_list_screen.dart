import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../../models/supplier.dart';
import '../../../providers/supplier_provider.dart';
import 'supplier_products_screen.dart';

class SuppliersListScreen extends ConsumerWidget {
  const SuppliersListScreen({Key? key}) : super(key: key);

  void _showSupplierDialog(BuildContext context, WidgetRef ref, {Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(supplier == null ? 'إضافة مخبز جديد' : 'تعديل المخبز', style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'اسم المخبز', labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
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
              if (nameCtrl.text.trim().isEmpty) return;
              final repo = ref.read(supplierRepositoryProvider);
              if (supplier == null) {
                await repo.insertSupplier(Supplier(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  createdAt: DateTime.now().toIso8601String(),
                ));
              } else {
                await repo.updateSupplier(supplier.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                ));
              }
              ref.read(globalRefreshProvider.notifier).refresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Supplier supplier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المخبز'),
        content: Text('هل أنت متأكد أنك تريد حذف "${supplier.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              try {
                final repo = ref.read(supplierRepositoryProvider);
                await repo.deleteSupplier(supplier.id!);
                ref.read(globalRefreshProvider.notifier).refresh();
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersState = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('إدارة المخابز'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSupplierDialog(context, ref),
          )
        ],
      ),
      body: suppliersState.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(
              child: Text('لا توجد مخابز مضافة', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            itemCount: suppliers.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) {
              final supplier = suppliers[i];
              return Card(
                color: AppTheme.cardBackground,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2))),
                child: ListTile(
                  title: Text(supplier.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: supplier.phone != null && supplier.phone!.isNotEmpty 
                      ? Text(supplier.phone!, style: const TextStyle(color: AppTheme.textSecondary)) 
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => _showSupplierDialog(context, ref, supplier: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                        onPressed: () => _confirmDelete(context, ref, supplier),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: AppTheme.primary, size: 16),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SupplierProductsScreen(supplier: supplier),
                    ));
                  },
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
