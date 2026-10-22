import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/money.dart';

enum RecentActivityType {
  debt,
  payment;

  String get label => switch (this) {
    RecentActivityType.debt => 'Debt',
    RecentActivityType.payment => 'Payment',
  };
}

class RecentActivityItem extends Equatable {
  const RecentActivityItem({
    required this.type,
    required this.id,
    required this.debtId,
    required this.customerName,
    required this.amount,
    required this.date,
    this.paymentMethod,
  });

  final RecentActivityType type;
  final String id;
  final String debtId;
  final String customerName;
  final Money amount;
  final DateTime date;
  final String? paymentMethod;

  @override
  List<Object?> get props => [
    type,
    id,
    debtId,
    customerName,
    amount,
    date,
    paymentMethod,
  ];
}
