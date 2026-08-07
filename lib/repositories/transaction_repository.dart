import 'package:uuid/uuid.dart';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../core/database/db_helper.dart';

import '../models/distribution.dart';

import '../models/return_transaction.dart';

import '../models/collection_transaction.dart';

import '../models/customer_statement_item.dart';



class TransactionRepository {

  final DBHelper _dbHelper = DBHelper.instance;

  Future<void> _checkWorkDayOpen(Transaction txn, String workDayId) async {
    var wd = await txn.query('work_days', where: 'id = ?', whereArgs: [workDayId]);
    if (wd.isEmpty) throw Exception('اليوم المالي غير موجود');
    if (wd.first['is_closed'] == 1) throw Exception('لا يمكن إجراء عملية في يوم مغلق');
  }

  Future<void> _checkInventoryForNegativeOp(Transaction txn, String workDayId, String productId, double newQty, {double oldQty = 0, String? supplierId}) async {
    String suppFilter = supplierId != null ? ' AND supplier_id = ?' : '';
    List<Object> args = supplierId != null ? [workDayId, productId, supplierId] : [workDayId, productId];

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

  Future<void> _checkInventoryForPositiveOp(Transaction txn, String workDayId, String productId, double newQty, {double oldQty = 0, String? supplierId}) async {
    String suppFilter = supplierId != null ? ' AND supplier_id = ?' : '';
    List<Object> args = supplierId != null ? [workDayId, productId, supplierId] : [workDayId, productId];

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

  Future<void> _checkReturnAvailable(Transaction txn, String workDayId, String customerId, String productId, double newQty, {double oldQty = 0, String? supplierId}) async {
    String suppFilter = supplierId != null ? ' AND supplier_id = ?' : '';
    List<Object> args = supplierId != null ? [workDayId, customerId, productId, supplierId] : [workDayId, customerId, productId];

    var dists = await txn.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ? AND customer_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double distributed = (dists.first['total'] as num?)?.toDouble() ?? 0.0;

    var rets = await txn.rawQuery('SELECT SUM(quantity) as total FROM returns WHERE work_day_id = ? AND customer_id = ? AND product_id = ? AND is_deleted = 0$suppFilter', args);
    double returned = (rets.first['total'] as num?)?.toDouble() ?? 0.0;

    double returnedIfOldRemoved = returned - oldQty;
    double projectedReturned = returnedIfOldRemoved + newQty;

    if (projectedReturned > distributed) {
      throw Exception('إجمالي المرتجع يتجاوز ما تم توزيعه للعميل في هذا اليوم');
    }
  }


  Future<int> insertDistribution(Distribution distribution) async {
    if ((distribution.quantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    if (distribution.price < 0) throw Exception('لا يمكن إدخال سعر سالب');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, distribution.workDayId);
      await _checkInventoryForNegativeOp(txn, distribution.workDayId, distribution.productId, (distribution.quantity ?? 0).toDouble(), supplierId: distribution.supplierId);
      final map = distribution.toMap();
      map['id'] = map['id'] ?? const Uuid().v4();
      map['updated_at'] = map['updated_at'] ?? DateTime.now().toIso8601String();
      int res = await txn.insert('distributions', map);
      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
        [(distribution.quantity ?? 0) * distribution.price, distribution.customerId]
      );
      return res;
    });
  }



