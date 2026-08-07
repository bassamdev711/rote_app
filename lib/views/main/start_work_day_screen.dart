import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/product_provider.dart';
import '../../providers/work_day_provider.dart';
import '../../models/inventory_load.dart';
import '../../core/utils/app_utils.dart';

class StartWorkDayScreen extends ConsumerStatefulWidget {
  const StartWorkDayScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StartWorkDayScreen> createState() => _StartWorkDayScreenState();
}

class _StartWorkDayScreenState extends ConsumerState<StartWorkDayScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('بدء يوم عمل جديد')),
      body: productsState.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('يرجى إضافة أصناف أولاً من الإعدادات'));
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('أدخل حمولة اليوم من المخبز', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    if (!_controllers.containsKey(product.id)) {
                      _controllers[product.id!] = TextEditingController();
                    }
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('الوحدة: ${product.unitName ?? "حبة"}'),
                      trailing: SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _controllers[product.id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'الكمية',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    List<InventoryLoad> initialLoads = [];
                    for (var product in products) {
                      final text = _controllers[product.id]?.text ?? '';
                      if (text.isNotEmpty) {
                        final qty = AppUtils.tryParseInt(text);
                        if (qty != null && qty > 0) {
                          initialLoads.add(InventoryLoad(
                            workDayId: '', // Will be set in provider
                            productId: product.id!,
                            supplierId: '', // Default or not used here
                            initialQuantity: qty,
                            costPrice: 0.0,
                            createdAt: DateTime.now().toIso8601String(),
                          ));
                        }
                      }
                    }
                    if (initialLoads.isNotEmpty) {
                      ref.read(currentWorkDayProvider.notifier).startNewDay(initialLoads);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال حمولة صنف واحد على الأقل')));
                    }
                  },
                  child: const Text('بدء اليوم', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, st) => Center(child: Text('خطأ: \$e')),
      ),
    );
  }
}
