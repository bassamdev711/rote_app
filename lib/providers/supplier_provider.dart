import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../models/supplier_product.dart';
import '../repositories/supplier_repository.dart';
import '../repositories/inventory_load_repository.dart';
import 'work_day_provider.dart';
import 'global_refresh_provider.dart';

// Provides the repository instance (already declared in daily_inventory_provider temporarily, but it's safe to have it here if we remove from there, or we can share)
final supplierRepositoryProvider = Provider((ref) => SupplierRepository());

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) async {
  ref.watch(globalRefreshProvider);
  final repo = ref.read(supplierRepositoryProvider);
  return await repo.getAllSuppliers();
});

final supplierProductsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, supplierId) async {
  ref.watch(globalRefreshProvider);
  final repo = ref.read(supplierRepositoryProvider);
  return await repo.getProductsForSupplier(supplierId);
});

// A provider for calculating a specific supplier's statement/balance for a workday
final supplierStatementProvider = FutureProvider.family.autoDispose<Map<String, double>, String>((ref, workDayId) async {
  ref.watch(globalRefreshProvider);
  final invRepo = ref.read(inventoryLoadRepositoryProvider);
  final supplierRepo = ref.read(supplierRepositoryProvider);
  
  final loads = await invRepo.getLoadsForWorkDay(workDayId);
  final returns = await supplierRepo.getReturnsForWorkDay(workDayId);
  
  Map<String, double> supplierBalances = {};
  
  for (var load in loads) {
    String key = load.supplierId.toString();
    double amount = (load.initialQuantity ?? 0) * load.costPrice;
    supplierBalances[key] = (supplierBalances[key] ?? 0.0) + amount;
  }
  
  for (var ret in returns) {
    String key = ret.supplierId.toString();
    double amount = (ret.quantity ?? 0) * ret.costPrice;
    supplierBalances[key] = (supplierBalances[key] ?? 0.0) - amount;
  }
  
  return supplierBalances;
});
