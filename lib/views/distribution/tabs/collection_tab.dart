import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/customer.dart';
import '../../../models/collection_transaction.dart';
import '../../../providers/work_day_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../providers/customer_balance_provider.dart';
import '../../../providers/daily_inventory_provider.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../../core/utils/app_utils.dart';

final _txRepoProvider = Provider((_) => TransactionRepository());

class CollectionTab extends ConsumerStatefulWidget {
  final Customer customer;
  final String? workDayId;
  final bool isClosed;
  const CollectionTab({Key? key, required this.customer, this.workDayId, this.isClosed = false}) : super(key: key);

  @override
  ConsumerState<CollectionTab> createState() => _CollectionTabState();
}

class _CollectionTabState extends ConsumerState<CollectionTab> {
  List<CollectionTransaction> _collections = [];
  bool _loading = true;

  String? get _effectiveWorkDayId => widget.workDayId ?? ref.read(currentWorkDayProvider).value?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final wdId = _effectiveWorkDayId;
    if (wdId == null) { setState(() => _loading = false); return; }
    final data = await ref.read(_txRepoProvider).getCollectionsByCustomer(widget.customer.id!, workDayId: wdId);
    if (mounted) setState(() { _collections = data; _loading = false; });
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'م' : 'ص';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  void _invalidateProviders() {
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final total = _collections.fold<double>(0, (sum, c) => sum + c.amount);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const SizedBox.shrink()
          : Column(
              children: [
                if (_collections.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي التحصيل', style: TextStyle(color: AppTheme.textSecondary)),
                        Text('${total.toStringAsFixed(2)} ريال',
                            style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                Expanded(
                  child: _collections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.payments_outlined, size: 48, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text('لا يوجد تحصيل لهذا العميل',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _collections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = _collections[i];
                            return InkWell(
                              onTap: widget.isClosed ? null : () => _showEditDialog(context, c),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.payments_outlined, color: AppTheme.success, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('دفعة نقدية', style: TextStyle(color: AppTheme.textPrimary)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(_formatTime(c.createdAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('${c.amount.toStringAsFixed(2)} ريال',
                                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    if (!widget.isClosed)
                                      const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: widget.isClosed ? null : FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة تحصيل'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final wdId = _effectiveWorkDayId;
    if (wdId == null) return;
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تسجيل تحصيل', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'المبلغ المحصّل',
                hintText: '0.00',
                prefixText: 'ريال  ',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                onPressed: () async {
                  final amount = AppUtils.tryParseDouble(amountCtrl.text) ?? 0;
                  if (amount <= 0) {
                    _showErrorDialog(ctx, 'الرجاء إدخال مبلغ صحيح أكبر من صفر');
                    return;
                  }
                  
                  try {
                    await ref.read(_txRepoProvider).insertCollection(CollectionTransaction(
                      workDayId: wdId, customerId: widget.customer.id!,
                      amount: amount, createdAt: DateTime.now().toIso8601String(),
                    ));
                    Navigator.pop(ctx);
                    _loadData();
                    _invalidateProviders();
                  } catch (e) {
                      String msg = e.toString();
                      if (msg.startsWith('Exception: ')) {
                        msg = msg.substring(11);
                      }
                      _showErrorDialog(ctx, msg);
                  }
                },
                child: const Text('تأكيد التحصيل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, CollectionTransaction coll) {
    final amountCtrl = TextEditingController(text: coll.amount.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('تعديل التحصيل', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('حذف التحصيل'),
                        content: const Text('هل أنت متأكد من حذف هذا التحصيل؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref.read(_txRepoProvider).deleteCollection(coll.id!);
                        _loadData();
                        _invalidateProviders();
                      } catch (e) {
                        if (mounted) {
                          _showErrorDialog(context, e.toString());
                        }
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22),
              decoration: const InputDecoration(
                labelText: 'المبلغ المحصّل',
                hintText: '0.00',
                prefixText: 'ريال  ',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                onPressed: () async {
                  final amount = AppUtils.tryParseDouble(amountCtrl.text) ?? 0;
                  if (amount <= 0) {
                    _showErrorDialog(ctx, 'الرجاء إدخال مبلغ صحيح أكبر من صفر');
                    return;
                  }
                  
                  try {
                    await ref.read(_txRepoProvider).updateCollection(CollectionTransaction(
                      id: coll.id, workDayId: coll.workDayId, customerId: coll.customerId,
                      amount: amount, createdAt: coll.createdAt,
                    ));
                    Navigator.pop(ctx);
                    _loadData();
                    _invalidateProviders();
                  } catch (e) {
                      String msg = e.toString();
                      if (msg.startsWith('Exception: ')) {
                        msg = msg.substring(11);
                      }
                      _showErrorDialog(ctx, msg);
                  }
                },
                child: const Text('حفظ التعديل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (alertCtx) => AlertDialog(
        title: const Text('تنبيه', style: TextStyle(color: AppTheme.warning)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(alertCtx), 
            child: const Text('حسناً')
          )
        ],
      ),
    );
  }
}
