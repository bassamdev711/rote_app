import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/work_day_provider.dart';
import '../../providers/daily_inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/broadcast_provider.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/auth_guard.dart';
import '../distribution/distribution_screen.dart';
import 'sync_dialog.dart';
import '../auth/login_screen.dart';

import 'new_day_screen.dart';
import 'add_inventory_screen.dart';
import 'days_review_screen.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workDayAsync = ref.watch(currentWorkDayProvider);
    final inventoryAsync = ref.watch(dailyInventoryProvider);
    final customersAsync = ref.watch(customersProvider);
    final distributorName = ref.watch(distributorNameProvider).value ?? '';
    final broadcastAsync = ref.watch(broadcastProvider);

    return workDayAsync.when(
      loading: () => const Scaffold(body: SizedBox.shrink()),
      error: (e, _) => Scaffold(body: Center(child: Text('خطأ: $e'))),
      data: (workDay) {
        final hasActiveDay = workDay != null;
        final dateToShow = hasActiveDay ? workDay.date : DateTime.now().toIso8601String();
        final arabicDate = _formatDateArabic(dateToShow);
        final customerCount = customersAsync.when(
          data: (c) => c.length,
          loading: () => 0,
          error: (_, __) => 0,
        );

        final hasBroadcast = broadcastAsync.value != null && broadcastAsync.value!.isNotEmpty;
        final double appBarHeight = hasBroadcast ? 275.0 : 190.0;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              // ── App Bar ───────────────────────────────────────
              SliverAppBar(
                expandedHeight: appBarHeight,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                    tooltip: 'تصدير للسحابة',
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const SyncDialog(isPush: true),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cloud_download_outlined, color: Colors.white),
                    tooltip: 'استيراد من السحابة',
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const SyncDialog(isPush: false),
                      );
                    },
                  ),
                  // 🔒 أيقونة الإعدادات محمية
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    onPressed: () => AuthGuard.run(
                      context,
                      () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    ),
                  ),
                ],
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipOval(
                                  child: Image.asset(
                                    'assets/logo.webp',
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text('روتي مان',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(arabicDate,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                if (distributorName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline,
                                          color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      const Text('الموزع / ',
                                          style: TextStyle(
                                              color: Colors.white54, fontSize: 12)),
                                      Text(distributorName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          )),
                                    ],
                                  )
                                ],
                                broadcastAsync.when(
                                  data: (text) {
                                    if (text == null || text.isEmpty) return const SizedBox.shrink();
                                    return _buildBroadcastBox(context, text);
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 🔒 شارة حالة اليوم (نُقلت للأسفل في صف منفصل) تم حذفها لأنها تتداخل مع الأزرار العلوية وتوجد حالة اليوم في الأسفل بالفعل.
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── الإجراءات الأساسية (محمية) ─────────────
                    const Text('الإجراءات الأساسية',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // التقارير
                        Expanded(
                          child: _buildActionTile(
                            context,
                            Icons.bar_chart,
                            'التقارير',
                            'التقارير اليومية',
                            AppTheme.success,
                            () => AuthGuard.run(context, () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // مراجعة الأيام
                        Expanded(
                          child: _buildActionTile(
                            context,
                            Icons.history,
                            'مراجعة الأيام',
                            'الأيام السابقة',
                            const Color(0xFFF43F5E),
                            () => AuthGuard.run(context, () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const DaysReviewScreen()))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // ── حالة العمل اليومي ─────────────────────
                    const Text('حالة العمل اليومي',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (!hasActiveDay)
                      _buildNoActiveDayCard(context)
                    else
                      _buildActiveDayCard(context, ref, inventoryAsync, workDay.id!.toString()),

                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateArabic(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('EEEE، d MMMM yyyy', 'ar');
      return formatter.format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // ── كرت "لم يتم بدء العمل" — محمي بتسجيل الدخول ──────────────
  Widget _buildNoActiveDayCard(BuildContext context) {
    return GestureDetector(
      onTap: () => AuthGuard.run(
        context,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NewDayScreen())),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wb_sunny_rounded,
                  color: Colors.amberAccent, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'لم يتم بدء العمل اليوم',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // 🔒 مؤشر القفل
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'يتطلب تفعيل الحساب',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'انقر هنا لفتح يوم عمل جديد وإدخال الحمولة الأولية من المخبز',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── كرت اليوم المفتوح — العمليات محمية ───────────────────
  Widget _buildActiveDayCard(
      BuildContext context, WidgetRef ref, AsyncValue inventoryAsync, String dayId) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.1))),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment_turned_in,
                    color: AppTheme.primary, size: 22),
                SizedBox(width: 8),
                Text('العمليات المتاحة لليوم المفتوح',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 🔒 توزيع
                    Expanded(
                      child: _buildDayActionBtn(
                        context: context,
                        icon: Icons.local_shipping,
                        label: 'توزيع',
                        color: AppTheme.primary,
                        onTap: () => AuthGuard.run(
                          context,
                          () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const DistributionScreen())),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 🔒 إضافة حمولة
                    Expanded(
                      child: _buildDayActionBtn(
                        context: context,
                        icon: Icons.inventory_2,
                        label: 'إضافة حمولة',
                        color: const Color(0xFF0EA5E9),
                        onTap: () => AuthGuard.run(
                          context,
                          () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => const AddInventoryScreen())),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInventoryCard(inventoryAsync),
                const SizedBox(height: 20),
                // 🔒 إغلاق اليوم
                _buildCloseDayButton(context, ref, dayId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayActionBtn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInventoryCard(AsyncValue inventoryAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.inventory_2_outlined,
                color: AppTheme.textSecondary, size: 18),
            SizedBox(width: 8),
            Text('تفاصيل حمولة السيارة',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(12),
          child: inventoryAsync.when(
            data: (inventory) {
              final list = inventory as List;
              if (list.isEmpty) {
                return const Text('لا توجد بيانات حمولة لهذا اليوم',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 13));
              }
              return Column(
                children: list.map<Widget>((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(item.productName,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        _statChip('بداية', item.initialLoad.toString(),
                            AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        _statChip('وُزّع', item.distributed.toString(),
                            AppTheme.warning),
                        const SizedBox(width: 6),
                        _statChip(
                            'متبقي', item.remaining.toString(), AppTheme.success),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('خطأ: $e'),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  /// بطاقة الإجراء — مع مؤشر قفل اختياري
  Widget _buildActionTile(
    BuildContext context,
    IconData iconData,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap, {
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // 🔒 مؤشر القفل
            if (isLocked)
              Icon(Icons.lock_outline,
                  size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseDayButton(
      BuildContext context, WidgetRef ref, String dayId) {
    return InkWell(
      // 🔒 إغلاق اليوم محمي بتسجيل الدخول
      onTap: () => AuthGuard.run(
        context,
        () => _confirmCloseDay(context, ref, dayId),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.danger.withValues(alpha: 0.4), width: 1),
        ),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Row(
              children: [
                Icon(Icons.lock_clock, color: AppTheme.danger),
                SizedBox(width: 12),
                Text('إغلاق يوم العمل',
                    style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            Icon(Icons.chevron_left, color: AppTheme.danger),
          ],
        ),
      ),
    );
  }

  void _confirmCloseDay(BuildContext context, WidgetRef ref, String dayId) {
    final inventoryState = ref.read(dailyInventoryProvider);
    final inventories = inventoryState.value ?? [];
    final remainingItems = inventories.where((inv) => inv.remaining != 0).toList();

    if (remainingItems.isNotEmpty) {
      final itemsStr = remainingItems.map((inv) => '• ${inv.productName}: ${inv.remaining} حبة').join('\n');
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تنبيه', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          content: Text('لا يمكن إغلاق اليوم.\nيوجد رصيد غير مسوى (موجب أو سالب) لم يتم تصفيته:\n\n$itemsStr\n\nالرجاء تسوية الكميات المتبقية عبر شاشات التوزيع أولاً.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إغلاق اليوم'),
        content: const Text(
            'هل أنت متأكد من إغلاق يوم العمل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(currentWorkDayProvider.notifier).closeDay(dayId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إغلاق اليوم بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('خطأ في الإغلاق', style: TextStyle(color: AppTheme.danger)),
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('حسناً'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الإغلاق',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastBox(BuildContext context, String text) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // خلفية دافئة فاتحة (ليست زرقاء)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_rounded, color: Colors.amber.shade700, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B), // نص داكن للقراءة
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showBroadcastDialog(context, text),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'قراءة المزيد',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('تعميم', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
