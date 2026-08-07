import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_generator.dart';
import '../../models/work_day.dart';
import '../../models/supplier.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/distributor_provider.dart';

class PdfReportDialog extends ConsumerWidget {
  final WorkDay workDay;

  const PdfReportDialog({Key? key, required this.workDay}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: AppTheme.danger, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إنشاء تقرير PDF', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                  Text('ليوم: ${workDay.date}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('اختر نوع التقرير:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Option 1: Distributor Report
          _ReportOption(
            icon: Icons.person_outline,
            color: const Color(0xFF2563EB),
            title: 'تقرير الموزع',
            subtitle: 'جميع حركات اليوم من كل المخابز',
            onTap: () async {
              Navigator.pop(context);
              final distributorName = ref.read(distributorNameProvider).value ?? '';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري إنشاء تقرير الموزع...'), duration: Duration(seconds: 2)));
              await PdfGenerator.generateDistributorReport(workDay, distributorName);
            },
          ),
          const SizedBox(height: 10),

          // Option 2: Supplier Report
          _SupplierReportOption(workDay: workDay),
        ],
      ),
    );
  }
}

class _ReportOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    );
  }
}

class _SupplierReportOption extends ConsumerStatefulWidget {
  final WorkDay workDay;
  const _SupplierReportOption({required this.workDay});

  @override
  ConsumerState<_SupplierReportOption> createState() => _SupplierReportOptionState();
}

class _SupplierReportOptionState extends ConsumerState<_SupplierReportOption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    const color = Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _expanded ? color : color.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تقرير المخبز', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('اختر المخبز لعرض بياناته فقط', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.arrow_forward_ios, color: color, size: 16),
                ),
              ],
            ),
          ),
        ),

        // Suppliers list (expanded)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? suppliersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (suppliers) => suppliers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('لا توجد مخابز مضافة',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 8),
                            ...suppliers.map((supplier) => _buildSupplierTile(supplier, color)),
                          ],
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSupplierTile(Supplier supplier, Color color) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final distributorName = ref.read(distributorNameProvider).value ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري إنشاء تقرير ${supplier.name}...'),
            duration: const Duration(seconds: 2),
          ),
        );
        await PdfGenerator.generateSupplierReport(widget.workDay, supplier, distributorName);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  supplier.name.isNotEmpty ? supplier.name[0] : '؟',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(supplier.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.danger, size: 20),
          ],
        ),
      ),
    );
  }
}
