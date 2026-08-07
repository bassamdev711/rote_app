import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/customer.dart';
import '../../models/customer_price.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/global_refresh_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({Key? key, this.customer}) : super(key: key);

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _neighborhoodCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;
  
  final Map<String, TextEditingController> _priceControllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _neighborhoodCtrl = TextEditingController(text: widget.customer?.neighborhood ?? '');
    _phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
    _notesCtrl = TextEditingController(text: widget.customer?.notes ?? '');
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final products = await ref.read(productsProvider.future);
    final repo = ref.read(customerRepositoryProvider);
    
    List<CustomerPrice> customPrices = [];
    if (widget.customer != null) {
      customPrices = await repo.getCustomerPrices(widget.customer!.id!);
    }

    for (var product in products) {
      final cp = customPrices.where((e) => e.productId == product.id).firstOrNull;
      _priceControllers[product.id!] = TextEditingController(
        text: cp?.customPrice.toString() ?? product.defaultPrice.toString(),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    for (var ctrl in _priceControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final customer = Customer(
        id: widget.customer?.id,
        name: _nameCtrl.text.trim(),
        neighborhood: _neighborhoodCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        createdAt: widget.customer?.createdAt ?? DateTime.now().toIso8601String(),
        lastSyncedAt: widget.customer?.lastSyncedAt,
        syncStatus: 'pending',
        isDeleted: widget.customer?.isDeleted ?? false,
      );

      final repo = ref.read(customerRepositoryProvider);
      
      String customerId;
      if (customer.id == null) {
        customerId = await repo.insert(customer);
      } else {
        await repo.update(customer);
        customerId = customer.id!;
      }

      List<CustomerPrice> prices = [];
      for (var entry in _priceControllers.entries) {
        final productId = entry.key;
        final price = AppUtils.tryParseDouble(entry.value.text) ?? 0.0;
        prices.add(CustomerPrice(
          customerId: customerId,
          productId: productId.toString(),
          customPrice: price,
        ));
      }
      
      await repo.saveCustomerPrices(customerId, prices);
      ref.read(globalRefreshProvider.notifier).refresh();
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.customer == null ? 'إضافة عميل جديد' : 'تعديل العميل'),
        backgroundColor: AppTheme.background,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTextField(_nameCtrl, 'اسم العميل *', Icons.person, true),
                const SizedBox(height: 12),
                _buildTextField(_neighborhoodCtrl, 'الحي', Icons.location_on, false),
                const SizedBox(height: 12),
                _buildTextField(_phoneCtrl, 'رقم الهاتف', Icons.phone, false, TextInputType.phone),
                const SizedBox(height: 12),
                _buildTextField(_notesCtrl, 'ملاحظات', Icons.note, false),
                const SizedBox(height: 24),
                const Text('تخصيص الأسعار', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...ref.read(productsProvider).maybeWhen(
                  data: (products) => products.map((product) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(product.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          ),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _priceControllers[product.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                prefixText: 'ريال ',
                                filled: true,
                                fillColor: AppTheme.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  orElse: () => [const SizedBox.shrink()],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isRequired, [TextInputType? type]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: isRequired ? (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
