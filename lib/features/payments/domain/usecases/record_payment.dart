import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

class RecordPayment {
  const RecordPayment(this._repository);
  final PaymentRepository _repository;

  /// The repository enforces the payment rules, so the use case only forwards
  /// the request and keeps the presentation layer away from the data layer.
  Future<Payment> call({
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
