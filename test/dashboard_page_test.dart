import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/recent_activity_item.dart';
import 'package:utang_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:utang_tracker/features/dashboard/presentation/pages/dashboard_page.dart';

void main() {
  testWidgets('activity date and time appear with label below amount', (
    tester,
  ) async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);

    final activityDate = DateTime(2026, 7, 15, 14, 5);
    final summary = DashboardSummary(
      outstandingBalance: Money.zero(),
      collectedToday: Money.zero(),
      activeDebtsCount: 1,
      totalCustomers: 1,
      recentActivity: [
        RecentActivityItem(
          type: RecentActivityType.payment,
          id: 'activity-id',
          debtId: 'debt-id',
          customerName: 'Maria Santos',
          amount: Money.fromPesoString('125'),
          date: activityDate,
          paymentMethod: 'GCash',
        ),
        RecentActivityItem(
          type: RecentActivityType.debt,
          id: 'second-activity-id',
          debtId: 'second-debt-id',
          customerName: 'Juan Dela Cruz',
          amount: Money.fromPesoString('300'),
          date: DateTime(2026, 7, 14, 9, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(summary),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    final dateAndTime = find.text(
      DateFormatters.smartTimestamp(
        activityDate,
        relativeTo: DateTime.now(),
        locale: 'en-US',
        use24HourFormat: false,
      ),
    );
    final label = find.text('Payment');
    final amount = find.text(Money.fromPesoString('125').format());

    expect(dateAndTime, findsOneWidget);
    expect(tester.widget<Text>(dateAndTime).style?.fontWeight, FontWeight.w500);
    expect(label, findsOneWidget);
    expect(find.text('GCash'), findsNothing);
    expect(amount, findsOneWidget);
    expect(
      tester.getTopLeft(label).dy,
      greaterThan(tester.getTopLeft(amount).dy),
    );
    expect(
      tester.getTopLeft(label).dy,
      closeTo(tester.getTopLeft(dateAndTime).dy, 1),
    );
    expect(
      tester.getTopRight(label).dx,
      closeTo(tester.getTopRight(amount).dx, 1),
    );
    expect(find.byType(AppCard), findsNWidgets(2));
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  const _FakeDashboardRepository(this.summary);

  final DashboardSummary summary;

  @override
  Future<DashboardSummary> getDashboardData() async => summary;
}
