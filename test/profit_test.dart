import 'package:roti_app/repositories/transaction_repository.dart';
import 'package:roti_app/repositories/inventory_load_repository.dart';
import 'package:roti_app/core/database/db_helper.dart';
import 'package:roti_app/models/inventory_load.dart';
import 'package:roti_app/models/distribution.dart';
import 'package:roti_app/models/return_transaction.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  print('--- بدء اختبار منظومة الأرباح ---');
  final dbHelper = DBHelper.instance;
  final db = await dbHelper.database;
  
  // Clean up
  await db.delete('inventory_loads');
  await db.delete('distributions');
  await db.delete('returns');
  await db.delete('work_days');
  await db.delete('suppliers');
  await db.delete('products');
  await db.delete('customers');

  // Create base data
  final supplierId = const Uuid().v4();
  await db.insert('suppliers', {
    'id': supplierId,
    'name': 'مخبز الاختبار',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  final productId = const Uuid().v4();
  await db.insert('products', {
    'id': productId,
    'name': 'صنف الاختبار',
    'default_price': 100.0,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  final customerId = const Uuid().v4();
  await db.insert('customers', {
    'id': customerId,
    'name': 'عميل الاختبار',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  final workDayId = const Uuid().v4();
  await db.insert('work_days', {
    'id': workDayId,
    'date': DateTime.now().toIso8601String().split('T').first,
    'is_closed': 0,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });

  final txRepo = TransactionRepository();
  final invRepo = InventoryLoadRepository();

  // 1. Load Inventory: 10 items at 80 cost
  print('1. تحميل المخزون: 10 حبات بسعر 80 ريال');
  await invRepo.insert(InventoryLoad(
    id: const Uuid().v4(),
    workDayId: workDayId,
    supplierId: supplierId,
    productId: productId,
    initialQuantity: 10,
    costPrice: 80.0,
    createdAt: DateTime.now().toIso8601String(),
  ));

  // 2. Distribute: 10 items at 100 price
  print('2. التوزيع: بيع 10 حبات بسعر 100 ريال');
  await txRepo.insertDistribution(Distribution(
    id: const Uuid().v4(),
    workDayId: workDayId,
    customerId: customerId,
    productId: productId,
    quantity: 10,
    price: 100.0,
    createdAt: DateTime.now().toIso8601String(),
  ));

  // 3. Check Profit
  var profits = await txRepo.getDayProfitBySupplierFIFO(workDayId);
  print('\\n--- نتيجة الأرباح بعد التوزيع ---');
  for (var p in profits) {
    print('الإيراد = ${p["total_revenue"]}');
    print('تكلفة البيع = ${p["total_cost"]}');
    print('الربح = ${p["total_profit"]}');
  }

  // 4. Return: 2 items at 100 price
  print('\\n3. المرتجع: إرجاع 2 حبة بسعر 100 ريال');
  await txRepo.insertReturn(ReturnTransaction(
    id: const Uuid().v4(),
    workDayId: workDayId,
    customerId: customerId,
    productId: productId,
    quantity: 2,
    price: 100.0,
    createdAt: DateTime.now().toIso8601String(),
  ));

  // 5. Check Profit again
  profits = await txRepo.getDayProfitBySupplierFIFO(workDayId);
  print('\\n--- نتيجة الأرباح بعد المرتجع ---');
  for (var p in profits) {
    print('الإيراد = ${p["total_revenue"]}');
    print('تكلفة البيع = ${p["total_cost"]}');
    print('الربح = ${p["total_profit"]}');
  }
}
