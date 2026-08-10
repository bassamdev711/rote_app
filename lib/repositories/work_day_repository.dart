import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/work_day.dart';
import 'transaction_repository.dart';
import 'supplier_payment_repository.dart';

class WorkDayRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<String> insert(WorkDay workDay) async {
    Database db = await _dbHelper.database;
    final map = workDay.toMap();
    final String id = map['id'] ?? map['date'];
    map['id'] = id;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    await db.insert('work_days', map);
    return id;
  }

  Future<List<WorkDay>> getAll() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_days', 
      where: 'is_deleted = 0',
      orderBy: 'date DESC'
    );
    return List.generate(maps.length, (i) {
      return WorkDay.fromMap(maps[i]);
    });
  }

  Future<WorkDay?> getActiveWorkDay() async {
    Database db = await _dbHelper.database;
    final maps = await db.query('work_days', where: 'is_closed = 0 AND is_deleted = 0', limit: 1);
    if (maps.isNotEmpty) return WorkDay.fromMap(maps.first);
    return null;
  }

  Future<int> update(WorkDay workDay) async {
    Database db = await _dbHelper.database;
    final map = workDay.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    return await db.update(
      'work_days',
      map,
      where: 'id = ?',
      whereArgs: [workDay.id],
    );
  }

  Future<int> delete(String id) async {
    Database db = await _dbHelper.database;
    return await db.update('work_days', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }


  Future<void> _verifyDayBalanceToZero(Database db, String workDayId) async {
    // 1. Get all unique product & supplier combinations involved in this workday
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT DISTINCT product_id, supplier_id FROM (
        SELECT product_id, supplier_id FROM inventory_loads WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT product_id, supplier_id FROM distributions WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT product_id, supplier_id FROM returns WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT product_id, supplier_id FROM supplier_returns WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT product_id, supplier_id FROM damaged_items WHERE work_day_id = ? AND is_deleted = 0
      )
    ''', [workDayId, workDayId, workDayId, workDayId, workDayId]);

    // 2. Check balance for each combination
    for (var row in rows) {
      final pid = row['product_id'];
      final sid = row['supplier_id'];
      
      final loadRes = await db.rawQuery('SELECT SUM(initial_quantity) as s FROM inventory_loads WHERE work_day_id = ? AND product_id = ? AND supplier_id = ? AND is_deleted = 0', [workDayId, pid, sid]);
      final distRes = await db.rawQuery('SELECT SUM(quantity) as s FROM distributions WHERE work_day_id = ? AND product_id = ? AND supplier_id = ? AND is_deleted = 0', [workDayId, pid, sid]);
      final retRes = await db.rawQuery('SELECT SUM(quantity) as s FROM returns WHERE work_day_id = ? AND product_id = ? AND supplier_id = ? AND is_deleted = 0', [workDayId, pid, sid]);
      final sretRes = await db.rawQuery('SELECT SUM(quantity) as s FROM supplier_returns WHERE work_day_id = ? AND product_id = ? AND supplier_id = ? AND is_deleted = 0', [workDayId, pid, sid]);
      final dmgRes = await db.rawQuery('SELECT SUM(quantity) as s FROM damaged_items WHERE work_day_id = ? AND product_id = ? AND supplier_id = ? AND is_deleted = 0', [workDayId, pid, sid]);
      
      final double load = (loadRes.first['s'] as num?)?.toDouble() ?? 0.0;
      final double dist = (distRes.first['s'] as num?)?.toDouble() ?? 0.0;
      final double ret = (retRes.first['s'] as num?)?.toDouble() ?? 0.0;
      final double sret = (sretRes.first['s'] as num?)?.toDouble() ?? 0.0;
      final double dmg = (dmgRes.first['s'] as num?)?.toDouble() ?? 0.0;
      
      final double remaining = load + ret - dist - sret - dmg;
      
      if (remaining != 0) {
        throw Exception('لا يمكن إغلاق اليوم. يوجد رصيد غير مسوى للصنف في أحد المخابز. المتبقي: $remaining');
      }
    }
  }

  Future<int> closeWorkDay(String id) async {
    Database db = await _dbHelper.database;
    
    // Inventory Verification per product
    await _verifyDayBalanceToZero(db, id);

    // Calculate supplier debts and record them
    final txRepo = TransactionRepository();
    final supplierPaymentRepo = SupplierPaymentRepository();
    
    final supplierProfits = await txRepo.getDayProfitBySupplierFIFO(id);
    for (var sp in supplierProfits) {
      final sId = sp['supplier_id'] as String;
      final cost = sp['total_cost'] != null 
          ? (sp['total_cost'] is String ? double.tryParse(sp['total_cost'].toString()) ?? 0.0 : (sp['total_cost'] as num).toDouble())
          : 0.0;
      
      if (cost > 0) {
        await supplierPaymentRepo.addPayment(
          supplierId: sId,
          amount: -cost, // Negative means we owe the supplier
          type: 'ديون إغلاق يوم',
          workDayId: id,
          notes: 'مديونية إغلاق اليوم',
        );
      }
    }

    return await db.update(
      'work_days',
      {
        'is_closed': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending'
      },
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<int> openWorkDay(String id) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'work_days',
      {
        'is_closed': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending'
      },
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<List<WorkDay>> getAllClosedDays() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_days', 
      where: 'is_closed = 1 AND is_deleted = 0',
      orderBy: 'date DESC'
    );
    return List.generate(maps.length, (i) {
      return WorkDay.fromMap(maps[i]);
    });
  }
}
