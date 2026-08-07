import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/db_helper.dart';
import '../models/distribution.dart';
import '../models/return_transaction.dart';
import '../repositories/inventory_load_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/supplier_repository.dart';
import '../models/supplier_return.dart';
import '../models/damaged_item.dart';
import 'customer_balance_provider.dart';
import 'work_day_provider.dart';
import 'supplier_provider.dart';
import 'global_refresh_provider.dart';

class ProductInventory {
  final String productId;
  final String productName;
  final int initialLoad;
  final int distributed;
  final int returned;
  final int supplierReturned;
  final int damaged;
  
  int get remaining => initialLoad + returned - distributed - supplierReturned - damaged;

  ProductInventory({
    required this.productId,
    required this.productName,
    required this.initialLoad,
    required this.distributed,
    required this.returned,
    required this.supplierReturned,
    required this.damaged,
  });
}

// supplierRepositoryProvider is defined in supplier_provider.dart.

final dailyInventoryProvider = FutureProvider.autoDispose<List<ProductInventory>>((ref) async {
  ref.watch(globalRefreshProvider);
  final activeDayState = ref.watch(currentWorkDayProvider);
  
  return activeDayState.when(
    data: (workDay) async {
      if (workDay == null) return [];
      
      final invRepo = ref.read(inventoryLoadRepositoryProvider);
      final txRepo = ref.read(transactionRepositoryProvider);
      final supplierRepo = ref.read(supplierRepositoryProvider);
      
      final loads = await invRepo.getLoadsForWorkDay(workDay.id!);
      
      // Fetch all products to match IDs
      final dbHelper = DBHelper.instance;
      final db = await dbHelper.database;
      final productMaps = await db.query('products');
      
      final distributions = await txRepo.getDistributionsByWorkDay(workDay.id!);
      final returns = await txRepo.getReturnsByWorkDay(workDay.id!);
      final supplierReturns = await supplierRepo.getReturnsForWorkDay(workDay.id!);
      final damagedItems = await supplierRepo.getDamagedItemsForWorkDay(workDay.id!);
      
      List<ProductInventory> inventories = [];
      
      for (var pMap in productMaps) {
        String pId = pMap['id'] as String;
        String pName = pMap['name'] as String;
        
        int initialLoad = 0;
        final loadForProduct = loads.where((l) => l.productId == pId).toList();
        for (var l in loadForProduct) {
          initialLoad += (l.initialQuantity as num).toInt();
        }
        
        int distributed = 0;
        for (Distribution d in distributions.where((d) => d.productId == pId)) {
          distributed += (d.quantity as num).toInt();
        }
        
        int returned = 0;
        for (ReturnTransaction r in returns.where((r) => r.productId == pId)) {
          returned += (r.quantity as num).toInt();
        }

        int supplierReturned = 0;
        for (SupplierReturn sr in supplierReturns.where((r) => r.productId == pId)) {
          supplierReturned += (sr.quantity as num).toInt();
        }

        int damaged = 0;
        for (DamagedItem di in damagedItems.where((r) => r.productId == pId)) {
          damaged += (di.quantity as num).toInt();
        }
        
        inventories.add(ProductInventory(
          productId: pId,
          productName: pName,
          initialLoad: initialLoad,
          distributed: distributed,
          returned: returned,
          supplierReturned: supplierReturned,
          damaged: damaged,
        ));
      }
      
      return inventories;
    },
    error: (e, st) => [],
    loading: () => [],
  );
});

final inventoryForDayProvider = FutureProvider.family.autoDispose<List<ProductInventory>, String>((ref, workDayId) async {
  ref.watch(globalRefreshProvider);
  final invRepo = ref.read(inventoryLoadRepositoryProvider);
  final txRepo = ref.read(transactionRepositoryProvider);
  final supplierRepo = ref.read(supplierRepositoryProvider);
  
  final loads = await invRepo.getLoadsForWorkDay(workDayId);
  
  final dbHelper = DBHelper.instance;
  final db = await dbHelper.database;
  final productMaps = await db.query('products');
  
  final distributions = await txRepo.getDistributionsByWorkDay(workDayId);
  final returns = await txRepo.getReturnsByWorkDay(workDayId);
  final supplierReturns = await supplierRepo.getReturnsForWorkDay(workDayId);
  final damagedItems = await supplierRepo.getDamagedItemsForWorkDay(workDayId);
  
  List<ProductInventory> inventories = [];
  
  for (var pMap in productMaps) {
    String pId = pMap['id'] as String;
    String pName = pMap['name'] as String;
    
    int initialLoad = 0;
    final loadForProduct = loads.where((l) => l.productId == pId).toList();
    for (var l in loadForProduct) {
      initialLoad += (l.initialQuantity as num).toInt();
    }
    
    int distributed = 0;
    for (Distribution d in distributions.where((d) => d.productId == pId)) {
      distributed += (d.quantity as num).toInt();
    }
    
    int returned = 0;
    for (ReturnTransaction r in returns.where((r) => r.productId == pId)) {
      returned += (r.quantity as num).toInt();
    }

    int supplierReturned = 0;
    for (SupplierReturn sr in supplierReturns.where((r) => r.productId == pId)) {
      supplierReturned += (sr.quantity as num).toInt();
    }

    int damaged = 0;
    for (DamagedItem di in damagedItems.where((r) => r.productId == pId)) {
      damaged += (di.quantity as num).toInt();
    }
    
    inventories.add(ProductInventory(
      productId: pId,
      productName: pName,
      initialLoad: initialLoad,
      distributed: distributed,
      returned: returned,
      supplierReturned: supplierReturned,
      damaged: damaged,
    ));
  }
  return inventories;
});
