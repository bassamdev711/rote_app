import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'global_refresh_provider.dart';
import '../repositories/transaction_repository.dart';

class CustomerSummary {
  final double balance;
  final int? quantity;
  final double totalPaid;
  CustomerSummary({required this.balance, required this.quantity, this.totalPaid = 0.0});
}

final transactionRepositoryProvider = Provider((ref) => TransactionRepository());

final customerBalanceProvider = FutureProvider.family<CustomerSummary, String>((ref, customerId) async {
  ref.watch(globalRefreshProvider);
  final repo = ref.read(transactionRepositoryProvider);
  
  // استعلام SQL واحد فقط بدلاً من 3 استعلامات + حلقات تكرار
  final summary = await repo.getCustomerBalanceSummary(customerId);
  
  return CustomerSummary(
    balance: (summary['balance'] as num).toDouble(),
    quantity: (summary['quantity'] as num).toInt(),
    totalPaid: (summary['totalPaid'] as num).toDouble(),
  );
});
