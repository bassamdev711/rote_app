import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/db_helper.dart';
import '../models/supplier_payment.dart';

class SupplierPaymentRepository {
  final DBHelper _dbHelper = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<void> addPayment({
    required String supplierId,
    required double amount,
    required String type,
    String? workDayId,
    String? notes,
  }) async {
    Database db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    
    final payment = SupplierPayment(
      id: _uuid.v4(),
      supplierId: supplierId,
      amount: amount,
      type: type,
      workDayId: workDayId,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('supplier_payments', payment.toMap());

      // Update supplier balance
      // Positive amount means the distributor pays the supplier (balance increases)
      // Negative amount (or debt) means distributor owes the supplier (balance decreases)
      // Since amount is stored as passed, we just add it to the balance.
      // If closing a day, we will pass a negative amount.
      await txn.rawUpdate('''
        UPDATE suppliers
        SET current_balance = current_balance + ?,
            updated_at = ?,
            sync_status = 'pending'
        WHERE id = ?
      ''', [amount, now, supplierId]);
    });
  }

  Future<List<SupplierPayment>> getSupplierPayments(String supplierId) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'supplier_payments',
      where: 'supplier_id = ? AND is_deleted = 0',
      whereArgs: [supplierId],
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => SupplierPayment.fromMap(e)).toList();
  }

  Future<double> getSupplierBalance(String supplierId) async {
    Database db = await _dbHelper.database;
    final result = await db.query(
      'suppliers',
      columns: ['current_balance'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return (result.first['current_balance'] as num).toDouble();
    }
    return 0.0;
  }
}
