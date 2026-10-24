import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';

enum DebtNotificationKind { overdue, dueToday, dueSoon }

class DebtNotification extends Equatable {
  const DebtNotification({
    required this.debt,
    required this.kind,
    required this.daysFromToday,
  });

  final Debt debt;
  final DebtNotificationKind kind;
  final int daysFromToday;

  DateTime get dueDate => debt.dueDate!;

  @override
  List<Object?> get props => [debt, kind, daysFromToday];
}

class DebtNotificationFeed extends Equatable {
  const DebtNotificationFeed({required this.items});

  factory DebtNotificationFeed.fromDebts(
    Iterable<Debt> debts, {
    required DateTime now,
    int upcomingDays = 7,
  }) {
    final today = startOfLocalDay(now);
    final items = <DebtNotification>[];

    for (final debt in debts) {
      final dueDate = debt.dueDate;
      if (dueDate == null ||
          debt.status == DebtStatus.paid ||
          !debt.hasOpenBalance) {
        continue;
      }

      final daysFromToday = startOfLocalDay(dueDate).difference(today).inDays;
      if (daysFromToday > upcomingDays) continue;

      final DebtNotificationKind kind;
      if (debt.isOverdue(now: now)) {
        kind = DebtNotificationKind.overdue;
      } else if (daysFromToday == 0) {
        kind = DebtNotificationKind.dueToday;
      } else {
        kind = DebtNotificationKind.dueSoon;
      }
      items.add(
        DebtNotification(debt: debt, kind: kind, daysFromToday: daysFromToday),
      );
    }

    items.sort((first, second) {
      final kindOrder = first.kind.index.compareTo(second.kind.index);
      if (kindOrder != 0) return kindOrder;

      final dueOrder = first.dueDate.compareTo(second.dueDate);
      if (dueOrder != 0) return dueOrder;

      return second.debt.balance.centavos.compareTo(
        first.debt.balance.centavos,
      );
    });
    return DebtNotificationFeed(items: List.unmodifiable(items));
  }

  final List<DebtNotification> items;

  List<DebtNotification> byKind(DebtNotificationKind kind) =>
      items.where((item) => item.kind == kind).toList(growable: false);

  int get urgentCount =>
      items.where((item) => item.kind != DebtNotificationKind.dueSoon).length;

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}
