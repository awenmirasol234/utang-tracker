import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/notifications/domain/entities/debt_notification.dart';

void main() {
  group('DebtNotificationFeed', () {
    final now = DateTime(2026, 7, 15, 14);

    test('groups overdue, today, and next-seven-day active debts', () {
      final feed = DebtNotificationFeed.fromDebts([
        _debt('future', dueDate: DateTime(2026, 7, 23)),
        _debt('soon', dueDate: DateTime(2026, 7, 18)),
        _debt('today', dueDate: DateTime(2026, 7, 15, 23, 30)),
        _debt('overdue', dueDate: DateTime(2026, 7, 13)),
        _debt(
          'paid',
          dueDate: DateTime(2026, 7, 14),
          status: DebtStatus.paid,
          balance: Money.zero(),
        ),
        _debt('no-date'),
      ], now: now);

      expect(feed.items.map((item) => item.debt.id), [
        'overdue',
        'today',
        'soon',
      ]);
      expect(feed.byKind(DebtNotificationKind.overdue), hasLength(1));
      expect(feed.byKind(DebtNotificationKind.dueToday), hasLength(1));
      expect(feed.byKind(DebtNotificationKind.dueSoon), hasLength(1));
      expect(feed.urgentCount, 2);
    });

    test('keeps future alerts quiet until seven days before', () {
      final feed = DebtNotificationFeed.fromDebts([
        _debt('later', dueDate: DateTime(2026, 7, 22)),
      ], now: now);

      expect(feed.items.single.daysFromToday, 7);
      expect(feed.urgentCount, 0);
    });
  });
}

Debt _debt(
  String debtId, {
  DateTime? dueDate,
  DebtStatus status = DebtStatus.unpaid,
  Money? balance,
}) {
  final date = DateTime(2026, 7, 1);
  return Debt(
    id: debtId,
    customerId: 'customer-$debtId',
    totalAmount: Money.fromPesos(100),
    paidAmount: Money.zero(),
    balance: balance ?? Money.fromPesos(100),
    status: status,
    transactionDate: date,
    dueDate: dueDate,
    createdAt: date,
    updatedAt: date,
    customerName: 'Customer $debtId',
  );
}
