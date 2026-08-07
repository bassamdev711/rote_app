import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/customer_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/customer_balance_provider.dart';
import '../../models/customer.dart';
import 'add_customer_screen.dart';
import 'customer_statement_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_generator.dart';
import 'package:intl/intl.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('العملاء'),
        backgroundColor: AppTheme.background,
        actions: [
          customersState.when(
            data: (customers) => IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.danger),
              tooltip: 'تقرير العملاء',
              onPressed: () => _showReportOptionsDialog(context, customers),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم العميل...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: customersState.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return const Center(child: Text('لا يوجد عملاء، أضف عميلاً جديداً', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)));
                }

                final filtered = customers.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('لم يتم العثور على عميل بهذا الاسم', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    return CustomerCard(customer: customer);
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showReportOptionsDialog(BuildContext context, List<Customer> customers) async {
    int selectedOption = 0; // 0: all, 1: debt, 2: paid
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text('تقرير العملاء'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('جميع العملاء'),
                    value: 0,
                    groupValue: selectedOption,
                    onChanged: (val) => setStateSB(() => selectedOption = val!),
                  ),
                  RadioListTile<int>(
                    title: const Text('العملاء الذين عليهم مديونية'),
                    value: 1,
                    groupValue: selectedOption,
                    onChanged: (val) => setStateSB(() => selectedOption = val!),
                  ),
                  RadioListTile<int>(
                    title: const Text('العملاء المسددون بالكامل'),
                    value: 2,
                    groupValue: selectedOption,
                    onChanged: (val) => setStateSB(() => selectedOption = val!),
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
                    Navigator.pop(ctx);
                    await _generateReport(context, customers, selectedOption);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('إنشاء'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateReport(BuildContext context, List<Customer> allCustomers, int option) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<Map<String, dynamic>> customersData = [];
      for (var c in allCustomers) {
        final summary = await ref.read(customerBalanceProvider(c.id!).future);
        customersData.add({
          'customer': c,
          'balance': summary.balance,
          'totalPaid': summary.totalPaid,
        });
      }

      if (option == 1) { // debt
        customersData = customersData.where((d) => (d['balance'] as double) > 0).toList();
      } else if (option == 2) { // paid
        customersData = customersData.where((d) => (d['balance'] as double) <= 0).toList();
      }

      if (context.mounted) Navigator.pop(context); // close loading

      if (customersData.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد عملاء يطابقون الفلتر المختار')));
        }
        return;
      }

      String title = 'جميع العملاء';
      if (option == 1) title = 'العملاء الذين عليهم مديونية';
      if (option == 2) title = 'العملاء المسددون بالكامل';

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      title = '$title (حتى $today)';

      final distributorName = ref.read(distributorNameProvider).value ?? '';
      await PdfGenerator.generateAllCustomersReport(customersData, title, distributorName);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف عميل'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذا العميل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              ref.read(customersProvider.notifier).deleteCustomer(id);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class CustomerCard extends ConsumerWidget {
  final Customer customer;

  const CustomerCard({Key? key, required this.customer}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(customerBalanceProvider(customer.id!.toString()));

    return summaryAsync.when(
      data: (summary) {
        final double balance = summary.balance;
        final int quantity = summary.quantity ?? 0;
        
        final bool hasDebt = balance > 0;
        final bool isOwed = balance < 0;
        
        // Define colors based on balance state
        Color cardColor = AppTheme.cardBackground;
        Color borderColor = const Color(0xFFE2E8F0);
        
        if (hasDebt) {
          cardColor = const Color(0xFFFEF2F2);
          borderColor = AppTheme.danger.withOpacity(0.3);
        } else if (isOwed) {
          cardColor = const Color(0xFFEFF6FF);
          borderColor = AppTheme.primary.withOpacity(0.3);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerStatementScreen(customer: customer),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        child: const Icon(Icons.person, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customer.neighborhood != null && customer.neighborhood!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                customer.neighborhood!,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddCustomerScreen(customer: customer)));
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('حذف العميل'),
                              content: Text('هل أنت متأكد أنك تريد حذف العميل "${customer.name}"؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                  onPressed: () async {
                                    try {
                                      await ref.read(customersProvider.notifier).deleteCustomer(customer.id!);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceAll('Exception: ', '')),
                                            backgroundColor: AppTheme.danger,
                                          )
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('حذف', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn(
                        label: 'الكمية معه',
                        value: quantity.toString(),
                        color: AppTheme.textPrimary,
                      ),
                      if (hasDebt) ...[
                        _buildInfoColumn(
                          label: 'الباقي عليه',
                          value: '${balance.toStringAsFixed(2)} ريال',
                          color: AppTheme.danger,
                        ),
                      ] else if (isOwed) ...[
                        _buildInfoColumn(
                          label: 'الباقي له',
                          value: '${balance.abs().toStringAsFixed(2)} ريال',
                          color: AppTheme.primary,
                        ),
                      ] else ...[
                        _buildInfoColumn(
                          label: 'الرصيد',
                          value: 'مصفر',
                          color: AppTheme.success,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 80),
      error: (e, st) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildInfoColumn({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


