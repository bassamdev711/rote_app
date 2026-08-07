import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_statement_item.dart';
import '../repositories/transaction_repository.dart';
import 'package:intl/intl.dart';
import 'global_refresh_provider.dart';

final transactionRepositoryProvider = Provider((ref) => TransactionRepository());

// Parameters for fetching the statement: customerId, and an optional timeFilter ('today', 'week', 'month', 'custom')
class CustomerStatementParams {
  final String customerId;
  final String timeFilter;
  final String? customStartDate;
  final String? customEndDate;

  CustomerStatementParams({
    required this.customerId, 
    required this.timeFilter,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerStatementParams &&
          runtimeType == other.runtimeType &&
          customerId == other.customerId &&
          timeFilter == other.timeFilter &&
          customStartDate == other.customStartDate &&
          customEndDate == other.customEndDate;

  @override
  int get hashCode => 
      customerId.hashCode ^ 
      timeFilter.hashCode ^ 
      (customStartDate?.hashCode ?? 0) ^ 
      (customEndDate?.hashCode ?? 0);
}

final customerStatementProvider = FutureProvider.family<List<CustomerStatementItem>, CustomerStatementParams>((ref, params) async {
  ref.watch(globalRefreshProvider);
  final repo = ref.read(transactionRepositoryProvider);
  String? startDate;
  String? endDate;

  final now = DateTime.now();
  final format = DateFormat('yyyy-MM-dd');

  switch (params.timeFilter) {
    case 'today':
      startDate = format.format(now);
      endDate = format.format(now);
      break;
    case 'week':
      // Start of week (let's say 7 days ago)
      startDate = format.format(now.subtract(const Duration(days: 7)));
      endDate = format.format(now);
      break;
    case 'month':
      // Start of month
      startDate = format.format(DateTime(now.year, now.month, 1));
      endDate = format.format(now);
      break;
    case 'custom':
      startDate = params.customStartDate;
      endDate = params.customEndDate;
      break;
    default:
      startDate = null;
      endDate = null;
  }

  return await repo.getCustomerStatement(
    params.customerId,
    startDate: startDate,
    endDate: endDate,
  );
});
