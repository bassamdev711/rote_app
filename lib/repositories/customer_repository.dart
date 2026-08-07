import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/customer.dart';
import '../models/customer_price.dart';

class CustomerRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<String> insert(Customer customer) async {
    Database db = await _dbHelper.database;
    final map = customer.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    await db.insert('customers', map);
    return id;
  }

  Future<List<Customer>> getAll({int? limit, int? offset}) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers', 
      where: 'is_deleted = 0',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) {
      return Customer.fromMap(maps[i]);
    });
  }

  Future<int> update(Customer customer) async {
    Database db = await _dbHelper.database;
    final map = customer.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    return await db.update(
      'customers',
      map,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> delete(String id) async {
    Database db = await _dbHelper.database;
    final distributions = await db.query('distributions', where: 'customer_id = ?', whereArgs: [id], limit: 1);
    final returns = await db.query('returns', where: 'customer_id = ?', whereArgs: [id], limit: 1);
    final collections = await db.query('collections', where: 'customer_id = ?', whereArgs: [id], limit: 1);
    
    if (distributions.isNotEmpty || returns.isNotEmpty || collections.isNotEmpty) {
      throw Exception('لا يمكن حذف العميل لوجود حركات مالية أو عمليات سابقة مرتبطة به للحفاظ على سلامة الحسابات.');
    }
    
    return await db.update('customers', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id],
    );
  }

  Future<void> saveCustomerPrices(String customerId, List<CustomerPrice> prices) async {
    Database db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('customer_prices', where: 'customer_id = ?', whereArgs: [customerId]);
      for (var price in prices) {
        final map = price.toMap(); 
        map['id'] = map['id'] ?? const Uuid().v4(); 
        map['created_at'] = map['created_at'] ?? DateTime.now().toUtc().toIso8601String();
        map['updated_at'] = map['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
        await txn.insert('customer_prices', map);
      }
    });
  }

  Future<List<CustomerPrice>> getCustomerPrices(String customerId) async {
    Database db = await _dbHelper.database;
    final maps = await db.query('customer_prices', where: 'customer_id = ?', whereArgs: [customerId]);
    return maps.map((map) => CustomerPrice.fromMap(map)).toList();
  }

  Future<CustomerPrice?> getCustomerPrice(String customerId, String productId) async {
    Database db = await _dbHelper.database;
    final maps = await db.query('customer_prices', 
      where: 'customer_id = ? AND product_id = ?', 
      whereArgs: [customerId, productId]);
    if (maps.isNotEmpty) {
      return CustomerPrice.fromMap(maps.first);
    }
    return null;
  }
}
