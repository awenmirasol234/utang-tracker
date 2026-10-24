import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

class PaymentOperations {
  const PaymentOperations(this._repository);

  final PaymentRepository _repository;

  Future<Payment> recordPayment({
    required String debtId,
    required Money amount,
    required DateTime paymentDate,
    required String paymentMethod,
    String? notes,
  }) {
    return _repository.recordPayment(
      debtId: debtId,
      amount: amount,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }
}
