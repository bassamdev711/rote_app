import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import 'main/home_screen.dart';
import 'auth/login_screen.dart';
import 'auth/pending_approval_screen.dart';
import 'auth/suspended_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)));
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _controller.forward();

    _runSecurityCheckAndNavigate();
  }

  Future<void> _runSecurityCheckAndNavigate() async {
    // الانتظار حتى تكتمل حركة البداية
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final subEndTs = data['subscription_end_date'] as Timestamp?;
          
          final prefs = await SharedPreferences.getInstance();
          if (status != null) await prefs.setString('cached_status', status);
          if (subEndTs != null) await prefs.setInt('cached_sub_end', subEndTs.millisecondsSinceEpoch);

          bool isExpired = false;
          if (subEndTs != null) {
            isExpired = subEndTs.toDate().isBefore(DateTime.now());
          }

          if (status == 'suspended' || isExpired) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SuspendedScreen()),
            );
          } else if (status == 'active' || status == 'approved') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
            );
          }
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          );
        }
      } catch (e) {
        // Fallback in case of lack of internet, use local cache
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedStatus = prefs.getString('cached_status');
          final cachedSubEnd = prefs.getInt('cached_sub_end');
          
          bool isExpired = false;
          if (cachedSubEnd != null) {
            final endDate = DateTime.fromMillisecondsSinceEpoch(cachedSubEnd);
            isExpired = endDate.isBefore(DateTime.now());
          }
          
          if (cachedStatus == 'suspended' || isExpired) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SuspendedScreen()),
            );
          } else if (cachedStatus == 'active' || cachedStatus == 'approved') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } catch (_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الشعار الرسمي
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.webp',
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'روتي مان',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'رفيقك في التوزيع',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 60),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
