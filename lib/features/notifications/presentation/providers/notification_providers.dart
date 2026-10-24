import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/notifications/domain/entities/debt_notification.dart';

final debtNotificationsProvider =
    AsyncNotifierProvider<DebtNotificationsNotifier, DebtNotificationFeed>(
      DebtNotificationsNotifier.new,
    );

class DebtNotificationsNotifier extends AsyncNotifier<DebtNotificationFeed> {
  @override
  Future<DebtNotificationFeed> build() async {
    ref.watch(dataVersionProvider);
    final debts = await ref.watch(debtRepositoryProvider).getAll();
    return DebtNotificationFeed.fromDebts(debts, now: DateTime.now());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final debts = await ref.read(debtRepositoryProvider).getAll();
      return DebtNotificationFeed.fromDebts(debts, now: DateTime.now());
    });
  }
}
