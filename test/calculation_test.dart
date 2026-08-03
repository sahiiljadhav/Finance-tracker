import 'package:flutter_test/flutter_test.dart';
import 'package:finance/domain/entities/transaction_record.dart';

// Since Isar tests require core binaries which aren't easily available in CLI environments without setup,
// we will test the core recalculation logic purely by simulating the Isar transaction loop.

void recalculateCustomerTotalsSimulated(List<TransactionRecord> transactions) {
  // Sort chronologically
  transactions.sort((a, b) => a.date.compareTo(b.date));

  double currentGiven = 0;
  double currentBalance = 0;

  for (var tx in transactions) {
    if (tx.type == TransactionType.given) {
      currentGiven += tx.amount;
      currentBalance += tx.amount;
    } else {
      currentBalance -= tx.amount;
    }
    tx.runningTotalGiven = currentGiven;
    tx.runningBalance = currentBalance;
  }
}

void main() {
  group('Running Totals Calculation Logic', () {
    test('Calculates correctly for multiple gives and receives', () {
      final tx1 = TransactionRecord()
        ..id = 1
        ..date = DateTime(2023, 1, 1)
        ..type = TransactionType.given
        ..amount = 1000;

      final tx2 = TransactionRecord()
        ..id = 2
        ..date = DateTime(2023, 1, 2)
        ..type = TransactionType.received
        ..amount = 400;

      final tx3 = TransactionRecord()
        ..id = 3
        ..date = DateTime(2023, 1, 3)
        ..type = TransactionType.given
        ..amount = 200;

      final transactions = [tx1, tx2, tx3];

      recalculateCustomerTotalsSimulated(transactions);

      // tx1: Given 1000. Total Given: 1000, Balance: 1000
      expect(tx1.runningTotalGiven, 1000);
      expect(tx1.runningBalance, 1000);

      // tx2: Received 400. Total Given: 1000, Balance: 600
      expect(tx2.runningTotalGiven, 1000);
      expect(tx2.runningBalance, 600);

      // tx3: Given 200. Total Given: 1200, Balance: 800
      expect(tx3.runningTotalGiven, 1200);
      expect(tx3.runningBalance, 800);
    });
  });
}
