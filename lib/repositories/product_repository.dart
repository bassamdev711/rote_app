import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database/db_helper.dart';
import '../models/product.dart';

class ProductRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<String> insert(Product product) async {
    Database db = await _dbHelper.database;
    final map = product.toMap();
    final String id = map['id'] ?? const Uuid().v4();
    map['id'] = id;
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    await db.insert('products', map);
    return id;
  }

  Future<List<Product>> getAll({int? limit, int? offset}) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products', 
      where: 'is_deleted = 0',
      orderBy: 'name ASC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  Future<int> update(Product product) async {
    Database db = await _dbHelper.database;
    final map = product.toMap();
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    map['sync_status'] = 'pending';
    return await db.update(
      'products',
      map,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> delete(String id) async {
    Database db = await _dbHelper.database;
    return await db.update('products', {'is_deleted': 1, 'sync_status': 'pending', 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
