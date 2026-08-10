import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/supplier.dart';
import '../models/supplier_product.dart';
import '../models/supplier_return.dart';
import '../models/damaged_item.dart';

class SupplierRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<void> _checkWorkDayOpen(Transaction txn, String workDayId) async {
    var wd = await txn.query('work_days', where: 'id = ?', whereArgs: [workDayId]);
    if (wd.isEmpty) throw Exception('اليوم المالي غير موجود');
    if (wd.first['is_closed'] == 1) throw Exception('لا يمكن إجراء عملية في يوم مغلق');
  }

  Future<void> _checkInventoryForNegativeOp(Transaction txn, String workDayId, String supplierId, String productId, double newQty, {double oldQty = 0}) async {
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
    double availableIfOldRemoved = currentAvailable + oldQty;
    
    if (newQty > availableIfOldRemoved) {
      throw Exception('الكمية المطلوبة أكبر من المخزون المتبقي (المتوفر)');
    }
  }


  // --- Suppliers ---
  Future<int> insertSupplier(Supplier supplier) async {
    Database db = await _dbHelper.database;
    final map = supplier.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    map['updated_at'] = map['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    return await db.insert('suppliers', map);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    Database db = await _dbHelper.database;
    final map = supplier.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return await db.update('suppliers', map, where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deleteSupplier(String id) async {
    Database db = await _dbHelper.database;
    return await db.update('suppliers', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> getAllSuppliers({int? limit, int? offset}) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers', 
      where: 'is_deleted = 0', 
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  // --- Supplier Products ---
  Future<int> insertSupplierProduct(SupplierProduct sp) async {
    Database db = await _dbHelper.database;
    final map = sp.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    map['created_at'] = map['created_at'] ?? DateTime.now().toUtc().toIso8601String();
    map['updated_at'] = map['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    return await db.insert('supplier_products', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateSupplierProduct(SupplierProduct sp) async {
    Database db = await _dbHelper.database;
    final map = sp.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return await db.update('supplier_products', map, where: 'id = ?', whereArgs: [sp.id]);
  }

  Future<int> deleteSupplierProduct(String id) async {
    Database db = await _dbHelper.database;
    return await db.update('supplier_products', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProductsForSupplier(String supplierId) async {
    Database db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT sp.id AS sp_id, sp.cost_price, p.id AS product_id, p.name AS product_name, p.default_price
      FROM supplier_products sp
      JOIN products p ON sp.product_id = p.id
      WHERE sp.supplier_id = ? AND sp.is_deleted = 0 AND p.is_deleted = 0
      ORDER BY p.name ASC
    ''', [supplierId]);
  }

  // --- Supplier Returns ---
  Future<int> insertSupplierReturn(SupplierReturn sReturn) async {
    if ((sReturn.quantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, sReturn.workDayId);
      await _checkInventoryForNegativeOp(txn, sReturn.workDayId, sReturn.supplierId, sReturn.productId, (sReturn.quantity ?? 0).toDouble());
      final map = sReturn.toMap();
      final String id = (map['id'] == null || map['id'].toString().isEmpty) ? const Uuid().v4() : map['id'];
      map['id'] = id;
    map['updated_at'] = map['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    return await txn.insert('supplier_returns', map);
    });
  }

  Future<List<SupplierReturn>> getReturnsForWorkDay(String workDayId) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'supplier_returns',
      where: 'work_day_id = ? AND is_deleted = 0',
      whereArgs: [workDayId],
    );
    return List.generate(maps.length, (i) => SupplierReturn.fromMap(maps[i]));
  }

  // --- Damaged Items ---
  Future<int> insertDamagedItem(DamagedItem di) async {
    if (di.quantity < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, di.workDayId);
      await _checkInventoryForNegativeOp(txn, di.workDayId, di.supplierId, di.productId, di.quantity.toDouble());
      final map = di.toMap();
      final String id = (map['id'] == null || map['id'].toString().isEmpty) ? const Uuid().v4() : map['id'];
      map['id'] = id;
    map['updated_at'] = map['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    return await txn.insert('damaged_items', map);
    });
  }

  Future<List<DamagedItem>> getDamagedItemsForWorkDay(String workDayId) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'damaged_items',
      where: 'work_day_id = ? AND is_deleted = 0',
      whereArgs: [workDayId],
    );
    return List.generate(maps.length, (i) => DamagedItem.fromMap(maps[i]));
  }
}
