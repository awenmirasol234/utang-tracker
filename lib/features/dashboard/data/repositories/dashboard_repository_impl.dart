import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/recent_activity_item.dart';
import 'package:utang_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(
    this._customers,
    this._debts,
    this._payments, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final CustomerRepository _customers;
  final DebtRepository _debts;
  final PaymentRepository _payments;
  final DateTime Function() _now;

  @override
  Future<DashboardSummary> getDashboardData() async {
    final now = _now();
    final start = startOfLocalDay(now);
    final end = endOfLocalDay(now);

    final outstandingCentavos = await _debts.outstandingBalanceCentavos();
    final collectedToday = await _payments.collectedBetween(
      start: start,
      end: end,
    );
    final activeDebts = await _debts.countActive();
    final totalCustomers = await _customers.count();
    final recentPayments = await _payments.getRecent(
      limit: AppConstants.recentItemsLimit,
    );
    final recentDebts = await _debts.getRecent(
      limit: AppConstants.recentItemsLimit,
    );

    final recentActivity = <RecentActivityItem>[
      ...recentDebts.map(
        (debt) => RecentActivityItem(
          type: RecentActivityType.debt,
          id: debt.id,
          debtId: debt.id,
          customerName: debt.customerName ?? 'Customer',
          amount: debt.totalAmount,
          date: debt.createdAt,
        ),
      ),
      ...recentPayments.map(
        (payment) => RecentActivityItem(
          type: RecentActivityType.payment,
          id: payment.id,
          debtId: payment.debtId,
          customerName: payment.customerName ?? 'Customer',
          amount: payment.amount,
          date: payment.createdAt,
          paymentMethod: payment.paymentMethod,
        ),
      ),
    ]..sort((first, second) => second.date.compareTo(first.date));

    return DashboardSummary(
      outstandingBalance: Money.fromCentavos(outstandingCentavos),
      collectedToday: collectedToday,
      activeDebtsCount: activeDebts,
      totalCustomers: totalCustomers,
      recentActivity: recentActivity
          .take(AppConstants.recentItemsLimit)
          .toList(growable: false),
    );
  }
}
