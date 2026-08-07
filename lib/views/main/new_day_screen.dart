import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_load.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/work_day_provider.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_screen.dart';
import '../../core/utils/app_utils.dart';

class NewDayScreen extends ConsumerStatefulWidget {
  const NewDayScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NewDayScreen> createState() => _NewDayScreenState();
}

class _NewDayScreenState extends ConsumerState<NewDayScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _costPrices = {};
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: suppliersAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (suppliers) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: AppTheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.wb_sunny, color: Colors.amber, size: 32),
                            SizedBox(height: 6),
                            Text('بدء يوم عمل جديد',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('أدخل كميات الحمولة من المخابز',
                                style: TextStyle(color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (suppliers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildEmptySuppliersCard(context),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: DefaultTabController(
                      length: suppliers.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: suppliers.map((supplier) {
                                return _buildSupplierTab(supplier);
                              }).toList(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildStartButton(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplierTab(Supplier supplier) {
    final productsState = ref.watch(supplierProductsProvider(supplier.id!.toString()));
    
    return productsState.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('لم يتم ربط أي منتجات بهذا المخبز', style: TextStyle(color: AppTheme.textSecondary)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final key = '${supplier.id}_${p['product_id']}';
            _controllers.putIfAbsent(key, () => TextEditingController());
            _costPrices[key] = p['cost_price'] is String 
                ? double.tryParse(p['cost_price'].toString()) ?? 0.0 
                : (p['cost_price'] as num?)?.toDouble() ?? 0.0;
            
            return _buildProductRow(key, p['product_name'] as String, p['cost_price'].toString());
          },
        );
      },
    );
  }

  Widget _buildEmptySuppliersCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          const Text('لا توجد مخابز مضافة',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'قبل بدء يوم العمل، يجب إضافة مخبز واحد على الأقل وربط الأصناف به لتتمكن من استلام الحمولة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            icon: const Icon(Icons.settings),
            label: const Text('الذهاب للإعدادات'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(String controllerKey, String name, String costStr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.bakery_dining, color: AppTheme.textSecondary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('تكلفة الحبة: $costStr', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _controllers[controllerKey],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _startDay,
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(_isLoading ? 'جاري البدء...' : 'بدء يوم العمل',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _startDay() async {
    List<InventoryLoad> loads = [];
    
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    
    for (var key in _controllers.keys) {
      String txt = _controllers[key]?.text.trim() ?? '';
      for (int i = 0; i < arabicDigits.length; i++) {
        txt = txt.replaceAll(arabicDigits[i], englishDigits[i]);
      }
      final qty = AppUtils.tryParseInt(txt) ?? 0;
      if (qty > 0) {
        final parts = key.split('_');
        final suppId = parts[0];
        final prodId = parts[1];
        
        loads.add(InventoryLoad(
          workDayId: '', // Assigned inside the provider
          productId: prodId,
          supplierId: suppId,
          initialQuantity: qty,
          costPrice: _costPrices[key] ?? 0.0,
          createdAt: DateTime.now().toIso8601String(),
        ));
      }
    }
    
    if (loads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل كمية صنف واحد على الأقل من أي مخبز'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    await ref.read(currentWorkDayProvider.notifier).startNewDay(loads);
    if (mounted) {
      Navigator.of(context).pop(); // Go back to Home
    }
  }
}
