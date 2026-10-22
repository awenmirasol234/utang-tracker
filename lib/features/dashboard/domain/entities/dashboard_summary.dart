import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/dashboard/domain/entities/recent_activity_item.dart';

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.outstandingBalance,
    required this.collectedToday,
    required this.activeDebtsCount,
    required this.totalCustomers,
    required this.recentActivity,
  });

  final Money outstandingBalance;
  final Money collectedToday;
  final int activeDebtsCount;
  final int totalCustomers;
  final List<RecentActivityItem> recentActivity;

  @override
  List<Object?> get props => [
    outstandingBalance,
    collectedToday,
    activeDebtsCount,
    totalCustomers,
    recentActivity,
  ];
}
