import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/global_refresh_provider.dart';
import '../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'dart:ui';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extract phone from email
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.email?.replaceAll('@roti.app', '') ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('بانتظار الموافقة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              ref.invalidate(globalRefreshProvider);
              await ref.read(authServiceProvider).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_empty, size: 64, color: AppTheme.warning),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'حسابك قيد المراجعة',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تم تقديم طلبك بنجاح. يرجى التواصل مع الإدارة لتسديد الرسوم وتفعيل الحساب.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 12),
                            const Text('780500363', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 2)),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(text: '780500363'));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرقم')));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text('تواصل معنا (واتساب)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final msg = "السلام عليكم ورحمة الله، لقد قمت بإنشاء حساب جديد في روتي مان منصة التوزيع، وأرغب في استكمال إجراءات التسجيل. رقم الجوال المسجل: $phone أرجو التكرم بمراجعة الطلب وتفعيل الحساب. شكراً لكم.";
                            final encodedMsg = Uri.encodeComponent(msg);
                            final whatsappUrl = Uri.parse('whatsapp://send?phone=+967780500363&text=$encodedMsg');
                            final webUrl = Uri.parse('https://wa.me/967780500363?text=$encodedMsg');
                            
                            try {
                              if (await canLaunchUrl(whatsappUrl)) {
                                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                              } else {
                                await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الواتساب')));
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
