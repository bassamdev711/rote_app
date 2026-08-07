import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/work_day_provider.dart';
import '../../providers/daily_inventory_provider.dart';
import '../customers/customers_screen.dart';
import '../products/products_screen.dart';
import '../distribution/distribution_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../../sync/sync_service.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/broadcast_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/global_refresh_provider.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workDayState = ref.watch(currentWorkDayProvider);
    final inventoryState = ref.watch(dailyInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('روتي مان - الرئيسية'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('القائمة الرئيسية', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('إدارة العملاء'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('إدارة الأصناف'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
              },
            ),
          ],
        ),
      ),
      body: workDayState.when(
        data: (workDay) {
          return Column(
            children: [
              // الهيدر المخصص - القسم العلوي (يجمع الأزرار وحالة اليوم لمنع التداخل)
              Container(
                margin: const EdgeInsets.all(12.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // الصف الأول: الأزرار
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.cloud_sync, color: Colors.blue),
                            label: const Text('مزامنة سحابية', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade900,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => const SyncDialog(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text('الإعدادات', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // مسافة كافية بين القسمين لمنع التداخل
                    // الصف الثاني: إشعار حالة اليوم
                    if (workDay == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠️ اليوم مغلق - لا يوجد يوم مفتوح حالياً',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.today, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'اليوم مفتوح: ${workDay.date}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // باقي محتوى الصفحة
              Expanded(
                child: workDay == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          const Icon(Icons.calendar_today, size: 100, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'يرجى فتح يوم جديد للبدء بالعمل',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const Spacer(),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('المخزون الحالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(),
                              inventoryState.when(
                                data: (inv) {
                                  if (inv.isEmpty) {
                                    return const Text('لا توجد أصناف في المخزون');
                                  }
                                  return Column(
                                    children: inv.map((e) => Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.productName),
                                        Text('المتبقي: ${e.remaining}',
                                            style: TextStyle(
                                              color: e.remaining > 0 ? Colors.red : Colors.green,
                                              fontWeight: FontWeight.bold,
                                            )),
                                      ],
                                    )).toList(),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (e, st) => Text('خطأ: $e'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          children: [
                            _buildActionCard(context, Icons.local_shipping, 'توزيع', Colors.orange, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributionScreen()));
                            }),
                            _buildActionCard(context, Icons.bar_chart, 'الإحصائيات', Colors.purple, () {
                              // TODO: Navigate to Stats
                            }),
                            _buildActionCard(context, Icons.picture_as_pdf, 'التقارير', Colors.green, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                            }),
                            _buildActionCard(context, Icons.lock_clock, 'إغلاق اليوم', Colors.red, () {
                              _tryCloseDay(context, ref, workDay.id!, inventoryState);
                            }),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void _tryCloseDay(BuildContext context, WidgetRef ref, String dayId, AsyncValue inventoryState) {
    final inventories = inventoryState.value;
    if (inventories == null) return;

    // Check if any product has remaining quantity > 0
    final remaining = (inventories as List).where((inv) => inv.remaining > 0).toList();

    if (remaining.isNotEmpty) {
      // BLOCK: show which products still have remaining
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('لا يمكن إغلاق اليوم'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لا يزال هناك مخزون لم يُحسب. يجب تسجيل الراجع أو التوزيع لكل الكميات أولاً:',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              ...remaining.map((inv) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.orange, size: 8),
                    const SizedBox(width: 8),
                    Text('${inv.productName}: متبقي ${inv.remaining} حبة',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              )).toList(),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت، سأعالجها'),
            ),
          ],
        ),
      );
      return;
    }

    // ALL CLEAR: show confirmation
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق اليوم'),
        content: const Text('✅ كل المخزون تمت معالجته.\nهل أنت متأكد من إغلاق اليوم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(currentWorkDayProvider.notifier).closeDay(dayId);
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد الإغلاق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class SyncDialog extends ConsumerStatefulWidget {
  const SyncDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<SyncDialog> {
  final SyncService _syncService = SyncService();
  String _status = 'جاري الإعداد...';
  bool _isSyncing = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    await _syncService.syncData(
      onProgress: (msg) {
        if (mounted) {
          setState(() {
            _status = msg;
            if (msg.startsWith('خطأ')) {
              _hasError = true;
            }
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isSyncing = false;
        if (!_hasError) {
          _status = 'تمت المزامنة بنجاح!';
          ref.invalidate(currentWorkDayProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(broadcastProvider);
          ref.invalidate(distributorNameProvider);
          ref.read(globalRefreshProvider.notifier).refresh();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isSyncing ? Icons.sync : (_hasError ? Icons.error_outline : Icons.check_circle_outline),
            color: _isSyncing ? Colors.blue : (_hasError ? Colors.red : Colors.green),
          ),
          const SizedBox(width: 10),
          const Text('المزامنة السحابية'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSyncing) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        ],
      ),
      actions: [
        if (!_isSyncing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
      ],
    );
  }
}
