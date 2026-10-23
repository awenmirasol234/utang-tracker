import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';

void main() {
  final now = DateTime(2026, 7, 20, 10);

  Debt debt({
    DateTime? dueDate,
    DebtStatus status = DebtStatus.unpaid,
    Money? balance,
  }) {
    return Debt(
      id: 'debt-1',
      customerId: 'customer-1',
      totalAmount: Money.fromPesoString('100'),
      paidAmount: Money.zero(),
      balance: balance ?? Money.fromPesoString('50'),
      status: status,
      transactionDate: DateTime(2026, 7, 1),
      dueDate: dueDate,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
  }

  group('isOverdue', () {
    test('is true once the due day has passed', () {
      final subject = debt(dueDate: DateTime(2026, 7, 19));

      expect(subject.isOverdue(now: now), isTrue);
    });

    test('is false on the due day itself', () {
      final subject = debt(dueDate: DateTime(2026, 7, 20));

      expect(subject.isOverdue(now: now), isFalse);
    });

    test('is false without a due date', () {
      final subject = debt();

      expect(subject.isOverdue(now: now), isFalse);
    });

    test('is false for a paid debt', () {
      final subject = debt(
        dueDate: DateTime(2026, 7, 19),
        status: DebtStatus.paid,
        balance: Money.zero(),
      );

      expect(subject.isOverdue(now: now), isFalse);
    });

    test('is false when there is no open balance', () {
      final subject = debt(
        dueDate: DateTime(2026, 7, 19),
        balance: Money.zero(),
      );

      expect(subject.isOverdue(now: now), isFalse);
    });
  });
}
