import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

class CustomerDetailData {
  const CustomerDetailData({
    required this.customer,
    required this.debts,
    required this.payments,
    required this.outstandingBalance,
  });

  final Customer customer;
  final List<Debt> debts;
  final List<Payment> payments;
  final Money outstandingBalance;
}

class GetCustomerDetail {
  const GetCustomerDetail({
    required CustomerRepository customers,
    required DebtRepository debts,
    required PaymentRepository payments,
  }) : _customers = customers,
       _debts = debts,
       _payments = payments;

  final CustomerRepository _customers;
  final DebtRepository _debts;
  final PaymentRepository _payments;

  Future<CustomerDetailData?> call(String customerId) async {
    final customer = await _customers.getById(customerId);
    if (customer == null) return null;

    final debtList = await _debts.getByCustomer(customerId);
    final paymentList = await _payments.getByCustomer(customerId);

    var outstanding = Money.zero();
    for (final debt in debtList) {
      outstanding = outstanding + debt.balance;
    }

    return CustomerDetailData(
      customer: customer,
      debts: debtList,
      payments: paymentList,
      outstandingBalance: outstanding,
    );
  }
}
