import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';
import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../domain/entities/transaction_record.dart';
import '../../domain/entities/customer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final totalCustomersAsync = ref.watch(totalCustomersProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Book', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                _getSyncText(syncStatus.value),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildDashboard(statsAsync, totalCustomersAsync),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<CustomerFilter>(
              segments: const [
                ButtonSegment(value: CustomerFilter.all, label: Text('All')),
                ButtonSegment(value: CustomerFilter.daily, label: Text('Daily')),
                ButtonSegment(value: CustomerFilter.monthly, label: Text('Monthly')),
              ],
              selected: {ref.watch(customerFilterProvider)},
              onSelectionChanged: (set) {
                ref.read(customerFilterProvider.notifier).state = set.first;
              },
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(child: _CustomerList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _getSyncText(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced: return '☁️ Synced';
      case SyncStatus.syncing: return '☁️ Syncing...';
      case SyncStatus.error: return '☁️ Sync Error';
      case SyncStatus.disconnected: return '☁️ Offline';
    }
  }

  Widget _buildDashboard(AsyncValue<Map<String, double>> statsAsync, AsyncValue<int> totalCustomersAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Customers',
              value: totalCustomersAsync.valueOrNull?.toString() ?? '0',
            ),
          ),
          Expanded(
            child: _StatCard(
              title: 'Total Given',
              value: '₹${NumberFormat('#,##,###').format(statsAsync.valueOrNull?['totalGiven'] ?? 0)}',
            ),
          ),
          Expanded(
            child: _StatCard(
              title: 'Outstanding',
              value: '₹${NumberFormat('#,##,###').format(statsAsync.valueOrNull?['totalBalance'] ?? 0)}',
              valueColor: const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _StatCard({required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF0D47A1)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerList extends ConsumerWidget {
  const _CustomerList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(filteredCustomersProvider);

    if (customers.isEmpty) {
      return const Center(child: Text('No customers found.'));
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        // We can fetch the last transaction for the customer to show totals
        // For simplicity in UI and speed, it's better if Customer entity had totalGiven/Balance
        // but since we compute them, we'll use a StreamBuilder or Provider per item.
        return _CustomerListItem(customer: customer);
      },
    );
  }
}

class _CustomerListItem extends ConsumerWidget {
  final Customer customer;

  const _CustomerListItem({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(customerTransactionsProvider(customer.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailsScreen(customerId: customer.id, customerName: customer.name))),
        onLongPress: () => _showDeleteDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: txAsync.when(
            data: (transactions) {
              final lastTx = transactions.isNotEmpty ? transactions.last : null;
              final given = lastTx?.runningTotalGiven ?? 0;
              final balance = lastTx?.runningBalance ?? 0;

              DateTime? lastGivenDate;
              DateTime? lastReceivedDate;
              for (var tx in transactions) {
                if (tx.type == TransactionType.given) {
                  lastGivenDate = tx.date;
                } else if (tx.type == TransactionType.received) {
                  lastReceivedDate = tx.date;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: customer.frequency == RepaymentFrequency.daily ? Colors.blue[50] : Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: customer.frequency == RepaymentFrequency.daily ? Colors.blue[200]! : Colors.purple[200]!),
                        ),
                        child: Text(
                          customer.frequency == RepaymentFrequency.daily ? 'Daily' : 'Monthly',
                          style: TextStyle(
                            fontSize: 12,
                            color: customer.frequency == RepaymentFrequency.daily ? Colors.blue[700] : Colors.purple[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Given : ₹${NumberFormat('#,##,###').format(given)}'),
                      Text('Balance : ₹${NumberFormat('#,##,###').format(balance)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (lastGivenDate != null)
                    Text('Money Given On: ${DateFormat('dd MMM yyyy').format(lastGivenDate)}', style: TextStyle(fontSize: 12, color: Colors.orange[900])),
                  if (lastReceivedDate != null)
                    Text('Money Received On: ${DateFormat('dd MMM yyyy').format(lastReceivedDate)}', style: TextStyle(fontSize: 12, color: Colors.green[900])),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: \$e'),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete ${customer.name} and all their transactions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(financeRepositoryProvider).deleteCustomer(customer.id);
              Navigator.pop(ctx);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
