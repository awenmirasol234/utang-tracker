import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/money.dart';

class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.customerName,
    this.customerId,
  });

  final String id;
  final String debtId;
  final Money amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;

  final String? customerName;
  final String? customerId;

  @override
  List<Object?> get props => [
    id,
    debtId,
    amount,
    paymentDate,
    paymentMethod,
    notes,
    createdAt,
    customerName,
    customerId,
  ];
}
