import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final broadcastProvider = StreamProvider<String?>((ref) {
  return FirebaseFirestore.instance
      .collection('broadcasts')
      .where('isActive', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['text'] as String?;
    }
    return null;
  });
});
