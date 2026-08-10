import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/inventory_load.dart';

class InventoryLoadRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<void> _checkWorkDayOpen(Transaction txn, String workDayId) async {
    var wd = await txn.query('work_days', where: 'id = ?', whereArgs: [workDayId]);
    if (wd.isEmpty) throw Exception('اليوم المالي غير موجود');
    if (wd.first['is_closed'] == 1) throw Exception('لا يمكن إجراء عملية في يوم مغلق');
  }

  Future<void> _checkInventoryForPositiveOp(Transaction txn, String workDayId, String supplierId, String productId, double newQty, {double oldQty = 0}) async {
    List<Object> args = [workDayId, productId, supplierId];
    String suppFilter = ' AND supplier_id = ?';

    var loads = await txn.rawQuery('SELECT SUM(initial_quantity) as total FROM inventory_loads WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double loaded = (loads.first['total'] as num?)?.toDouble() ?? 0.0;

    var dists = await txn.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double distributed = (dists.first['total'] as num?)?.toDouble() ?? 0.0;

    var rets = await txn.rawQuery('SELECT SUM(quantity) as total FROM returns WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double returned = (rets.first['total'] as num?)?.toDouble() ?? 0.0;

    var srets = await txn.rawQuery('SELECT SUM(quantity) as total FROM supplier_returns WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double supplierReturned = (srets.first['total'] as num?)?.toDouble() ?? 0.0;

    var damages = await txn.rawQuery('SELECT SUM(quantity) as total FROM damaged_items WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double damaged = (damages.first['total'] as num?)?.toDouble() ?? 0.0;

    double currentAvailable = loaded + returned - distributed - supplierReturned - damaged;
    double availableIfOldRemoved = currentAvailable - oldQty;
    double projectedAvailable = availableIfOldRemoved + newQty;
    
    if (projectedAvailable < 0 && newQty < oldQty) {
      throw Exception('هذا التعديل سيجعل المخزون المتبقي بالسالب نظراً لأنه تم توزيع هذه البضاعة بالفعل');
    }
  }


  Future<String> insert(InventoryLoad load) async {
    if ((load.initialQuantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, load.workDayId);
      final map = load.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    await txn.insert('inventory_loads', map);
    return id;
    });
  }

  Future<List<InventoryLoad>> getLoadsForWorkDay(String workDayId) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_loads', 
      where: 'work_day_id = ? AND is_deleted = 0',
      whereArgs: [workDayId],
    );
    return List.generate(maps.length, (i) {
      return InventoryLoad.fromMap(maps[i]);
    });
  }

  Future<int> update(InventoryLoad load) async {
    if ((load.initialQuantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      var old = await txn.query('inventory_loads', where: 'id = ?', whereArgs: [load.id]);
      if (old.isNotEmpty) {
          await _checkWorkDayOpen(txn, old.first['work_day_id'] as String);
          double oldQty = (old.first['initial_quantity'] as num).toDouble();
          await _checkInventoryForPositiveOp(txn, load.workDayId, load.supplierId, load.productId, (load.initialQuantity ?? 0).toDouble(), oldQty: oldQty);
      }
      await _checkWorkDayOpen(txn, load.workDayId);
      final map = load.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    return await txn.update(
      'inventory_loads',
      map,
      where: 'id = ?',
      whereArgs: [load.id],
    );
    });
  }

  Future<int> delete(String id) async {
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      var old = await txn.query('inventory_loads', where: 'id = ?', whereArgs: [id]);
      if (old.isNotEmpty && old.first['is_deleted'] == 0) {
        await _checkWorkDayOpen(txn, old.first['work_day_id'] as String);
        await _checkInventoryForPositiveOp(txn, old.first['work_day_id'] as String, old.first['supplier_id'] as String, old.first['product_id'] as String, 0.0, oldQty: (old.first['initial_quantity'] as num).toDouble());
      }
      return await txn.update('inventory_loads', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getLoadsWithProductName(String workDayId) async {
    Database db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT il.*, p.name as product_name 
      FROM inventory_loads il
      LEFT JOIN products p ON il.product_id = p.id
      WHERE il.work_day_id = ? AND il.is_deleted = 0
    ''', [workDayId]);
  }
}
