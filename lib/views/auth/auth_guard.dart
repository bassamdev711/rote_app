import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';
import 'suspended_screen.dart';

class AuthGuard {
  static void run(BuildContext context, VoidCallback action) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // 1. Not logged in -> go to Login
    if (user == null) {
      _navigateToLogin(context);
      return;
    }

    // 2. Logged in, check status
    try {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
      );
      
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (context.mounted) Navigator.pop(context); // close loading

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
          _navigateToSuspended(context);
        } else if (status == 'active' || status == 'approved') {
          // Success! Run the action.
          action();
        } else {
          // Pending or other status
          _navigateToPending(context);
        }
      } else {
        // Document missing, might be still creating
        _navigateToPending(context);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // close loading
      
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
          if (context.mounted) _navigateToSuspended(context);
        } else if (cachedStatus == 'active' || cachedStatus == 'approved') {
          action();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ في الاتصال بالشبكة: $e')),
            );
          }
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في التحقق من الحساب: $e')),
          );
        }
      }
    }
  }

  static void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  static void _navigateToPending(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
    );
  }

  static void _navigateToSuspended(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SuspendedScreen()),
    );
  }
}
