import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';

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

  /// Whether the debt still has an amount to collect.
  bool get hasOpenBalance => balance.isPositive;

  /// Whether the debt is past its due date and still has an open balance.
  bool isOverdue({required DateTime now}) {
    final dueDate = this.dueDate;
    if (dueDate == null || status == DebtStatus.paid || !hasOpenBalance) {
      return false;
    }
    return startOfLocalDay(dueDate).isBefore(startOfLocalDay(now));
  }

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
