import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';

Money computeTotal(Iterable<Money> prices) {
  return prices.fold(Money.zero(), (total, price) => total + price);
}

DebtStatus deriveStatus({
  required Money totalAmount,
  required Money paidAmount,
}) {
  if (paidAmount.centavos <= 0) {
    return DebtStatus.unpaid;
  }
  if (paidAmount.centavos >= totalAmount.centavos) {
    return DebtStatus.paid;
  }
  return DebtStatus.partial;
}
