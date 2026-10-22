import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';

abstract class PaymentRepository {
  Future<List<Payment>> getAll();
  Future<List<Payment>> getByDebt(String debtId);
  Future<List<Payment>> getByCustomer(String customerId);
  Future<List<Payment>> getRecent({int limit = 5});
  Future<Money> collectedBetween({
    required DateTime start,
    required DateTime end,
  });
  Future<Payment> recordPayment({
    required String debtId,
    required Money amount,
    required DateTime paymentDate,
    required String paymentMethod,
    String? notes,
  });
}
