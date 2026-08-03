import 'package:isar/isar.dart';

part 'transaction_record.g.dart';

enum TransactionType { given, received }

@collection
class TransactionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int customerId;

  late DateTime date;

  @enumerated
  late TransactionType type;

  late double amount;

  // Running totals at the time of this transaction
  late double runningTotalGiven;
  late double runningBalance;

  String? note; // optional
}
