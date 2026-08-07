import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/db_helper.dart';
import '../repositories/transaction_repository.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper.instance;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // List of all tables we want to sync
  final List<String> _tables = [
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
    'collections',
    'damaged_items',
    'supplier_payments'
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> syncData({Function(String)? onProgress}) async {
    if (_uid == null) {
      onProgress?.call("خطأ: لم يتم تسجيل الدخول");
      return;
    }

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      onProgress?.call("خطأ: لا يوجد اتصال بالإنترنت");
      return;
    }

    try {
      Database db = await _dbHelper.database;
      
      onProgress?.call("جاري رفع البيانات الجديدة...");
      await _pushLocalChanges(db);

      onProgress?.call("جاري سحب التحديثات من السحابة...");
      await _pullRemoteChanges(db);

      onProgress?.call("تمت المزامنة بنجاح ✓");
    } catch (e) {
      print("Sync Error: $e");
      onProgress?.call("خطأ في المزامنة: $e");
    }
  }

  Future<void> _pushLocalChanges(Database db) async {
    for (String table in _tables) {
      while (true) {
        final List<Map<String, dynamic>> pendingRecords = await db.query(
          table,
          where: 'sync_status = ?',
          whereArgs: ['pending'],
          limit: 500,
        );

        if (pendingRecords.isEmpty) break;

        WriteBatch batch = _firestore.batch();
        
        for (var record in pendingRecords) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(record);
          
          data.remove('sync_status');
          data.remove('last_synced_at');
          
          final docRef = _firestore
              .collection('users')
              .doc(_uid)
              .collection(table)
              .doc(data['id'].toString());
              
          batch.set(docRef, data, SetOptions(merge: true));
        }

        await batch.commit();

        final String now = DateTime.now().toUtc().toIso8601String();
        await db.transaction((txn) async {
          for (var record in pendingRecords) {
            await txn.update(
              table,
              {
                'sync_status': 'synced',
                'last_synced_at': now,
              },
              where: 'id = ?',
              whereArgs: [record['id']],
            );
          }
        });
      }
    }
  }

  Future<void> _pullRemoteChanges(Database db) async {
    final Set<String> affectedCustomerIds = {};
    final Set<String> affectedWorkDayIds = {};

    for (String table in _tables) {
      final String lastSyncKey = 'last_sync_${table}_$_uid';
      String? lastSyncTimeStr = await _secureStorage.read(key: lastSyncKey);
      
      // If the local table is completely empty, we MUST do a full sync 
      // regardless of what lastSyncTimeStr says, because we might have 
      // recreated the database.
      final int count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
      if (count == 0) {
        lastSyncTimeStr = null;
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(_uid)
          .collection(table);

      // Delta Sync: Only fetch documents modified since the last successful sync
      if (lastSyncTimeStr != null) {
        query = query.where('updated_at', isGreaterThan: lastSyncTimeStr).orderBy('updated_at');
      }

      bool hasMore = true;
      DocumentSnapshot? lastDoc;
      
      while (hasMore) {
        var paginatedQuery = query.limit(500);
        if (lastDoc != null) {
          paginatedQuery = paginatedQuery.startAfterDocument(lastDoc);
        }

        final querySnapshot = await paginatedQuery.get();

        if (querySnapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        lastDoc = querySnapshot.docs.last;

        final remoteIds = querySnapshot.docs.map((d) => d.data()['id'].toString()).toList();

        await db.transaction((txn) async {
          final placeholders = List.filled(remoteIds.length, '?').join(',');
          final localRecords = await txn.query(table, where: 'id IN ($placeholders)', whereArgs: remoteIds);
          final localRecordMap = { for (var rec in localRecords) rec['id'].toString(): rec };

          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final remoteId = data['id'].toString();
            
            if (['distributions', 'returns', 'collections'].contains(table) && data.containsKey('customer_id') && data['customer_id'] != null) {
              affectedCustomerIds.add(data['customer_id'].toString());
            }
            if (['distributions', 'returns', 'collections', 'inventory_loads', 'supplier_returns', 'damaged_items'].contains(table) && data.containsKey('work_day_id') && data['work_day_id'] != null) {
              affectedWorkDayIds.add(data['work_day_id'].toString());
            }

            // Fallback for older records lacking supplier_id
            if ((table == 'distributions' || table == 'returns') && !data.containsKey('supplier_id')) {
              data['supplier_id'] = 'unknown';
            }
            
            data['sync_status'] = 'synced';
            data['last_synced_at'] = DateTime.now().toUtc().toIso8601String();

            final localRecord = localRecordMap[remoteId];
            
            if (localRecord == null) {
              await txn.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              final int localIsDeleted = (localRecord['is_deleted'] as num?)?.toInt() ?? 0;
              final int remoteIsDeleted = (data['is_deleted'] as num?)?.toInt() ?? 0;

              if (remoteIsDeleted == 1 && localIsDeleted == 0) {
                 // Remote is deleted, local is not. Remote delete ALWAYS wins!
                 await txn.update(table, data, where: 'id = ?', whereArgs: [remoteId]);
              } else if (localIsDeleted == 1 && remoteIsDeleted == 0) {
                 // Local is deleted, remote is not. Local delete ALWAYS wins!
                 // Do nothing. Next push will delete the remote.
              } else {
                  // Normal LWW
                  final localUpdatedAt = localRecord['updated_at'] as String?;
                  final remoteUpdatedAt = data['updated_at'] as String?;
                  
                  if (localUpdatedAt != null && remoteUpdatedAt != null) {
                    DateTime localDate = DateTime.parse(localUpdatedAt);
                    DateTime remoteDate = DateTime.parse(remoteUpdatedAt);
                    
                    if (remoteDate.isAfter(localDate)) {
                       await txn.update(table, data, where: 'id = ?', whereArgs: [remoteId]);
                    }
                  } else {
                     await txn.update(table, data, where: 'id = ?', whereArgs: [remoteId]);
                  }
              }
            }
          }
        });

        // Record the latest updated_at from this batch to save for next sync
        String? latestUpdateInBatch = lastSyncTimeStr;
        for (var doc in querySnapshot.docs) {
          final docUpdatedAtStr = doc.data()['updated_at'] as String?;
          if (docUpdatedAtStr != null) {
            if (latestUpdateInBatch == null || DateTime.parse(docUpdatedAtStr).isAfter(DateTime.parse(latestUpdateInBatch))) {
              latestUpdateInBatch = docUpdatedAtStr;
            }
          }
        }

        if (latestUpdateInBatch != null) {
          await _secureStorage.write(key: lastSyncKey, value: latestUpdateInBatch);
        }
      }
    }

    // === POST-SYNC SWEEP (Multi-Device Integrity Check) ===
    await _postSyncIntegritySweep(db, affectedCustomerIds, affectedWorkDayIds);
  }

  Future<void> _postSyncIntegritySweep(Database db, Set<String> affectedCustomerIds, Set<String> affectedWorkDayIds) async {
    if (affectedWorkDayIds.isEmpty) return;
    
    final placeholders = List.filled(affectedWorkDayIds.length, '?').join(',');
    final List<Map<String, dynamic>> affectedDays = await db.query('work_days', where: 'id IN ($placeholders) AND is_deleted = 0', whereArgs: affectedWorkDayIds.toList());
    final List<Map<String, dynamic>> allProducts = await db.query('products', where: 'is_deleted = 0');

    for (var wd in affectedDays) {
      String workDayId = wd['id'].toString();
      bool isClosed = wd['is_closed'] == 1;
      bool wasModifiedInSweep = false;
      
      for (var prod in allProducts) {
        String productId = prod['id'].toString();
        
        bool hasConflict = true;
        while (hasConflict) {
          // 1. Calculate Available Inventory
          var loads = await db.rawQuery('SELECT SUM(initial_quantity) as total FROM inventory_loads WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, productId]);
          double loaded = (loads.first['total'] as num?)?.toDouble() ?? 0.0;

          var dists = await db.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, productId]);
          double distributed = (dists.first['total'] as num?)?.toDouble() ?? 0.0;

          var rets = await db.rawQuery('SELECT SUM(quantity) as total FROM returns WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, productId]);
          double returned = (rets.first['total'] as num?)?.toDouble() ?? 0.0;

          var srets = await db.rawQuery('SELECT SUM(quantity) as total FROM supplier_returns WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, productId]);
          double supplierReturned = (srets.first['total'] as num?)?.toDouble() ?? 0.0;

          var damages = await db.rawQuery('SELECT SUM(quantity) as total FROM damaged_items WHERE work_day_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, productId]);
          double damaged = (damages.first['total'] as num?)?.toDouble() ?? 0.0;

          double available = loaded + returned - distributed - supplierReturned - damaged;
          
          if (available >= 0) {
            hasConflict = false; // Resolved!
          } else {
            // Negative inventory! We must reject the most recent negative operation.
            String? tableToReject;
            String? idToReject;
            DateTime? latestDate;
            String? customerIdAffected;

            Future<void> checkLatest(String table, bool hasCustomer) async {
              var rows = await db.query(table, where: 'work_day_id = ? AND product_id = ? AND is_deleted = 0', whereArgs: [workDayId, productId], orderBy: 'created_at DESC', limit: 1);
              if (rows.isNotEmpty) {
                DateTime d = DateTime.parse(rows.first['created_at'].toString());
                if (latestDate == null || d.isAfter(latestDate!)) {
                  latestDate = d;
                  tableToReject = table;
                  idToReject = rows.first['id'].toString();
                  if (hasCustomer) customerIdAffected = rows.first['customer_id'].toString();
                }
              }
            }

            await checkLatest('distributions', true);
            await checkLatest('supplier_returns', false);
            await checkLatest('damaged_items', false);

            if (tableToReject != null && idToReject != null) {
              await db.update(tableToReject!, {
                'is_deleted': 1,
                'sync_status': 'pending',
                'updated_at': DateTime.now().toUtc().toIso8601String()
              }, where: 'id = ?', whereArgs: [idToReject]);
              
              if (customerIdAffected != null) affectedCustomerIds.add(customerIdAffected!);
              wasModifiedInSweep = true;
            } else {
               hasConflict = false;
            }
          }
        }
      }
      
      // 2. Resolve Customer Returns Exceeding Distributions
      var uniqueCustomersRows = await db.rawQuery('SELECT DISTINCT customer_id FROM distributions WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
      List<String> customerIds = uniqueCustomersRows.map((e) => e['customer_id'].toString()).toList();
      
      for (var cId in customerIds) {
        for (var prod in allProducts) {
          String productId = prod['id'].toString();
          bool hasConflict = true;
          while (hasConflict) {
            var dists = await db.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ? AND customer_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, cId, productId]);
            double distributed = (dists.first['total'] as num?)?.toDouble() ?? 0.0;

            var rets = await db.rawQuery('SELECT SUM(quantity) as total FROM returns WHERE work_day_id = ? AND customer_id = ? AND product_id = ? AND is_deleted = 0', [workDayId, cId, productId]);
            double returned = (rets.first['total'] as num?)?.toDouble() ?? 0.0;
            
            if (returned <= distributed) {
              hasConflict = false;
            } else {
               var rows = await db.query('returns', where: 'work_day_id = ? AND customer_id = ? AND product_id = ? AND is_deleted = 0', whereArgs: [workDayId, cId, productId], orderBy: 'created_at DESC', limit: 1);
               if (rows.isNotEmpty) {
                  await db.update('returns', {
                    'is_deleted': 1,
                    'sync_status': 'pending',
                    'updated_at': DateTime.now().toUtc().toIso8601String()
                  }, where: 'id = ?', whereArgs: [rows.first['id']]);
                  affectedCustomerIds.add(cId);
                  wasModifiedInSweep = true;
               } else {
                  hasConflict = false;
               }
            }
          }
        }
      }
      
      // 3. RE-OPEN ZOMBIE CLOSED DAYS
      if (isClosed) {
         var totalLoads = await db.rawQuery('SELECT SUM(initial_quantity) as total FROM inventory_loads WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
         double tLoaded = (totalLoads.first['total'] as num?)?.toDouble() ?? 0.0;
         
         var totalDists = await db.rawQuery('SELECT SUM(quantity) as total FROM distributions WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
         double tDist = (totalDists.first['total'] as num?)?.toDouble() ?? 0.0;
         
         var totalRets = await db.rawQuery('SELECT SUM(quantity) as total FROM returns WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
         double tRet = (totalRets.first['total'] as num?)?.toDouble() ?? 0.0;

         var totalSRets = await db.rawQuery('SELECT SUM(quantity) as total FROM supplier_returns WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
         double tSRet = (totalSRets.first['total'] as num?)?.toDouble() ?? 0.0;

         var totalDmgs = await db.rawQuery('SELECT SUM(quantity) as total FROM damaged_items WHERE work_day_id = ? AND is_deleted = 0', [workDayId]);
         double tDmg = (totalDmgs.first['total'] as num?)?.toDouble() ?? 0.0;

         if ((tLoaded + tRet) != (tDist + tSRet + tDmg) || wasModifiedInSweep) {
            // THE CLOSED DAY IS NOW CORRUPTED BY SYNC ZOMBIE TRANSACTIONS! FORCE IT OPEN!
            await db.update('work_days', {
               'is_closed': 0,
               'sync_status': 'pending',
               'updated_at': DateTime.now().toUtc().toIso8601String()
            }, where: 'id = ?', whereArgs: [workDayId]);
         }
      }
    }
    
    if (affectedCustomerIds.isNotEmpty) {
      final repo = TransactionRepository();
      for (String customerId in affectedCustomerIds) {
        await repo.recalculateCustomerBalance(customerId);
      }
    }
  }
}
