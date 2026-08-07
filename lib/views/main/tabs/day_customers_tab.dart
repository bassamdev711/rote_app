import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/customer.dart';
import '../../../models/work_day.dart';
import '../../../repositories/transaction_repository.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/global_refresh_provider.dart';
import '../../distribution/customer_card_screen.dart';

class DayCustomersTab extends ConsumerStatefulWidget {
  final WorkDay workDay;
  const DayCustomersTab({Key? key, required this.workDay}) : super(key: key);

  @override
  ConsumerState<DayCustomersTab> createState() => _DayCustomersTabState();
}

class _DayCustomersTabState extends ConsumerState<DayCustomersTab>
    with AutomaticKeepAliveClientMixin {
  final _txRepo = TransactionRepository();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maps = await _txRepo.getCustomersWithTransactionsForDay(widget.workDay.id!);
    if (mounted) {
      setState(() {
        _customers = maps.map((m) => Customer.fromMap(m)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(globalRefreshProvider, (_, __) => _load());
    if (_loading) return const SizedBox.shrink();

    final allCustomersAsync = ref.watch(customersProvider);

    return Column(
      children: [
        // زر إضافة عميل - يظهر فقط إذا كان اليوم مفتوحاً
        if (!widget.workDay.isClosed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: allCustomersAsync.when(
              data: (all) {
                final unlisted = all.where((c) => !_customers.any((lc) => lc.id == c.id)).toList();
                if (unlisted.isEmpty) return const SizedBox();
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('إضافة عميل لهذا اليوم'),
                    onPressed: () => _showAddDialog(context, unlisted),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

        // عدد العملاء
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('العملاء (${_customers.length})',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ),

        // القائمة
        Expanded(
          child: _customers.isEmpty
              ? const Center(
                  child: Text('لا توجد حركات في هذا اليوم',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _customers[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        tileColor: AppTheme.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                          child: Text(c.name[0],
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c.name,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: c.neighborhood != null && c.neighborhood!.isNotEmpty
                            ? Text(c.neighborhood!,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                            : null,
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => CustomerCardScreen(customer: c, workDayId: widget.workDay.id, isClosed: widget.workDay.isClosed),
                          ));
                          _load();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, List<Customer> unlisted) {
    Customer? selected = unlisted.first;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('اختر عميلاً'),
          content: DropdownButton<Customer>(
            value: selected,
            isExpanded: true,
            items: unlisted.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (c) => setS(() => selected = c),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (selected != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CustomerCardScreen(customer: selected!, workDayId: widget.workDay.id, isClosed: widget.workDay.isClosed),
                  )).then((_) => _load());
                }
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      ),
    );
  }
}
