import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/transaction_record.dart';

class IsarDatabase {
  late Isar isar;
  
  Future<void> init() async {
    String dirPath = '';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }
    isar = await Isar.open(
      [CustomerSchema, TransactionRecordSchema],
      directory: dirPath,
    );
  }

  // --- CUSTOMERS ---

  Stream<List<Customer>> watchCustomers() {
    return isar.customers.where().watch(fireImmediately: true);
  }

  Future<Customer?> getCustomer(int id) async {
    return isar.customers.get(id);
  }

  Future<void> addCustomer(String name, double initialAmount, DateTime date, RepaymentFrequency frequency) async {
    final customer = Customer()
      ..name = name
      ..createdDate = date
      ..frequency = frequency;
    
    await isar.writeTxn(() async {
      final customerId = await isar.customers.put(customer);
      
      if (initialAmount > 0) {
        final tx = TransactionRecord()
          ..customerId = customerId
          ..date = date
          ..type = TransactionType.given
          ..amount = initialAmount
          ..runningTotalGiven = initialAmount
          ..runningBalance = initialAmount;
        await isar.transactionRecords.put(tx);
      }
    });
  }

  Future<void> editCustomerName(int id, String newName) async {
    await isar.writeTxn(() async {
      final customer = await isar.customers.get(id);
      if (customer != null) {
        customer.name = newName;
        await isar.customers.put(customer);
      }
    });
  }

  Future<void> deleteCustomer(int id) async {
    await isar.writeTxn(() async {
      await isar.customers.delete(id);
      await isar.transactionRecords.filter().customerIdEqualTo(id).deleteAll();
    });
  }

  // --- TRANSACTIONS ---

  Stream<List<TransactionRecord>> watchTransactions(int customerId) {
    return isar.transactionRecords
        .filter()
        .customerIdEqualTo(customerId)
        .sortByDate()
        .watch(fireImmediately: true);
  }

  Future<void> addTransaction(int customerId, DateTime date, double amount, TransactionType type) async {
    await isar.writeTxn(() async {
      final tx = TransactionRecord()
        ..customerId = customerId
        ..date = date
        ..amount = amount
        ..type = type
        ..runningTotalGiven = 0 // Temporary
        ..runningBalance = 0; // Temporary
        
      await isar.transactionRecords.put(tx);
    });
    // Recalculate totals for this customer
    await _recalculateCustomerTotals(customerId);
  }

  Future<void> editTransaction(int txId, DateTime date, double amount, TransactionType type) async {
    int? customerId;
    await isar.writeTxn(() async {
      final tx = await isar.transactionRecords.get(txId);
      if (tx != null) {
        tx.date = date;
        tx.amount = amount;
        tx.type = type;
        customerId = tx.customerId;
        await isar.transactionRecords.put(tx);
      }
    });
    if (customerId != null) {
      await _recalculateCustomerTotals(customerId!);
    }
  }

  Future<void> deleteTransaction(int txId) async {
    int? customerId;
    await isar.writeTxn(() async {
      final tx = await isar.transactionRecords.get(txId);
      if (tx != null) {
        customerId = tx.customerId;
        await isar.transactionRecords.delete(txId);
      }
    });
    if (customerId != null) {
      await _recalculateCustomerTotals(customerId!);
    }
  }

  // --- RECALCULATION LOGIC ---

  Future<void> _recalculateCustomerTotals(int customerId) async {
    await isar.writeTxn(() async {
      final transactions = await isar.transactionRecords
          .filter()
          .customerIdEqualTo(customerId)
          .sortByDate()
          .findAll();

      double currentGiven = 0;
      double currentBalance = 0;

      for (var tx in transactions) {
        if (tx.type == TransactionType.given) {
          currentGiven += tx.amount;
          currentBalance += tx.amount;
        } else {
          currentBalance -= tx.amount;
        }

        if (tx.runningTotalGiven != currentGiven || tx.runningBalance != currentBalance) {
          tx.runningTotalGiven = currentGiven;
          tx.runningBalance = currentBalance;
          await isar.transactionRecords.put(tx);
        }
      }
    });
  }

  // --- DASHBOARD AGGREGATES ---

  Stream<int> watchTotalCustomers() {
    return isar.customers.where().watch(fireImmediately: true).map((list) => list.length);
  }

  Stream<Map<String, double>> watchDashboardStats() async* {
    // We can yield updates whenever transactions change.
    // A simpler way is to listen to the transactions collection.
    yield* isar.transactionRecords.where().watch(fireImmediately: true).asyncMap((_) async {
      final allCustomers = await isar.customers.where().findAll();
      double totalGiven = 0;
      double totalBalance = 0;

      for (var c in allCustomers) {
        // Get the latest transaction for each customer
        final lastTx = await isar.transactionRecords
            .filter()
            .customerIdEqualTo(c.id)
            .sortByDateDesc()
            .findFirst();
        
        if (lastTx != null) {
          totalGiven += lastTx.runningTotalGiven;
          totalBalance += lastTx.runningBalance;
        }
      }
      return {'totalGiven': totalGiven, 'totalBalance': totalBalance};
    });
  }

  // --- BACKUP & RESTORE UTILS ---
  
  Future<String> getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/default.isar';
  }
}
