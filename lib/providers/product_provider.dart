import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../models/supplier_product.dart';
import 'supplier_provider.dart';
import 'global_refresh_provider.dart';
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(() {
  return ProductsNotifier();
});

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<Product>> build() async {
    ref.watch(globalRefreshProvider);
    _offset = 0;
    _hasMore = true;
    final items = await _repository.getAll(limit: _limit, offset: _offset);
    if (items.length < _limit) _hasMore = false;
    return items;
  }

  Future<void> loadMore() async {
    if (state.isLoading || !_hasMore) return;
    
    final current = state.value ?? [];
    _offset += _limit;
    final moreItems = await _repository.getAll(limit: _limit, offset: _offset);
    
    if (moreItems.length < _limit) {
      _hasMore = false;
    }
    
    state = AsyncData([...current, ...moreItems]);
  }

  Future<void> addProduct(Product product) async {
    await _repository.insert(product);
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> addProductWithSupplier(Product product, String supplierId, double costPrice) async {
    final productId = await _repository.insert(product);
    final supplierRepo = ref.read(Provider((ref) => SupplierRepository()));
    await supplierRepo.insertSupplierProduct(SupplierProduct(
      supplierId: supplierId,
      productId: productId,
      costPrice: costPrice,
    ));
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> updateProduct(Product product) async {
    await _repository.update(product);
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> deleteProduct(String id) async {
    await _repository.delete(id);
    ref.read(globalRefreshProvider.notifier).refresh();
  }
}