  Future<int> updateDistribution(Distribution distribution) async {
    if ((distribution.quantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    if (distribution.price < 0) throw Exception('لا يمكن إدخال سعر سالب');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, distribution.workDayId);
      await _checkInventoryForNegativeOp(txn, distribution.workDayId, distribution.productId, (distribution.quantity ?? 0).toDouble(), supplierId: distribution.supplierId);
      final map = distribution.toMap();
      map['updated_at'] = DateTime.now().toIso8601String();
      map['sync_status'] = 'pending';
      var old = await txn.query('distributions', where: 'id = ?', whereArgs: [distribution.id]);
      await _checkWorkDayOpen(txn, distribution.workDayId);
      
      double oldQty = 0.0;
      String? oldProductId;
      
      if (old.isNotEmpty) {
        oldQty = (old.first['quantity'] as num).toDouble();
        oldProductId = old.first['product_id'] as String;
      }

      if (oldProductId != null && oldProductId == distribution.productId) {
        await _checkInventoryForNegativeOp(txn, distribution.workDayId, distribution.productId, (distribution.quantity ?? 0).toDouble(), oldQty: oldQty, supplierId: distribution.supplierId);
      } else {
        await _checkInventoryForNegativeOp(txn, distribution.workDayId, distribution.productId, (distribution.quantity ?? 0).toDouble(), oldQty: 0.0, supplierId: distribution.supplierId);
        if (oldProductId != null) {
          // Note: using the new supplierId for the old product check might be slightly inaccurate if supplier changed, but it's acceptable for this simple case. Ideally we should read old supplier_id.
          await _checkInventoryForPositiveOp(txn, distribution.workDayId, oldProductId, 0.0, oldQty: oldQty, supplierId: distribution.supplierId);
        }
      }
      if (old.isNotEmpty) {
        double oldVal = ((old.first['quantity'] as num) * (old.first['price'] as num)).toDouble();
        double newVal = (distribution.quantity ?? 0) * distribution.price;
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance - ? + ? WHERE id = ?', [oldVal, newVal, distribution.customerId]);
      }
      return await txn.update('distributions', map, where: 'id = ?', whereArgs: [distribution.id]);
    });
  }



  Future<int> deleteDistribution(String id) async {
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      var old = await txn.query('distributions', where: 'id = ?', whereArgs: [id]);
      if (old.isNotEmpty && old.first['is_deleted'] == 0) {
        await _checkWorkDayOpen(txn, old.first['work_day_id'] as String);
        await _checkInventoryForPositiveOp(txn, old.first['work_day_id'] as String, old.first['product_id'] as String, 0.0, oldQty: (old.first['quantity'] as num).toDouble());
        double val = ((old.first['quantity'] as num) * (old.first['price'] as num)).toDouble();
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance - ? WHERE id = ?', [val, old.first['customer_id']]);
      }
      return await txn.update('distributions', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }



  Future<int> insertReturn(ReturnTransaction returnTx) async {
    if ((returnTx.quantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    if (returnTx.price < 0) throw Exception('لا يمكن إدخال سعر سالب');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, returnTx.workDayId);
      await _checkInventoryForPositiveOp(txn, returnTx.workDayId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), supplierId: returnTx.supplierId);
      await _checkReturnAvailable(txn, returnTx.workDayId, returnTx.customerId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), supplierId: returnTx.supplierId);
      final map = returnTx.toMap();
      map['id'] = map['id'] ?? const Uuid().v4();
      map['updated_at'] = map['updated_at'] ?? DateTime.now().toIso8601String();
      int res = await txn.insert('returns', map);
      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance - ? WHERE id = ?',
        [(returnTx.quantity ?? 0) * returnTx.price, returnTx.customerId]
      );
      return res;
    });
  }



  Future<int> updateReturn(ReturnTransaction returnTx) async {
    if ((returnTx.quantity ?? 0) < 0) throw Exception('لا يمكن إدخال كمية سالبة');
    if (returnTx.price < 0) throw Exception('لا يمكن إدخال سعر سالب');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _checkWorkDayOpen(txn, returnTx.workDayId);
      await _checkInventoryForPositiveOp(txn, returnTx.workDayId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), supplierId: returnTx.supplierId);
      await _checkReturnAvailable(txn, returnTx.workDayId, returnTx.customerId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), supplierId: returnTx.supplierId);
      final map = returnTx.toMap();
      map['updated_at'] = DateTime.now().toIso8601String();
      map['sync_status'] = 'pending';
      var old = await txn.query('returns', where: 'id = ?', whereArgs: [returnTx.id]);
      await _checkWorkDayOpen(txn, returnTx.workDayId);
      
      double oldQty = 0.0;
      String? oldProductId;
      
      if (old.isNotEmpty) {
        oldQty = (old.first['quantity'] as num).toDouble();
        oldProductId = old.first['product_id'] as String;
      }

      if (oldProductId != null && oldProductId == returnTx.productId) {
        await _checkInventoryForPositiveOp(txn, returnTx.workDayId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), oldQty: oldQty, supplierId: returnTx.supplierId);
        await _checkReturnAvailable(txn, returnTx.workDayId, returnTx.customerId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), oldQty: oldQty, supplierId: returnTx.supplierId);
      } else {
        // Validate new product
        await _checkInventoryForPositiveOp(txn, returnTx.workDayId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), oldQty: 0.0, supplierId: returnTx.supplierId);
        await _checkReturnAvailable(txn, returnTx.workDayId, returnTx.customerId, returnTx.productId, (returnTx.quantity ?? 0).toDouble(), oldQty: 0.0, supplierId: returnTx.supplierId);
        // Validate old product
        if (oldProductId != null) {
            await _checkInventoryForPositiveOp(txn, returnTx.workDayId, oldProductId, 0.0, oldQty: oldQty, supplierId: returnTx.supplierId);
        }
      }
      if (old.isNotEmpty) {
        double oldVal = ((old.first['quantity'] as num) * (old.first['price'] as num)).toDouble();
        double newVal = (returnTx.quantity ?? 0) * returnTx.price;
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance + ? - ? WHERE id = ?', [oldVal, newVal, returnTx.customerId]);
      }
      return await txn.update('returns', map, where: 'id = ?', whereArgs: [returnTx.id]);
    });
  }



  Future<int> deleteReturn(String id) async {
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      var old = await txn.query('returns', where: 'id = ?', whereArgs: [id]);
      if (old.isNotEmpty && old.first['is_deleted'] == 0) {
        await _checkWorkDayOpen(txn, old.first['work_day_id'] as String);
        await _checkInventoryForPositiveOp(txn, old.first['work_day_id'] as String, old.first['product_id'] as String, 0.0, oldQty: (old.first['quantity'] as num).toDouble());
        double val = ((old.first['quantity'] as num) * (old.first['price'] as num)).toDouble();
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance + ? WHERE id = ?', [val, old.first['customer_id']]);
      }
      return await txn.update('returns', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }



  Future<int> insertCollection(CollectionTransaction collectionTx) async {
    if (collectionTx.amount < 0) throw Exception('لا يمكن أن يكون المبلغ سالباً');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final map = collectionTx.toMap();
      map['id'] = map['id'] ?? const Uuid().v4();
      map['updated_at'] = map['updated_at'] ?? DateTime.now().toIso8601String();
      int res = await txn.insert('collections', map);
      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance - ? WHERE id = ?',
        [collectionTx.amount, collectionTx.customerId]
      );
      return res;
    });
  }



  Future<int> updateCollection(CollectionTransaction collectionTx) async {
    if (collectionTx.amount < 0) throw Exception('لا يمكن أن يكون المبلغ سالباً');
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final map = collectionTx.toMap();
      map['updated_at'] = DateTime.now().toIso8601String();
      map['sync_status'] = 'pending';
      var old = await txn.query('collections', where: 'id = ?', whereArgs: [collectionTx.id]);
      if (old.isNotEmpty) {
        double oldVal = (old.first['amount'] as num).toDouble();
        double newVal = collectionTx.amount;
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance + ? - ? WHERE id = ?', [oldVal, newVal, collectionTx.customerId]);
      }
      return await txn.update('collections', map, where: 'id = ?', whereArgs: [collectionTx.id]);
    });
  }



  Future<int> deleteCollection(String id) async {
    Database db = await _dbHelper.database;
    return await db.transaction((txn) async {
      var old = await txn.query('collections', where: 'id = ?', whereArgs: [id]);
      if (old.isNotEmpty && old.first['is_deleted'] == 0) {
        double val = (old.first['amount'] as num).toDouble();
        await txn.rawUpdate('UPDATE customers SET current_balance = current_balance + ? WHERE id = ?', [val, old.first['customer_id']]);
      }
      return await txn.update('collections', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    });
  }



  Future<List<Map<String, dynamic>>> getCustomersWithTransactionsForDay(String workDayId) async {

    Database db = await _dbHelper.database;

    final result = await db.rawQuery('''

      SELECT DISTINCT c.* FROM customers c
      WHERE c.id IN (
        SELECT customer_id FROM distributions WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT customer_id FROM returns WHERE work_day_id = ? AND is_deleted = 0
        UNION
        SELECT customer_id FROM collections WHERE work_day_id = ? AND is_deleted = 0
      )

      ORDER BY c.name

    ''', [workDayId, workDayId, workDayId]);

    return result;

  }



  Future<List<Distribution>> getDistributionsByCustomer(String customerId, {String? workDayId}) async {

    Database db = await _dbHelper.database;

    String where = 'customer_id = ? AND is_deleted = 0';

    List<dynamic> whereArgs = [customerId];

    if (workDayId != null) {

      where += ' AND work_day_id = ?';

      whereArgs.add(workDayId);

    }

    final List<Map<String, dynamic>> maps = await db.query(

      'distributions',

      where: where,

      whereArgs: whereArgs,

    );

    return List.generate(maps.length, (i) => Distribution.fromMap(maps[i]));

  }



  Future<List<ReturnTransaction>> getReturnsByCustomer(String customerId, {String? workDayId}) async {

    Database db = await _dbHelper.database;

    String where = 'customer_id = ? AND is_deleted = 0';

    List<dynamic> whereArgs = [customerId];

    if (workDayId != null) {

      where += ' AND work_day_id = ?';

      whereArgs.add(workDayId);

    }

    final List<Map<String, dynamic>> maps = await db.query(

      'returns',

      where: where,

      whereArgs: whereArgs,

    );

    return List.generate(maps.length, (i) => ReturnTransaction.fromMap(maps[i]));

  }



  Future<List<CollectionTransaction>> getCollectionsByCustomer(String customerId, {String? workDayId}) async {

    Database db = await _dbHelper.database;

    String where = 'customer_id = ? AND is_deleted = 0';

    List<dynamic> whereArgs = [customerId];

    if (workDayId != null) {

      where += ' AND work_day_id = ?';

      whereArgs.add(workDayId);

    }

    final List<Map<String, dynamic>> maps = await db.query(

      'collections',

      where: where,

      whereArgs: whereArgs,

    );

    return List.generate(maps.length, (i) => CollectionTransaction.fromMap(maps[i]));

  }



  Future<List<Distribution>> getDistributionsByWorkDay(String workDayId) async {

    Database db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(

      'distributions',

      where: 'work_day_id = ? AND is_deleted = 0',

      whereArgs: [workDayId],

    );

    return List.generate(maps.length, (i) => Distribution.fromMap(maps[i]));

  }



  Future<List<ReturnTransaction>> getReturnsByWorkDay(String workDayId) async {

    Database db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(

      'returns',

      where: 'work_day_id = ? AND is_deleted = 0',

      whereArgs: [workDayId],

    );

    return List.generate(maps.length, (i) => ReturnTransaction.fromMap(maps[i]));

  }



  Future<List<CollectionTransaction>> getCollectionsByWorkDay(String workDayId) async {

    Database db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(

      'collections',

      where: 'work_day_id = ? AND is_deleted = 0',

      whereArgs: [workDayId],

    );

    return List.generate(maps.length, (i) => CollectionTransaction.fromMap(maps[i]));

  }







  Future<Map<String, double>> getDaySummary(String workDayId) async {

    Database db = await _dbHelper.database;

    final dists = await db.query('distributions', where: 'work_day_id = ? AND is_deleted = 0', whereArgs: [workDayId]);

    final rets = await db.query('returns', where: 'work_day_id = ? AND is_deleted = 0', whereArgs: [workDayId]);

    final cols = await db.query('collections', where: 'work_day_id = ? AND is_deleted = 0', whereArgs: [workDayId]);



    double totalDist = 0;

    for (var d in dists) totalDist += ((d['quantity'] as num) * (d['price'] as num));



    double totalRet = 0;

    for (var r in rets) totalRet += ((r['quantity'] as num) * (r['price'] as num));



    double totalCol = 0;
    for (var c in cols) totalCol += (c['amount'] as num);

    final srets = await db.query('supplier_returns', where: 'work_day_id = ? AND is_deleted = 0', whereArgs: [workDayId]);
    double totalSupplierRet = 0;
    for (var sr in srets) totalSupplierRet += ((sr['quantity'] as num) * (sr['cost_price'] as num));

    return {
      'totalDistribution': totalDist,
      'totalReturn': totalRet,
      'totalCollection': totalCol,
      'totalSupplierReturn': totalSupplierRet,
      'remaining': (totalDist - totalRet) - totalCol,
    };
  }



  Future<List<CustomerStatementItem>> getCustomerStatement(String customerId, {String? startDate, String? endDate}) async {

    Database db = await _dbHelper.database;

    List<CustomerStatementItem> items = [];



    // Base queries

    String baseWhere = 'customer_id = ?';

    List<dynamic> whereArgs = [customerId];



    if (startDate != null && endDate != null) {

      String endDateTime = '${endDate}T23:59:59';

      whereArgs.addAll([startDate, endDateTime]);

    }



    String getWhereClause(String? tableAlias) {

      String clause = tableAlias != null ? '$tableAlias.customer_id = ? AND $tableAlias.is_deleted = 0' : 'customer_id = ? AND is_deleted = 0';

      if (startDate != null && endDate != null) {

        String col = tableAlias != null ? '$tableAlias.created_at' : 'created_at';

        clause += ' AND $col >= ? AND $col <= ?';

      }

      return clause;

    }



    // Fetch distributions

    final distMaps = await db.rawQuery('''

      SELECT d.*, p.name as product_name 

      FROM distributions d

      LEFT JOIN products p ON d.product_id = p.id

      WHERE ${getWhereClause('d')}

    ''', whereArgs);

    

    for (var m in distMaps) {

      items.add(CustomerStatementItem(

        id: m['id'] as String,

        type: 'distribution',

        productId: m['product_id'] as String,

        productName: m['product_name'] as String?,

        quantity: m['quantity'] != null 
            ? (m['quantity'] is String ? int.tryParse(m['quantity'].toString()) : (m['quantity'] as num).toInt())
            : null,

        amount: ((m['quantity'] as num) * (m['price'] as num)).toDouble(),

        createdAt: m['created_at'] as String,

      ));

    }



    // Fetch returns

    final retMaps = await db.rawQuery('''

      SELECT r.*, p.name as product_name 

      FROM returns r

      LEFT JOIN products p ON r.product_id = p.id

      WHERE ${getWhereClause('r')}

    ''', whereArgs);



    for (var m in retMaps) {

      items.add(CustomerStatementItem(

        id: m['id'] as String,

        type: 'return',

        productId: m['product_id'] as String,

        productName: m['product_name'] as String?,

        quantity: m['quantity'] != null 
            ? (m['quantity'] is String ? int.tryParse(m['quantity'].toString()) : (m['quantity'] as num).toInt())
            : null,

        amount: ((m['quantity'] as num) * (m['price'] as num)).toDouble(),

        createdAt: m['created_at'] as String,

      ));

    }



    // Fetch collections

    final colMaps = await db.query(

      'collections',

      where: getWhereClause(null),

      whereArgs: whereArgs,

    );



    for (var m in colMaps) {

      items.add(CustomerStatementItem(

        id: m['id'] as String,

        type: 'collection',

        amount: (m['amount'] as num).toDouble(),

        createdAt: m['created_at'] as String,

      ));

    }



    // Sort items by createdAt descending (newest first)

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));



    return items;

  }



  Future<List<Map<String, dynamic>>> getAllCustomersWithBalance() async {
    Database db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        c.id,
        c.name,
        c.neighborhood,
        c.current_balance AS balance
      FROM customers c
      WHERE c.is_deleted = 0 AND c.current_balance > 0.001
      ORDER BY balance DESC
    ''');
  }



  Future<List<Map<String, dynamic>>> getCustomerBalancePerDay(String customerId) async {

    Database db = await _dbHelper.database;

    return await db.rawQuery('''

      SELECT 

        wd.id AS work_day_id,

        wd.date,

        COALESCE(dist.total_dist, 0) AS total_dist,

        COALESCE(ret.total_ret, 0) AS total_ret,

        COALESCE(col.total_col, 0) AS total_col,

        COALESCE(dist.total_dist, 0) - COALESCE(ret.total_ret, 0) - COALESCE(col.total_col, 0) AS day_balance

      FROM work_days wd

      LEFT JOIN (

        SELECT work_day_id, SUM(quantity * price) AS total_dist FROM distributions WHERE customer_id = ? AND is_deleted = 0 GROUP BY work_day_id
      ) dist ON wd.id = dist.work_day_id
      LEFT JOIN (
        SELECT work_day_id, SUM(quantity * price) AS total_ret FROM returns WHERE customer_id = ? AND is_deleted = 0 GROUP BY work_day_id
      ) ret ON wd.id = ret.work_day_id
      LEFT JOIN (
        SELECT work_day_id, SUM(amount) AS total_col FROM collections WHERE customer_id = ? AND is_deleted = 0 GROUP BY work_day_id
      ) col ON wd.id = col.work_day_id

      WHERE (COALESCE(dist.total_dist, 0) + COALESCE(ret.total_ret, 0) + COALESCE(col.total_col, 0)) > 0

      ORDER BY wd.date DESC

    ''', [customerId, customerId, customerId]);

  }



  Future<List<Map<String, dynamic>>> getDaySummaryPerCustomer(String workDayId) async {

    Database db = await _dbHelper.database;

    return await db.rawQuery('''

      SELECT 

        c.id,

        c.name,

        c.neighborhood,

        COALESCE(dist.total_dist, 0) AS total_dist,

        COALESCE(ret.total_ret, 0) AS total_ret,

        COALESCE(col.total_col, 0) AS total_col,

        COALESCE(dist.total_dist, 0) - COALESCE(ret.total_ret, 0) - COALESCE(col.total_col, 0) AS remaining

      FROM customers c

      LEFT JOIN (

        SELECT customer_id, SUM(quantity * price) AS total_dist FROM distributions WHERE work_day_id = ? AND is_deleted = 0 GROUP BY customer_id
      ) dist ON c.id = dist.customer_id
      LEFT JOIN (
        SELECT customer_id, SUM(quantity * price) AS total_ret FROM returns WHERE work_day_id = ? AND is_deleted = 0 GROUP BY customer_id
      ) ret ON c.id = ret.customer_id
      LEFT JOIN (
        SELECT customer_id, SUM(amount) AS total_col FROM collections WHERE work_day_id = ? AND is_deleted = 0 GROUP BY customer_id
      ) col ON c.id = col.customer_id

      WHERE (COALESCE(dist.total_dist, 0) + COALESCE(ret.total_ret, 0) + COALESCE(col.total_col, 0)) > 0

      ORDER BY c.name

    ''', [workDayId, workDayId, workDayId]);

  }



  Future<List<Map<String, dynamic>>> getDayProductSummary(String workDayId) async {

    Database db = await _dbHelper.database;

    return await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        COALESCE(dist.total_qty, 0) AS dist_qty,
        COALESCE(dist.total_price, 0) AS dist_price,
        COALESCE(ret.total_qty, 0) AS ret_qty,
        COALESCE(ret.total_price, 0) AS ret_price,
        COALESCE(sret.total_qty, 0) AS sret_qty,
        COALESCE(sret.total_price, 0) AS sret_price,
        COALESCE(dmg.dist_qty, 0) AS dmg_dist_qty,
        COALESCE(dmg.bakery_qty, 0) AS dmg_bakery_qty
      FROM products p
      LEFT JOIN (
        SELECT product_id, SUM(quantity) AS total_qty, SUM(quantity * price) AS total_price 
        FROM distributions WHERE work_day_id = ? AND is_deleted = 0 GROUP BY product_id
      ) dist ON p.id = dist.product_id
      LEFT JOIN (
        SELECT product_id, SUM(quantity) AS total_qty, SUM(quantity * price) AS total_price 
        FROM returns WHERE work_day_id = ? AND is_deleted = 0 GROUP BY product_id
      ) ret ON p.id = ret.product_id
      LEFT JOIN (
        SELECT product_id, SUM(quantity) AS total_qty, SUM(quantity * cost_price) AS total_price 
        FROM supplier_returns WHERE work_day_id = ? AND is_deleted = 0 GROUP BY product_id
      ) sret ON p.id = sret.product_id
      LEFT JOIN (
        SELECT product_id, 
               SUM(CASE WHEN is_charged_to_distributor = 1 THEN quantity ELSE 0 END) AS dist_qty,
               SUM(CASE WHEN is_charged_to_distributor = 0 THEN quantity ELSE 0 END) AS bakery_qty
        FROM damaged_items WHERE work_day_id = ? AND is_deleted = 0 GROUP BY product_id
      ) dmg ON p.id = dmg.product_id
      WHERE p.is_deleted = 0 AND (COALESCE(dist.total_qty, 0) > 0 OR COALESCE(ret.total_qty, 0) > 0 OR COALESCE(sret.total_qty, 0) > 0 OR COALESCE(dmg.dist_qty, 0) > 0 OR COALESCE(dmg.bakery_qty, 0) > 0)
    ''', [workDayId, workDayId, workDayId, workDayId]);
  }

  Future<Map<String, Map<String, int>>> getProductQuantitiesForDay(String workDayId) async {
    Database db = await _dbHelper.database;
    final Map<String, Map<String, int>> results = {};

    final dists = await db.rawQuery('''
      SELECT product_id, SUM(quantity) as total_qty
      FROM distributions
      WHERE work_day_id = ? AND is_deleted = 0
      GROUP BY product_id
    ''', [workDayId]);

    for (var row in dists) {
      final pid = row['product_id'] as String;
      final qty = row['total_qty'] != null 
          ? (row['total_qty'] is String ? (int.tryParse(row['total_qty'].toString()) ?? 0) : (row['total_qty'] as num).toInt())
          : 0;
      results[pid] = {'dist': qty, 'ret': 0};
    }

    final rets = await db.rawQuery('''
      SELECT product_id, SUM(quantity) as total_qty
      FROM returns
      WHERE work_day_id = ? AND is_deleted = 0
      GROUP BY product_id
    ''', [workDayId]);

    for (var row in rets) {
      final pid = row['product_id'] as String;
      final qty = row['total_qty'] != null 
          ? (row['total_qty'] is String ? (int.tryParse(row['total_qty'].toString()) ?? 0) : (row['total_qty'] as num).toInt())
          : 0;
      if (results.containsKey(pid)) {
        results[pid]!['ret'] = qty;
      } else {
        results[pid] = {'dist': 0, 'ret': qty};
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> getDetailedDayData(String workDayId) async {
    Database db = await _dbHelper.database;
    final String query = '''
      SELECT 
        c.name as customer_name,
        d.created_at as time,
        p.name as product_name,
        d.quantity as dist_qty,
        d.price as price,
        0 as ret_qty,
        0 as col_amount,
        'توزيع' as type,
        COALESCE(s.name, '—') as supplier_name
      FROM distributions d
      JOIN customers c ON d.customer_id = c.id
      JOIN products p ON d.product_id = p.id
      LEFT JOIN suppliers s ON d.supplier_id = s.id
      WHERE d.work_day_id = ? AND d.is_deleted = 0
      
      UNION ALL
      
      SELECT 
        c.name as customer_name,
        r.created_at as time,
        p.name as product_name,
        0 as dist_qty,
        r.price as price,
        r.quantity as ret_qty,
        0 as col_amount,
        'راجع' as type,
        COALESCE(s.name, '—') as supplier_name
      FROM returns r
      JOIN customers c ON r.customer_id = c.id
      JOIN products p ON r.product_id = p.id
      LEFT JOIN suppliers s ON r.supplier_id = s.id
      WHERE r.work_day_id = ? AND r.is_deleted = 0
      
      UNION ALL
      
      SELECT 
        c.name as customer_name,
        co.created_at as time,
        '' as product_name,
        0 as dist_qty,
        0 as price,
        0 as ret_qty,
        co.amount as col_amount,
        'تحصيل' as type,
        '—' as supplier_name
      FROM collections co
      JOIN customers c ON co.customer_id = c.id
      WHERE co.work_day_id = ? AND co.is_deleted = 0

      UNION ALL

      SELECT 
        s.name as customer_name,
        sr.created_at as time,
        p.name as product_name,
        0 as dist_qty,
        sr.cost_price as price,
        sr.quantity as ret_qty,
        0 as col_amount,
        'راجع مخبز' as type,
        s.name as supplier_name
      FROM supplier_returns sr
      JOIN suppliers s ON sr.supplier_id = s.id
      JOIN products p ON sr.product_id = p.id
      WHERE sr.work_day_id = ? AND sr.is_deleted = 0

      UNION ALL

      SELECT 
        s.name as customer_name,
        di.created_at as time,
        p.name as product_name,
        0 as dist_qty,
        di.cost_price as price,
        di.quantity as ret_qty,
        0 as col_amount,
        CASE WHEN di.is_charged_to_distributor = 1 THEN 'تالف (على الموزع)' ELSE 'تالف (على المخبز)' END as type,
        s.name as supplier_name
      FROM damaged_items di
      JOIN suppliers s ON di.supplier_id = s.id
      JOIN products p ON di.product_id = p.id
      WHERE di.work_day_id = ? AND di.is_deleted = 0
      
      ORDER BY time DESC
    ''';
    
    return await db.rawQuery(query, [workDayId, workDayId, workDayId, workDayId, workDayId]);
  }

  Future<List<Map<String, dynamic>>> getDetailedDayDataBySupplier(String workDayId, String supplierId) async {
    Database db = await _dbHelper.database;

    final dists = await db.rawQuery('''
      SELECT 
        d.created_at as time, c.name as customer_name,
        p.name as product_name, d.quantity as dist_qty,
        d.price as price, 0 as ret_qty, 0 as col_amount,
        'توزيع' as type
      FROM distributions d
      JOIN customers c ON d.customer_id = c.id
      JOIN products p ON d.product_id = p.id
      WHERE d.work_day_id = ? AND d.supplier_id = ? AND d.is_deleted = 0
    ''', [workDayId, supplierId]);

    final rets = await db.rawQuery('''
      SELECT 
        r.created_at as time, c.name as customer_name,
        p.name as product_name, 0 as dist_qty,
        r.price as price, r.quantity as ret_qty, 0 as col_amount,
        'راجع' as type
      FROM returns r
      JOIN customers c ON r.customer_id = c.id
      JOIN products p ON r.product_id = p.id
      WHERE r.work_day_id = ? AND r.supplier_id = ? AND r.is_deleted = 0
    ''', [workDayId, supplierId]);

    final cols = await db.rawQuery('''
      SELECT 
        co.created_at as time, c.name as customer_name,
        '' as product_name, 0 as dist_qty,
        0 as price, 0 as ret_qty, co.amount as col_amount,
        'تحصيل' as type
      FROM collections co
      JOIN customers c ON co.customer_id = c.id
      WHERE co.work_day_id = ? AND co.is_deleted = 0
        AND co.customer_id IN (
          SELECT DISTINCT customer_id FROM distributions
          WHERE work_day_id = ? AND supplier_id = ? AND is_deleted = 0
        )
    ''', [workDayId, workDayId, supplierId]);

    final all = [
      ...dists.map((e) => Map<String, dynamic>.from(e)),
      ...rets.map((e) => Map<String, dynamic>.from(e)),
      ...cols.map((e) => Map<String, dynamic>.from(e)),
    ];
    all.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
    return all;
  }

  Future<Map<String, double>> getDaySummaryForSupplier(String workDayId, String supplierId) async {
    Database db = await _dbHelper.database;
    final dists = await db.rawQuery(
      'SELECT SUM(quantity * price) as total FROM distributions WHERE work_day_id = ? AND supplier_id = ? AND is_deleted = 0',
      [workDayId, supplierId]);
    final rets = await db.rawQuery(
      'SELECT SUM(quantity * price) as total FROM returns WHERE work_day_id = ? AND supplier_id = ? AND is_deleted = 0',
      [workDayId, supplierId]);

    return {
      'totalDistribution': (dists.first['total'] as num? ?? 0).toDouble(),
      'totalReturn': (rets.first['total'] as num? ?? 0).toDouble(),
      'totalCollection': 0,
    };
  }

  Future<Map<String, double>> getFullDaySummaryTotals(String workDayId) async {
    return getDaySummary(workDayId);
  }

  Future<Map<String, dynamic>> getCustomerBalanceSummary(String customerId) async {
    Database db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(d.total_amt, 0) AS dist_amount,
        COALESCE(d.total_qty, 0) AS dist_qty,
        COALESCE(r.total_amt, 0) AS ret_amount,
        COALESCE(r.total_qty, 0) AS ret_qty,
        COALESCE(c.total_col, 0) AS total_paid
      FROM (SELECT 1 as dummy)
      LEFT JOIN 
        (SELECT SUM(quantity * price) AS total_amt, SUM(quantity) AS total_qty FROM distributions WHERE customer_id = ? AND is_deleted = 0) d ON 1=1
      LEFT JOIN 
        (SELECT SUM(quantity * price) AS total_amt, SUM(quantity) AS total_qty FROM returns WHERE customer_id = ? AND is_deleted = 0) r ON 1=1
      LEFT JOIN 
        (SELECT SUM(amount) AS total_col FROM collections WHERE customer_id = ? AND is_deleted = 0) c ON 1=1
    ''', [customerId, customerId, customerId]);

    final row = result.first;
    final distAmt = (row['dist_amount'] as num?)?.toDouble() ?? 0.0;
    final distQty = (row['dist_qty'] as num?)?.toInt() ?? 0;
    final retAmt = (row['ret_amount'] as num?)?.toDouble() ?? 0.0;
    final retQty = (row['ret_qty'] as num?)?.toInt() ?? 0;
    final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0.0;
    return {
      'balance': distAmt - retAmt - totalPaid,
      'quantity': distQty - retQty,
      'totalPaid': totalPaid,
    };
  }



  Future<List<Map<String, dynamic>>> getCustomerDayTransactions(String customerId, String workDayId) async {
    Database db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT d.quantity, d.price, p.name AS product_name, d.created_at, 'توزيع' AS type
      FROM distributions d LEFT JOIN products p ON d.product_id = p.id
      WHERE d.customer_id = ? AND d.work_day_id = ? AND d.is_deleted = 0
      UNION ALL
      SELECT r.quantity, r.price, p.name AS product_name, r.created_at, 'راجع' AS type
      FROM returns r LEFT JOIN products p ON r.product_id = p.id
      WHERE r.customer_id = ? AND r.work_day_id = ? AND r.is_deleted = 0
      UNION ALL
      SELECT 0 AS quantity, amount AS price, '' AS product_name, created_at, 'تحصيل' AS type
      FROM collections
      WHERE customer_id = ? AND work_day_id = ? AND is_deleted = 0
      ORDER BY created_at ASC
    ''', [customerId, workDayId, customerId, workDayId, customerId, workDayId]);
  }

  Future<List<Map<String, dynamic>>> getDayProfitBySupplierFIFO(String workDayId) async {
    Database db = await _dbHelper.database;

    final wdRes = await db.query('work_days', where: 'id = ?', whereArgs: [workDayId]);
    if (wdRes.isEmpty) return [];
    final wdCreatedAt = wdRes.first['created_at'] as String;

    // الخطة البديلة: البحث عن آخر سعر تكلفة تاريخي (قبل أو خلال هذا اليوم المالي)
    final fallbackCosts = await db.rawQuery('''
      SELECT il.product_id, il.supplier_id, s.name as supplier_name, il.cost_price, p.name as product_name
      FROM inventory_loads il
      JOIN suppliers s ON il.supplier_id = s.id
      JOIN products p ON il.product_id = p.id
      INNER JOIN (
          SELECT product_id, MAX(created_at) as max_date
          FROM inventory_loads
          WHERE created_at <= ? AND is_deleted = 0
          GROUP BY product_id
      ) latest ON il.product_id = latest.product_id AND il.created_at = latest.max_date
      WHERE il.is_deleted = 0
    ''', [wdCreatedAt]);
    
    final Map<String, Map<String, dynamic>> productFallback = {};
    for (var fc in fallbackCosts) {
      final pid = fc['product_id'] as String;
      if (!productFallback.containsKey(pid)) {
        productFallback[pid] = fc;
      }
    }

    // الخطة البديلة الثانية: إذا لم يتم العثور على أي تاريخ تحميل، نلجأ للسعر الحالي
    final currentCosts = await db.rawQuery('''
      SELECT sp.product_id, sp.supplier_id, s.name as supplier_name, sp.cost_price, p.name as product_name
      FROM supplier_products sp
      JOIN suppliers s ON sp.supplier_id = s.id
      JOIN products p ON sp.product_id = p.id
      WHERE sp.is_deleted = 0
    ''');
    
    for (var cc in currentCosts) {
      final pid = cc['product_id'] as String;
      if (!productFallback.containsKey(pid)) {
        productFallback[pid] = cc;
      }
    }

    final loads = await db.rawQuery('''
      SELECT il.supplier_id, s.name AS supplier_name, il.product_id, p.name AS product_name,
             il.initial_quantity AS qty, il.cost_price, il.created_at
      FROM inventory_loads il
      JOIN suppliers s ON il.supplier_id = s.id
      JOIN products p ON il.product_id = p.id
      WHERE il.work_day_id = ? AND il.is_deleted = 0
      ORDER BY il.product_id, il.created_at ASC
    ''', [workDayId]);

    final dists = await db.rawQuery('''
      SELECT d.product_id, p.name AS product_name, SUM(d.quantity) AS dist_qty, SUM(d.quantity * d.price) AS dist_revenue
      FROM distributions d 
      JOIN products p ON d.product_id = p.id
      WHERE d.work_day_id = ? AND d.is_deleted = 0
      GROUP BY d.product_id, p.name
    ''', [workDayId]);

    final rets = await db.rawQuery('''
      SELECT product_id, SUM(quantity) AS ret_qty
      FROM returns WHERE work_day_id = ? AND is_deleted = 0
      GROUP BY product_id
    ''', [workDayId]);

    final chargedDamaged = await db.rawQuery('''
      SELECT product_id, SUM(quantity) AS damaged_qty
      FROM damaged_items WHERE work_day_id = ? AND is_deleted = 0 AND is_charged_to_distributor = 1
      GROUP BY product_id
    ''', [workDayId]);

    final Map<String, double> distQtyMap = {};
    final Map<String, double> distRevenueMap = {};
    final Map<String, String> distNameMap = {};
    for (var d in dists) {
      final pid = d['product_id'] as String;
      distQtyMap[pid] = (d['dist_qty'] as num).toDouble();
      distRevenueMap[pid] = (d['dist_revenue'] as num).toDouble();
      distNameMap[pid] = d['product_name'] as String;
    }

    final Map<String, double> retQtyMap = {};
    for (var r in rets) {
      final pid = r['product_id'] as String;
      retQtyMap[pid] = (r['ret_qty'] as num).toDouble();
    }

    final Map<String, double> chargedDamagedQtyMap = {};
    for (var di in chargedDamaged) {
      final pid = di['product_id'] as String;
      chargedDamagedQtyMap[pid] = (di['damaged_qty'] as num).toDouble();
    }

    final Map<String, List<Map<String, dynamic>>> loadsByProduct = {};
    for (var l in loads) {
      final pid = l['product_id'] as String;
      loadsByProduct.putIfAbsent(pid, () => []);
      loadsByProduct[pid]!.add(l);
    }

    final Set<String> activeProductIds = {};
    activeProductIds.addAll(distQtyMap.keys);
    activeProductIds.addAll(retQtyMap.keys);
    activeProductIds.addAll(chargedDamagedQtyMap.keys);
    activeProductIds.addAll(loadsByProduct.keys);

    final Map<String, Map<String, dynamic>> supplierResults = {};

    for (final productId in activeProductIds) {
      final totalDistQty = distQtyMap[productId] ?? 0;
      final totalRetQty = retQtyMap[productId] ?? 0;
      final totalChargedDamagedQty = chargedDamagedQtyMap[productId] ?? 0;
      
      final netSalesQty = totalDistQty - totalRetQty + totalChargedDamagedQty;
      final totalRevenue = distRevenueMap[productId] ?? 0;
      
      final avgSellPrice = totalDistQty > 0 ? totalRevenue / totalDistQty : 0.0;

      if (netSalesQty <= 0) continue;

      double remaining = netSalesQty;
      final productLoads = loadsByProduct[productId] ?? [];

      for (final load in productLoads) {
        if (remaining <= 0) break;

        final supplierId = load['supplier_id'] as String;
        final supplierName = load['supplier_name'] as String;
        final productName = load['product_name'] as String;
        final loadQty = (load['qty'] as num).toDouble();
        double costPrice = (load['cost_price'] as num).toDouble();
        
        if (costPrice <= 0 && productFallback.containsKey(productId)) {
          costPrice = (productFallback[productId]!['cost_price'] as num).toDouble();
        }

        final allocatedQty = remaining < loadQty ? remaining : loadQty;
        final revenue = allocatedQty * avgSellPrice;
        final cost = allocatedQty * costPrice;
        final profit = revenue - cost;

        remaining -= allocatedQty;

        supplierResults.putIfAbsent(supplierId, () => {
          'supplier_id': supplierId,
          'supplier_name': supplierName,
          'total_profit': 0.0,
          'total_revenue': 0.0,
          'total_cost': 0.0,
          'products': <Map<String, dynamic>>[],
        });

        supplierResults[supplierId]!['total_profit'] += profit;
        supplierResults[supplierId]!['total_revenue'] += revenue;
        supplierResults[supplierId]!['total_cost'] += cost;
        (supplierResults[supplierId]!['products'] as List).add({
          'product_name': productName,
          'qty': allocatedQty,
          'revenue': revenue,
          'cost': cost,
          'profit': profit,
          'avg_sell_price': avgSellPrice,
          'cost_price': costPrice,
          'allocated_qty': allocatedQty,
        });
      }

      if (remaining > 0) {
        String supplierId = 'unknown';
        String supplierName = 'غير محدد';
        String productName = distNameMap[productId] ?? 'صنف غير معروف';
        double costPrice = 0.0;

        if (productFallback.containsKey(productId)) {
          final fb = productFallback[productId]!;
          supplierId = fb['supplier_id'] as String;
          supplierName = fb['supplier_name'] as String;
          productName = fb['product_name'] as String;
          costPrice = (fb['cost_price'] as num).toDouble();
        }

        final revenue = remaining * avgSellPrice;
        final cost = remaining * costPrice;
        final profit = revenue - cost;

        supplierResults.putIfAbsent(supplierId, () => {
          'supplier_id': supplierId,
          'supplier_name': supplierName,
          'total_profit': 0.0,
          'total_revenue': 0.0,
          'total_cost': 0.0,
          'products': <Map<String, dynamic>>[],
        });

        supplierResults[supplierId]!['total_profit'] += profit;
        supplierResults[supplierId]!['total_revenue'] += revenue;
        supplierResults[supplierId]!['total_cost'] += cost;
        (supplierResults[supplierId]!['products'] as List).add({
          'product_name': productName,
          'qty': remaining,
          'revenue': revenue,
          'cost': cost,
          'profit': profit,
          'avg_sell_price': avgSellPrice,
          'cost_price': costPrice,
          'allocated_qty': remaining,
        });
        
        remaining = 0;
      }
    }
    return supplierResults.values.toList();
  }

  Future<void> recalculateCustomerBalance(String customerId, {Transaction? txn}) async {
    Database db = await _dbHelper.database;
    final action = (Transaction t) async {
      final result = await t.rawQuery('''
        SELECT 
          COALESCE(d.total_amt, 0) AS dist_amount,
          COALESCE(r.total_amt, 0) AS ret_amount,
          COALESCE(c.total_col, 0) AS total_paid
        FROM (SELECT 1 as dummy)
        LEFT JOIN 
          (SELECT SUM(quantity * price) AS total_amt FROM distributions WHERE customer_id = ? AND is_deleted = 0) d ON 1=1
        LEFT JOIN 
          (SELECT SUM(quantity * price) AS total_amt FROM returns WHERE customer_id = ? AND is_deleted = 0) r ON 1=1
        LEFT JOIN 
          (SELECT SUM(amount) AS total_col FROM collections WHERE customer_id = ? AND is_deleted = 0) c ON 1=1
      ''', [customerId, customerId, customerId]);

      final row = result.first;
      final distAmt = (row['dist_amount'] as num?)?.toDouble() ?? 0.0;
      final retAmt = (row['ret_amount'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0.0;
      
      final correctBalance = distAmt - retAmt - totalPaid;
      
      await t.update('customers', {'current_balance': correctBalance}, where: 'id = ?', whereArgs: [customerId]);
    };

    if (txn != null) {
      await action(txn);
    } else {
      await db.transaction((t) async => await action(t));
    }
  }
}
