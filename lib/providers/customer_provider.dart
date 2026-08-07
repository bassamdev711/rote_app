import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import 'global_refresh_provider.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final customersProvider = AsyncNotifierProvider<CustomersNotifier, List<Customer>>(() {
  return CustomersNotifier();
});

class CustomersNotifier extends AsyncNotifier<List<Customer>> {
  CustomerRepository get _repository => ref.read(customerRepositoryProvider);
  
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<Customer>> build() async {
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

  Future<void> addCustomer(Customer customer) async {
    await _repository.insert(customer);
    // Reload from db to ensure correct ordering via SQLite without memory sorting
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _repository.update(customer);
    ref.read(globalRefreshProvider.notifier).refresh();
  }

  Future<void> deleteCustomer(String id) async {
    await _repository.delete(id);
    if (state.hasValue) {
      state = AsyncData(state.value!.where((c) => c.id != id).toList());
    }
  }
}
