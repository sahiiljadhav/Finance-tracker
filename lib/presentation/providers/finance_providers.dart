import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/transaction_record.dart';

// --- CORE PROVIDERS ---

// Overridden in main() after initialization
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  throw UnimplementedError('financeRepositoryProvider not initialized');
});

// A provider that listens to the syncStatus ValueNotifier
final syncStatusProvider = ChangeNotifierProvider<ValueNotifier<SyncStatus>>((ref) {
  return ref.watch(financeRepositoryProvider).syncStatus;
});

// --- FILTER AND SEARCH PROVIDERS ---
enum CustomerFilter { all, daily, monthly }

final customerFilterProvider = StateProvider<CustomerFilter>((ref) => CustomerFilter.all);
final searchQueryProvider = StateProvider<String>((ref) => '');

// --- STREAM PROVIDERS ---

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCustomers();
});

// Customers provider that filters by search query
final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final customers = ref.watch(customersStreamProvider).valueOrNull ?? [];
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final filter = ref.watch(customerFilterProvider);

  return customers.where((c) {
    if (filter == CustomerFilter.daily && c.frequency != RepaymentFrequency.daily) return false;
    if (filter == CustomerFilter.monthly && c.frequency != RepaymentFrequency.monthly) return false;
    if (query.isNotEmpty && !c.name.toLowerCase().contains(query)) return false;
    return true;
  }).toList();
});

final customerTransactionsProvider = StreamProvider.family<List<TransactionRecord>, int>((ref, customerId) {
  return ref.watch(financeRepositoryProvider).watchTransactions(customerId);
});

final dashboardStatsProvider = StreamProvider<Map<String, double>>((ref) {
  return ref.watch(financeRepositoryProvider).watchDashboardStats();
});

final totalCustomersProvider = StreamProvider<int>((ref) {
  // watchTotalCustomers from repo
  return ref.watch(financeRepositoryProvider).watchTotalCustomers();
});
