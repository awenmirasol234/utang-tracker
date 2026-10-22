import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/usecases/record_payment.dart';

final recordPaymentUseCaseProvider = Provider((ref) {
  return RecordPayment(ref.watch(paymentRepositoryProvider));
});

class PaymentFilters {
  const PaymentFilters({
    this.searchQuery = '',
    this.paymentMethod,
    this.startDate,
    this.endDate,
  });

  final String searchQuery;
  final String? paymentMethod;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      paymentMethod != null ||
      startDate != null ||
      endDate != null;
}

class PaymentFiltersNotifier extends Notifier<PaymentFilters> {
  @override
  PaymentFilters build() => const PaymentFilters();

  void setSearchQuery(String query) {
    state = PaymentFilters(
      searchQuery: query,
      paymentMethod: state.paymentMethod,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  void setPaymentMethod(String? method) {
    state = PaymentFilters(
      searchQuery: state.searchQuery,
      paymentMethod: method,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  void setDateRange({DateTime? startDate, DateTime? endDate}) {
    state = PaymentFilters(
      searchQuery: state.searchQuery,
      paymentMethod: state.paymentMethod,
      startDate: startDate,
      endDate: endDate,
    );
  }

  void clear() {
    state = const PaymentFilters();
  }
}

final paymentFiltersProvider =
    NotifierProvider<PaymentFiltersNotifier, PaymentFilters>(
      PaymentFiltersNotifier.new,
    );

class PaymentFilterOptions {
  const PaymentFilterOptions({
    required this.paymentMethods,
    required this.hasPayments,
  });

  final List<String> paymentMethods;
  final bool hasPayments;
}

final paymentFilterOptionsProvider = FutureProvider<PaymentFilterOptions>((
  ref,
) async {
  final payments = await ref.watch(paymentRepositoryProvider).getAll();
  final methods =
      payments
          .map((payment) => payment.paymentMethod)
          .where((method) => method.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return PaymentFilterOptions(
    paymentMethods: methods,
    hasPayments: payments.isNotEmpty,
  );
});

final paymentsListProvider =
    AsyncNotifierProvider<PaymentsListNotifier, List<Payment>>(
      PaymentsListNotifier.new,
    );

class PaymentsListNotifier extends AsyncNotifier<List<Payment>> {
  @override
  Future<List<Payment>> build() async {
    final filters = ref.watch(paymentFiltersProvider);
    final payments = await ref.watch(paymentRepositoryProvider).getAll();
    return _applyFilters(payments, filters);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final filters = ref.read(paymentFiltersProvider);
      final payments = await ref.read(paymentRepositoryProvider).getAll();
      return _applyFilters(payments, filters);
    });
  }

  List<Payment> _applyFilters(List<Payment> payments, PaymentFilters filters) {
    final query = filters.searchQuery.trim().toLowerCase();

    return payments.where((payment) {
      if (query.isNotEmpty) {
        final name = payment.customerName?.toLowerCase() ?? '';
        if (!name.contains(query)) return false;
      }

      if (filters.paymentMethod != null &&
          payment.paymentMethod != filters.paymentMethod) {
        return false;
      }

      final paymentDay = startOfLocalDay(payment.paymentDate);

      if (filters.startDate != null) {
        final startDay = DateTime(
          filters.startDate!.year,
          filters.startDate!.month,
          filters.startDate!.day,
        );
        if (paymentDay.isBefore(startDay)) return false;
      }

      if (filters.endDate != null) {
        final endDay = DateTime(
          filters.endDate!.year,
          filters.endDate!.month,
          filters.endDate!.day,
        );
        if (paymentDay.isAfter(endDay)) return false;
      }

      return true;
    }).toList();
  }
}
