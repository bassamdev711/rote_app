import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/supplier.dart';
import '../../models/supplier_payment.dart';
import '../../models/work_day.dart';
import '../../providers/global_refresh_provider.dart';
import '../../repositories/supplier_payment_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/work_day_repository.dart';
import '../main/day_detail_screen.dart';
import '../../core/database/db_helper.dart';
import '../../core/utils/supplier_statement_pdf_generator.dart';

class SupplierStatementScreen extends ConsumerStatefulWidget {
  final Supplier supplier;
  const SupplierStatementScreen({Key? key, required this.supplier}) : super(key: key);

  @override
  ConsumerState<SupplierStatementScreen> createState() => _SupplierStatementScreenState();
}

class _SupplierStatementScreenState extends ConsumerState<SupplierStatementScreen> {
  final _paymentRepo = SupplierPaymentRepository();
  final _wdRepo = WorkDayRepository();
  
  List<SupplierPayment> _payments = [];
  double _currentBalance = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.supplier.currentBalance;
    _load();
  }

  Future<void> _load() async {
    final list = await _paymentRepo.getSupplierPayments(widget.supplier.id!);
    final balance = await _paymentRepo.getSupplierBalance(widget.supplier.id!);
    if (mounted) {
      setState(() {
        _payments = list;
        _currentBalance = balance;
        _loading = false;
      });
    }
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تسجيل دفعة للمخبز'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ (ريال)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    enabled: !isSubmitting,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amountController.text) ?? 0;
                          if (amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')),
                            );
                            return;
                          }
                          
                          setState(() => isSubmitting = true);
                          
                          try {
                            await _paymentRepo.addPayment(
                              supplierId: widget.supplier.id!,
                              amount: amt,
                              type: 'تسديد نقدي',
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );
                            
                            ref.read(globalRefreshProvider.notifier).refresh();
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تسجيل الدفعة بنجاح', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.success),
                              );
                            }
                          } catch (e) {
                            setState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.danger),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('حفظ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _openDayReview(String workDayId) async {
    // نجلب اليوم المالي
    final db = await DBHelper.instance.database;
    final res = await db.query('work_days', where: 'id = ?', whereArgs: [workDayId]);
    if (res.isNotEmpty) {
      final wd = WorkDay.fromMap(res.first);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DayDetailScreen(workDay: wd),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalRefreshProvider, (_, __) => _load());

    Color balanceColor;
    String balanceLabel;
    if (_currentBalance > 0) {
      balanceColor = AppTheme.success;
      balanceLabel = 'مدين: لك';
    } else if (_currentBalance < 0) {
      balanceColor = AppTheme.danger;
      balanceLabel = 'دائن: عليك';
    } else {
      balanceColor = AppTheme.textSecondary;
      balanceLabel = 'الرصيد مصفر';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('كشف حساب: ${widget.supplier.name}'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            onPressed: () async {
              await SupplierStatementPdfGenerator.generateAndOpen(
                supplierName: widget.supplier.name,
                balance: _currentBalance,
                payments: _payments,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('تسديد دفعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // بطاقة الرصيد
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: balanceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: balanceColor.withOpacity(0.3), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الرصيد التراكمي', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(balanceLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: balanceColor)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _currentBalance.abs().toStringAsFixed(2),
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: balanceColor),
                          ),
                          const SizedBox(width: 4),
                          Text('ريال', style: TextStyle(fontSize: 14, color: balanceColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('سجل الدفعات والحركات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                // السجل
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(child: Text('لا توجد حركات مسجلة', style: TextStyle(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final p = _payments[index];
                            final dt = DateTime.tryParse(p.createdAt)?.toLocal() ?? DateTime.now();
                            final dStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                            final tStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            
                            final isDebt = p.amount < 0;
                            final amountColor = isDebt ? AppTheme.danger : AppTheme.success;
                            final amountSign = isDebt ? '-' : '+';
                            final typeIcon = isDebt ? Icons.assignment_late_outlined : Icons.payments_outlined;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: AppTheme.cardBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: amountColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(typeIcon, color: amountColor, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              if (p.notes != null && p.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(p.notes!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                              ],
                                              const SizedBox(height: 4),
                                              Text('$dStr  $tStr', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$amountSign ${p.amount.abs().toStringAsFixed(2)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor),
                                        ),
                                      ],
                                    ),
                                    if (p.workDayId != null) ...[
                                      const Divider(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 36,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                          label: const Text('مراجعة اليوم المالي', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _openDayReview(p.workDayId!),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
