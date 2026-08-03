import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/finance_providers.dart';
import '../../domain/entities/transaction_record.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final int customerId;
  final TransactionRecord? existingTx;

  const AddTransactionScreen({super.key, required this.customerId, this.existingTx});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.given;

  @override
  void initState() {
    super.initState();
    if (widget.existingTx != null) {
      _amountController.text = widget.existingTx!.amount.toString();
      _selectedDate = widget.existingTx!.date;
      _selectedType = widget.existingTx!.type;
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    if (widget.existingTx != null) {
      await ref.read(financeRepositoryProvider).editTransaction(
            widget.existingTx!.id,
            _selectedDate,
            amount,
            _selectedType,
          );
    } else {
      await ref.read(financeRepositoryProvider).addTransaction(
            widget.customerId,
            _selectedDate,
            amount,
            _selectedType,
          );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingTx != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    title: 'Money Given',
                    isSelected: _selectedType == TransactionType.given,
                    color: Colors.orange,
                    onTap: () => setState(() => _selectedType = TransactionType.given),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TypeButton(
                    title: 'Money Received',
                    isSelected: _selectedType == TransactionType.received,
                    color: Colors.green,
                    onTap: () => setState(() => _selectedType = TransactionType.received),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _save,
            child: const Text('Save Transaction'),
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({required this.title, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? color.withOpacity(0.8) : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
