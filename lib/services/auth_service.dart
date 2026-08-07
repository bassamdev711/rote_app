import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/db_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Since we use phone as email, this helper transforms it
  String _phoneToEmail(String phone) {
    return "$phone@roti.app";
  }

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user details stream (to listen to status changes like 'pending' -> 'approved')
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Login
  Future<UserCredential?> login(String phone, String password) async {
    try {
      String email = _phoneToEmail(phone);
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e.toString()));
    }
  }

  // Register
  Future<UserCredential?> register(String name, String phone, String password) async {
    try {
      String email = _phoneToEmail(phone);
      
      // 1. Create the user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Create their document in Firestore with status 'pending'
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'phone': phone,
          'status': 'pending', // Important: Admin needs to change this to 'approved'
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } catch (e) {
      throw Exception(_handleAuthError(e.toString()));
    }
  }

  // Logout
  Future<void> logout() async {
    // 1. إفراغ قاعدة البيانات المحلية بالكامل
    await DBHelper.clearDatabase();
    
    // 2. مسح جميع التفضيلات المخزنة (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. مسح الخزنة الآمنة (Secure Storage) بالكامل
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await secureStorage.deleteAll();

    // 4. مسح الذاكرة المؤقتة السحابية لـ Firestore (Offline Cache)
    try {
      await _firestore.terminate();
      await _firestore.clearPersistence();
    } catch (e) {
      print('Error clearing Firestore persistence: $e');
    }

    // 5. تسجيل الخروج من فايربيس
    await _auth.signOut();
  }

  // Error translations
  String _handleAuthError(String error) {
    if (error.contains('user-not-found') || error.contains('invalid-credential')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    } else if (error.contains('email-already-in-use')) {
      return 'رقم الهاتف مسجل مسبقاً';
    } else if (error.contains('weak-password')) {
      return 'كلمة المرور ضعيفة جداً';
    }
    return 'حدث خطأ أثناء الاتصال بالخادم';
  }
}
