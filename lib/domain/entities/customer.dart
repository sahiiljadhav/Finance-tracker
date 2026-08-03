import 'package:isar/isar.dart';

part 'customer.g.dart';

enum RepaymentFrequency { daily, monthly }

@collection
class Customer {
  Id id = Isar.autoIncrement;

  late String name;

  late DateTime createdDate;

  @enumerated
  RepaymentFrequency frequency = RepaymentFrequency.daily; // Default to daily for existing
}
