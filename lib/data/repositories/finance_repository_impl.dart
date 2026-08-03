import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../local/isar_database.dart';
import '../remote/google_drive_service.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/transaction_record.dart';

enum SyncStatus { synced, syncing, error, disconnected }

class FinanceRepository {
  final IsarDatabase localDb;
  final GoogleDriveService driveService;

  final ValueNotifier<SyncStatus> syncStatus = ValueNotifier(SyncStatus.disconnected);
  final PublishSubject<void> _syncRequestSubject = PublishSubject<void>();
  StreamSubscription? _syncSubscription;

  FinanceRepository(this.localDb, this.driveService) {
    _initSyncDebouncer();
  }

  void _initSyncDebouncer() {
    // Sync automatically 30 seconds after the last change
    _syncSubscription = _syncRequestSubject
        .debounceTime(const Duration(seconds: 30))
        .listen((_) => forceSync());
  }

  void dispose() {
    _syncSubscription?.cancel();
    _syncRequestSubject.close();
  }

  // --- SYNC LOGIC ---

  void _requestSync() {
    if (syncStatus.value != SyncStatus.disconnected) {
      _syncRequestSubject.add(null);
    }
  }

  Future<void> forceSync() async {
    if (syncStatus.value == SyncStatus.disconnected || syncStatus.value == SyncStatus.syncing) return;
    
    syncStatus.value = SyncStatus.syncing;
    try {
      final dbPath = await localDb.getDatabasePath();
      final success = await driveService.backupDatabase(dbPath);
      syncStatus.value = success ? SyncStatus.synced : SyncStatus.error;
    } catch (e) {
      syncStatus.value = SyncStatus.error;
    }
  }
  
  Future<void> setConnected(bool isConnected) async {
    if (isConnected) {
       syncStatus.value = SyncStatus.synced;
       // Initial check for backup could happen here
    } else {
       syncStatus.value = SyncStatus.disconnected;
    }
  }

  // --- CRUD WRAPPERS ---

  Stream<List<Customer>> watchCustomers() => localDb.watchCustomers();
  
  Stream<List<TransactionRecord>> watchTransactions(int customerId) => localDb.watchTransactions(customerId);
  
  Stream<Map<String, double>> watchDashboardStats() => localDb.watchDashboardStats();
  
  Stream<int> watchTotalCustomers() => localDb.watchTotalCustomers();

  Future<void> addCustomer(String name, double initialAmount, DateTime date, RepaymentFrequency frequency) async {
    await localDb.addCustomer(name, initialAmount, date, frequency);
    _requestSync();
  }

  Future<void> editCustomerName(int id, String newName) async {
    await localDb.editCustomerName(id, newName);
    _requestSync();
  }

  Future<void> deleteCustomer(int id) async {
    await localDb.deleteCustomer(id);
    _requestSync();
  }

  Future<void> addTransaction(int customerId, DateTime date, double amount, TransactionType type) async {
    await localDb.addTransaction(customerId, date, amount, type);
    _requestSync();
  }

  Future<void> editTransaction(int txId, DateTime date, double amount, TransactionType type) async {
    await localDb.editTransaction(txId, date, amount, type);
    _requestSync();
  }

  Future<void> deleteTransaction(int txId) async {
    await localDb.deleteTransaction(txId);
    _requestSync();
  }
}
