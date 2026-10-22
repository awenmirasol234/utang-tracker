import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';

class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.customerId,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    required this.transactionDate,
    this.dueDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
  });

  final String id;
  final String customerId;
  final Money totalAmount;
  final Money paidAmount;
  final Money balance;
  final DebtStatus status;
  final DateTime transactionDate;
  final DateTime? dueDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? customerName;

  bool get isEditable => paidAmount.isZero;

  @override
  List<Object?> get props => [
    id,
    customerId,
    totalAmount,
    paidAmount,
    balance,
    status,
    transactionDate,
    dueDate,
    notes,
    createdAt,
    updatedAt,
    customerName,
  ];
}
