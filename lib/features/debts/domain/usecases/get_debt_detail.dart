import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

class DebtDetailData {
  const DebtDetailData({required this.detail, required this.payments});

  final DebtDetail detail;
  final List<Payment> payments;
}

class GetDebtDetail {
  const GetDebtDetail({
    required DebtRepository debts,
    required PaymentRepository payments,
  }) : _debts = debts,
       _payments = payments;

  final DebtRepository _debts;
  final PaymentRepository _payments;

  Future<DebtDetailData?> call(String debtId) async {
    final detail = await _debts.getById(debtId);
    if (detail == null) return null;

    final payments = await _payments.getByDebt(debtId);

    return DebtDetailData(detail: detail, payments: payments);
  }
}
