import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/balance_formatter.dart';
import '../../models/supplier.dart';
import '../../providers/global_refresh_provider.dart';
import '../../repositories/supplier_repository.dart';
import 'supplier_statement_screen.dart';

class SupplierAccountsScreen extends ConsumerStatefulWidget {
  const SupplierAccountsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SupplierAccountsScreen> createState() => _SupplierAccountsScreenState();
}

class _SupplierAccountsScreenState extends ConsumerState<SupplierAccountsScreen> {
  final _repo = SupplierRepository();
  List<Supplier> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAllSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalRefreshProvider, (_, __) => _load());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('حسابات المخابز'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('لا يوجد مخابز مسجلة', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _suppliers[index];
                    final balance = supplier.currentBalance;
                    
                    // رصيد موجب = لك عند المخبز (أخضر)
                    // رصيد سالب = عليك للمخبز (أحمر)
                    Color color;
                    String label;
                    if (balance > 0) {
                      color = AppTheme.success;
                      label = 'مدين: لك';
                    } else if (balance < 0) {
                      color = AppTheme.danger;
                      label = 'دائن: عليك';
                    } else {
                      color = AppTheme.textSecondary;
                      label = 'الرصيد مصفر';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => SupplierStatementScreen(supplier: supplier),
                          ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.store_mall_directory_rounded, color: color, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      supplier.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    balance.abs().toStringAsFixed(2),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    'ريال',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
