import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';
import '../../domain/entities/transaction_record.dart';
import 'add_transaction_screen.dart';
import '../../data/repositories/finance_repository_impl.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final int customerId;
  final String customerName;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(customerTransactionsProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editCustomerName(context, ref),
          ),
        ],
      ),
      body: txAsync.when(
        data: (transactions) {
          final lastTx = transactions.isNotEmpty ? transactions.last : null;
          final totalGiven = lastTx?.runningTotalGiven ?? 0;
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
            children: [
              _buildHeader(totalGiven, balance, lastGivenDate, lastReceivedDate),
              Expanded(
                child: ListView.builder(
                  // Show newest transactions first by reversing the list
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[transactions.length - 1 - index];
                    return _TransactionCard(
                      tx: tx,
                      onDelete: () => _deleteTransaction(context, ref, tx.id),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(
                            customerId: customerId,
                            existingTx: tx,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(customerId: customerId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildHeader(double totalGiven, double balance, DateTime? lastGivenDate, DateTime? lastReceivedDate) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF0D47A1),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Total Given', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${NumberFormat('#,##,###').format(totalGiven)}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('Current Balance', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${NumberFormat('#,##,###').format(balance)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          if (lastGivenDate != null || lastReceivedDate != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (lastGivenDate != null)
                  Text('Given On: ${DateFormat('dd MMM yyyy').format(lastGivenDate)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (lastReceivedDate != null)
                  Text('Received On: ${DateFormat('dd MMM yyyy').format(lastReceivedDate)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Future<void> _editCustomerName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: customerName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer Name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      ref.read(financeRepositoryProvider).editCustomerName(customerId, newName);
      // Wait for re-render or pop if you strictly want to change the appbar instantly.
      // Easiest is to pop and replace or rely on state, but since we passed name in constructor,
      // it won't update here. We should use a provider for the customer.
    }
  }

  void _deleteTransaction(BuildContext context, WidgetRef ref, int txId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('Are you sure? Running totals will be recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(financeRepositoryProvider).deleteTransaction(txId);
              Navigator.pop(ctx);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionRecord tx;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionCard({required this.tx, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isGiven = tx.type == TransactionType.given;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit Transaction'),
                    onTap: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Transaction', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(tx.date),
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGiven ? Colors.orange[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isGiven ? 'Money Given' : 'Money Received',
                      style: TextStyle(
                        fontSize: 12,
                        color: isGiven ? Colors.orange[900] : Colors.green[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '₹${NumberFormat('#,##,###').format(tx.amount)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Given', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('₹${NumberFormat('#,##,###').format(tx.runningTotalGiven)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        '₹${NumberFormat('#,##,###').format(tx.runningBalance)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
