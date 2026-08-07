import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

class DBHelper {
  static const String _databaseName = "roti_app_v2.db";
  static const int _databaseVersion = 8;

  // Singleton instance
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // ─── مسح قاعدة البيانات ──────────────────────────────────────────
  static Future<void> clearDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    await deleteDatabase(path);
  }


  // ─── مفتاح التشفير ────────────────────────────────────────────
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAlias = 'roti_db_encryption_key';

  /// يجلب مفتاح التشفير من الخزنة الآمنة، أو يولّد واحداً جديداً إذا لم يوجد
  static Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _storage.read(key: _keyAlias);
    if (key != null && key.isNotEmpty) return key;
    // توليد مفتاح عشوائي 128-char (UUID x2) وحفظه
    key = const Uuid().v4() + const Uuid().v4();
    await _storage.write(key: _keyAlias, value: key);
    return key;
  }

  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    final encKey = await _getOrCreateEncryptionKey();

    try {
      return await openDatabase(
        path,
        password: encKey,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stack) {
      print('==== DATABASE OPEN ERROR ====');
      print(e);
      print(stack);
      
      try {
        // قاعدة بيانات قديمة غير مشفرة — نشفّرها الآن
        final plainDb = await openDatabase(path);
        await plainDb.execute("PRAGMA rekey='$encKey'");
        await plainDb.close();
        
        // إعادة الفتح بالمفتاح الجديد
        return await openDatabase(
          path,
          password: encKey,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      } catch (innerE, innerStack) {
        print('==== INNER DATABASE OPEN ERROR ====');
        print(innerE);
        print(innerStack);
        // The encryption key was likely lost or the file is irrecoverably corrupted.
        // Delete the corrupted database and start fresh.
        await deleteDatabase(path);
        
        // Re-open fresh database
        return await openDatabase(
          path,
          password: encKey,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
      }
    }
  }

  static const String _syncFields = '''
    updated_at TEXT NOT NULL,
    last_synced_at TEXT,
    sync_status TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0
  ''';

  Future _onCreate(Database db, int version) async {
    // Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        neighborhood TEXT,
        phone TEXT,
        notes TEXT,
        current_balance REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        $_syncFields
      )
    ''');

    // Customer Prices Table
    await db.execute('''
      CREATE TABLE customer_prices (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        custom_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        UNIQUE(customer_id, product_id)
      )
    ''');

    // Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_price REAL NOT NULL,
        unit_name TEXT,
        items_per_unit INTEGER,
        created_at TEXT NOT NULL,
        $_syncFields
      )
    ''');

    // Suppliers Table
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        current_balance REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        $_syncFields
      )
    ''');

    // Supplier Products Table
    await db.execute('''
      CREATE TABLE supplier_products (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        cost_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        UNIQUE(supplier_id, product_id)
      )
    ''');

    // Supplier Returns Table
    await db.execute('''
      CREATE TABLE supplier_returns (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Damaged Items Table
    await db.execute('''
      CREATE TABLE damaged_items (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        is_charged_to_distributor INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Work Days Table
    await db.execute('''
      CREATE TABLE work_days (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        is_closed INTEGER NOT NULL DEFAULT 0,
        closed_at TEXT,
        created_at TEXT NOT NULL,
        $_syncFields
      )
    ''');

    // Inventory Loads Table
    await db.execute('''
      CREATE TABLE inventory_loads (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        initial_quantity INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // Distributions Table
    await db.execute('''
      CREATE TABLE distributions (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // Returns Table
    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // Collections Table
    await db.execute('''
      CREATE TABLE collections (
        id TEXT PRIMARY KEY,
        work_day_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (work_day_id) REFERENCES work_days (id)
      )
    ''');

    // --- Indexes for Maximum Performance ---
    await _createIndexes(db);
  }

  Future _createIndexes(Database db) async {
    // Distributions
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dist_wd_del ON distributions (work_day_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dist_cust_del_date ON distributions (customer_id, is_deleted, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dist_prod_del ON distributions (product_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dist_sync ON distributions (sync_status, is_deleted)');

    // Returns
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ret_wd_del ON returns (work_day_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ret_cust_del_date ON returns (customer_id, is_deleted, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ret_prod_del ON returns (product_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ret_sync ON returns (sync_status, is_deleted)');

    // Collections
    await db.execute('CREATE INDEX IF NOT EXISTS idx_col_wd_del ON collections (work_day_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_col_cust_del_date ON collections (customer_id, is_deleted, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_col_sync ON collections (sync_status, is_deleted)');

    // Inventory Loads
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_wd_del ON inventory_loads (work_day_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_prod_del ON inventory_loads (product_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inv_supp_del ON inventory_loads (supplier_id, is_deleted)');

    // Supplier Payments
    await db.execute('''
      CREATE TABLE supplier_payments (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        work_day_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        $_syncFields,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (work_day_id) REFERENCES work_days (id)
      )
    ''');
    
    // Common sync indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wd_sync ON work_days (sync_status, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cust_sync ON customers (sync_status, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prod_sync ON products (sync_status, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_spay_sync ON supplier_payments (sync_status, is_deleted)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final tables = [
        'customers',
        'customer_prices',
        'products',
        'suppliers',
        'supplier_products',
        'supplier_returns',
        'work_days',
        'inventory_loads',
        'distributions',
        'returns',
        'collections'
      ];

      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT DEFAULT ""');
          await db.execute('ALTER TABLE $table ADD COLUMN last_synced_at TEXT');
          await db.execute('ALTER TABLE $table ADD COLUMN sync_status TEXT DEFAULT "pending"');
          await db.execute('ALTER TABLE $table ADD COLUMN is_deleted INTEGER DEFAULT 0');
        } catch (e) {
          print('Error upgrading table $table: $e');
        }
      }
    }

    if (oldVersion < 3) {
      // Add indexes for maximum performance
      try {
        await _createIndexes(db);
      } catch (e) {
        print('Error creating indexes: $e');
      }
    }

    if (oldVersion < 4) {
      // Re-run indexes for composite queries (version 4)
      try {
        await _createIndexes(db);
      } catch (e) {
        print('Error updating composite indexes: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN current_balance REAL NOT NULL DEFAULT 0.0');
        
        // Calculate and migrate existing balances
        await db.execute('''
          UPDATE customers
          SET current_balance = (
            SELECT 
              COALESCE((SELECT SUM(quantity * price) FROM distributions WHERE customer_id = customers.id AND is_deleted = 0), 0)
              - COALESCE((SELECT SUM(quantity * price) FROM returns WHERE customer_id = customers.id AND is_deleted = 0), 0)
              - COALESCE((SELECT SUM(amount) FROM collections WHERE customer_id = customers.id AND is_deleted = 0), 0)
          )
        ''');
      } catch (e) {
        print('Error upgrading to v5 (current_balance): $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE damaged_items (
            id TEXT PRIMARY KEY,
            work_day_id TEXT NOT NULL,
            supplier_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            cost_price REAL NOT NULL,
            is_charged_to_distributor INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            $_syncFields,
            FOREIGN KEY (work_day_id) REFERENCES work_days (id),
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
            FOREIGN KEY (product_id) REFERENCES products (id)
          )
        ''');
      } catch (e) {
        print('Error upgrading to v6 (damaged_items): $e');
      }
    }

    if (oldVersion < 7) {
      try {
        // Add supplier_id column with default value
        await db.execute('ALTER TABLE distributions ADD COLUMN supplier_id TEXT NOT NULL DEFAULT "unknown"');
        await db.execute('ALTER TABLE returns ADD COLUMN supplier_id TEXT NOT NULL DEFAULT "unknown"');
        
        // Backfill supplier_id from inventory_loads (best guess based on product and workday)
        await db.execute('''
          UPDATE distributions 
          SET supplier_id = COALESCE(
            (SELECT supplier_id FROM inventory_loads 
             WHERE work_day_id = distributions.work_day_id AND product_id = distributions.product_id AND is_deleted = 0 
             LIMIT 1), 
            'unknown'
          )
        ''');
        
        await db.execute('''
          UPDATE returns 
          SET supplier_id = COALESCE(
            (SELECT supplier_id FROM inventory_loads 
             WHERE work_day_id = returns.work_day_id AND product_id = returns.product_id AND is_deleted = 0 
             LIMIT 1), 
            'unknown'
          )
        ''');
      } catch (e) {
        print('Error upgrading to v7 (supplier_id): $e');
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN current_balance REAL NOT NULL DEFAULT 0.0');
        await db.execute('''
          CREATE TABLE supplier_payments (
            id TEXT PRIMARY KEY,
            supplier_id TEXT NOT NULL,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            work_day_id TEXT,
            notes TEXT,
            created_at TEXT NOT NULL,
            $_syncFields,
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
            FOREIGN KEY (work_day_id) REFERENCES work_days (id)
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_spay_sync ON supplier_payments (sync_status, is_deleted)');
      } catch (e) {
        print('Error upgrading to v8 (supplier ledger): $e');
      }
    }
  }
}
