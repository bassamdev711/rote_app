import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        final status = doc.data()?['status'] as String?;
        if (status == 'approved') {
          // Success! Run the action.
          action();
        } else if (status == 'suspended') {
          _navigateToSuspended(context);
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحقق من الحساب: $e')),
        );
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
