import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/global_refresh_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import 'suppliers_list_screen.dart';
import '../customers/customers_screen.dart';
import '../../core/utils/app_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late FocusNode _nameFocusNode;
  bool _nameSaved = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _nameFocusNode = FocusNode();
    // Load the current name after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(distributorNameProvider).value ?? '';
      _nameCtrl.text = name;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    // Watch so that when name loads from prefs it refreshes
    final nameAsync = ref.watch(distributorNameProvider);
    final customersAsync = ref.watch(customersProvider);
    final customerCount = customersAsync.when(
      data: (c) => c.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // Sync text controller when provider loads
    nameAsync.whenData((name) {
      if (_nameCtrl.text != name) _nameCtrl.text = name;
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
  // ── Distributor Name Card ──
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _nameCtrl.text.isEmpty ? 'اسم الموزع...' : _nameCtrl.text,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showEditNameDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (FirebaseAuth.instance.currentUser?.phoneNumber?.isNotEmpty == true 
                            ? FirebaseAuth.instance.currentUser!.phoneNumber! 
                            : FirebaseAuth.instance.currentUser?.email?.replaceAll('@manager.roti.app', '')?.replaceAll('@roti.app', '')?.replaceAll('@roti.com', '')) ?? 'بدون رقم',
                        style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Customers Summary Card ──
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: Color(0xFF8B5CF6), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('العملاء', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          '$customerCount عميل مسجل',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Color(0xFF8B5CF6), size: 22),
                ],
              ),
            ),
          ),

          _sectionHeader('إدارة البيانات'),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.storefront_outlined,
            iconColor: AppTheme.primary,
            title: 'المخابز (الموردين)',
            subtitle: 'إدارة المخابز وأسعار التكلفة',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuppliersListScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.category_outlined,
            iconColor: AppTheme.primary,
            title: 'الأصناف',
            subtitle: 'إضافة وتعديل أصناف المخبوزات',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductsManagementScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader('التطبيق'),

          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.info_outline,
            iconColor: AppTheme.textSecondary,
            title: 'حول التطبيق',
            subtitle: 'روتي مان - الإصدار 1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: 20),
          _sectionHeader('الدعم والمساعدة'),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.support_agent,
            iconColor: Colors.green,
            title: 'تواصل معنا (الإدارة)',
            subtitle: 'للتواصل عبر الواتساب للاستفسار أو الدعم',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: const [
                      Icon(Icons.chat, color: Colors.green),
                      SizedBox(width: 8),
                      Text('تواصل معنا'),
                    ],
                  ),
                  content: const Text('سيتم تحويلك إلى دردشة الواتساب الخاصة بالمطور'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('تراجع', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('مواصلة'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              final appUrl = Uri.parse('whatsapp://send?phone=+967780500363');
              final webUrl = Uri.parse('https://wa.me/967780500363');
              try {
                if (await canLaunchUrl(appUrl)) {
                  await launchUrl(appUrl, mode: LaunchMode.externalApplication);
                } else if (await canLaunchUrl(webUrl)) {
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر فتح واتساب. تأكد من تثبيت التطبيق أو وجود متصفح.')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.language,
            iconColor: Colors.blue,
            title: 'عن المطور',
            subtitle: 'بسام الحكيم - مطور التطبيق',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: const [
                      Icon(Icons.language, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('عن المطور'),
                    ],
                  ),
                  content: const Text('سيتم فتح موقع المطور في المتصفح الافتراضي'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('تراجع', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('مواصلة'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              final url = Uri.parse('https://bassam-alhakim-portfolio.vercel.app/');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر فتح الرابط')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 20),
          _sectionHeader('الحساب'),
          const SizedBox(height: 8),
          _settingsTile(
            context,
            icon: Icons.logout,
            iconColor: AppTheme.danger,
            title: 'تسجيل الخروج',
            subtitle: 'تسجيل الخروج من الحساب الحالي',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: const [
                      Icon(Icons.logout, color: AppTheme.danger),
                      SizedBox(width: 8),
                      Text('تسجيل الخروج'),
                    ],
                  ),
                  content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من الحساب الحالي؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                ref.invalidate(globalRefreshProvider);
                await ref.read(authServiceProvider).logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    // Save locally
    await ref.read(distributorNameProvider.notifier).setName(newName);

    // Save to Firestore to persist across logouts
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': newName,
        });
      } catch (e) {
        // Ignore network errors silently for settings sync
      }
    }

    setState(() => _nameSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _nameSaved = false);
    });
  }

  void _showEditNameDialog(BuildContext context) {
    final tempCtrl = TextEditingController(text: _nameCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل اسم الموزع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: tempCtrl,
          decoration: const InputDecoration(
            hintText: 'أدخل الاسم الجديد...',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (tempCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _nameCtrl.text = tempCtrl.text.trim();
                });
                _saveName();
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
    );
  }

  Widget _settingsTile(BuildContext context,
      {required IconData icon, required Color iconColor, required String title,
       required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Products Management ──────────────────────────────────────
class ProductsManagementScreen extends ConsumerWidget {
  const ProductsManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('إدارة الأصناف'), backgroundColor: AppTheme.background),
      body: productsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('لا توجد أصناف بعد', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('اضغط + لإضافة صنف جديد', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = products[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Text('🍞', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                      onPressed: () => _showEditDialog(context, ref, p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      onPressed: () => _confirmDelete(context, ref, p.id!, p.name),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صنف'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة صنف جديد', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _inputField(nameCtrl, 'اسم الصنف *', 'مثال: روتي'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الاسم مطلوب')));
                      return;
                    }
                    await ref.read(productsProvider.notifier).addProduct(Product(
                      name: nameCtrl.text.trim(),
                      defaultPrice: 0,
                      createdAt: DateTime.now().toIso8601String(),
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Product product) {
    final nameCtrl = TextEditingController(text: product.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تعديل الصنف', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _inputField(nameCtrl, 'اسم الصنف *', 'مثال: روتي'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الاسم مطلوب')));
                      return;
                    }
                    final updated = product.copyWith(
                      name: nameCtrl.text.trim(),
                      updatedAt: DateTime.now().toIso8601String(),
                      syncStatus: 'pending',
                    );
                    await ref.read(productsProvider.notifier).updateProduct(updated);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('حفظ التعديل'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, String hint, [TextInputType? type]) {
    return TextField(
      controller: ctrl,
      keyboardType: type ?? TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: Text('هل تريد حذف "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              try {
                await ref.read(productsProvider.notifier).deleteProduct(id);
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

