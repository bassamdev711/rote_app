import 'package:roti_app/repositories/transaction_repository.dart';
import 'package:roti_app/repositories/work_day_repository.dart';
import 'package:roti_app/core/database/db_helper.dart';
import 'package:roti_app/models/distribution.dart';
import 'package:roti_app/models/return_transaction.dart';
import 'package:roti_app/models/collection_transaction.dart';
import 'package:roti_app/models/work_day.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  print('--- بدء اختبار سياسة إغلاق الأيام ---');
  final dbHelper = DBHelper.instance;
  final db = await dbHelper.database;
  
  // Clean up
  await db.delete('inventory_loads');
  await db.delete('distributions');
  await db.delete('returns');
  await db.delete('collections');
  await db.delete('work_days');
  await db.delete('suppliers');
  await db.delete('products');
  await db.delete('customers');

  // Create base data
  final productId = const Uuid().v4();
  await db.insert('products', {
    'id': productId,
    'name': 'خبز',
    'default_price': 100.0,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  final customerId = const Uuid().v4();
  await db.insert('customers', {
    'id': customerId,
    'name': 'عميل الاختبار',
    'current_balance': 0.0,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  // --- اختبار 1: تسلسل الأيام (إغلاق اليوم بنجاح) ---
  print('\\n--- اختبار 1: تسلسل الأيام ---');
  final wdRepo = WorkDayRepository();
  final txRepo = TransactionRepository();
  
  final day1Id = const Uuid().v4();
  await wdRepo.insert(WorkDay(id: day1Id, date: '2026-08-01', isClosed: false, createdAt: DateTime.now().toIso8601String()));
  print('تم إنشاء اليوم الأول (مفتوح).');

  // Load 100
  await db.insert('inventory_loads', {
    'id': const Uuid().v4(),
    'work_day_id': day1Id,
    'product_id': productId,
    'initial_quantity': 100,
    'cost_price': 80.0,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });
  print('تم تحميل 100 صنف.');

  // Distribute 100
  await txRepo.insertDistribution(Distribution(
    workDayId: day1Id,
    customerId: customerId,
    productId: productId,
    quantity: 100,
    price: 100.0,
    createdAt: DateTime.now().toIso8601String(),
  ));
  print('تم توزيع 100 صنف.');

  // Close Day 1
  try {
    await wdRepo.closeWorkDay(day1Id);
    print('✅ نجاح: تم إغلاق اليوم الأول بعد تصفية الرصيد.');
  } catch (e) {
    print('❌ فشل: لم يتمكن من إغلاق اليوم. الخطأ: \$e');
  }

  // Attempt to distribute in Day 1
  try {
    await txRepo.insertDistribution(Distribution(
      workDayId: day1Id,
      customerId: customerId,
      productId: productId,
      quantity: 10,
      price: 100.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    print('❌ فشل: تم السماح بإضافة توزيع في يوم مغلق!');
  } catch (e) {
    print('✅ نجاح: تم منع التوزيع في اليوم المغلق بنجاح. (\$e)');
  }

  // --- اختبار 2: التحصيل في يوم مغلق ---
  print('\\n--- اختبار 2: التحصيل في يوم مغلق ---');
  // Check customer balance
  var c = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
  double currentBalance = (c.first['current_balance'] as num).toDouble();
  print('رصيد العميل قبل التحصيل: $currentBalance');

  try {
    await txRepo.insertCollection(CollectionTransaction(
      workDayId: day1Id,
      customerId: customerId,
      amount: 50.0,
      createdAt: DateTime.now().toIso8601String(),
    ));
    print('✅ نجاح: تم السماح بإضافة تحصيل (500) في اليوم المغلق.');
  } catch (e) {
    print('❌ فشل: تم منع التحصيل في اليوم المغلق! الخطأ: $e');
  }

  c = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
  double newBalance = (c.first['current_balance'] as num).toDouble();
  print('رصيد العميل بعد التحصيل: $newBalance');
  if (newBalance == currentBalance - 500.0) {
    print('✅ نجاح: رصيد العميل تغير بشكل صحيح.');
  } else {
    print('❌ فشل: رصيد العميل لم يتغير بالشكل المتوقع.');
  }

  // Check inventory balance - it should be 0 (100 - 100)
  var dists = await db.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ?', [day1Id]);
  print('إجمالي الموزع لم يتأثر (المتوقع 100): ${dists.first["total"]}');

  print('\n--- اكتملت الاختبارات ---');
}
