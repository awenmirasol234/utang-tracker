import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer_sort_order.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/features/customers/domain/usecases/customer_operations.dart';
import 'package:utang_tracker/features/customers/domain/usecases/get_customer_detail.dart';

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final customerSearchQueryProvider =
    NotifierProvider<CustomerSearchQueryNotifier, String>(
      CustomerSearchQueryNotifier.new,
    );

class CustomerSortFilterNotifier extends Notifier<CustomerSortOrder> {
  @override
  CustomerSortOrder build() => CustomerSortOrder.nameAsc;

  void setSort(CustomerSortOrder order) => state = order;
}

final customerSortOrderProvider =
    NotifierProvider<CustomerSortFilterNotifier, CustomerSortOrder>(
      CustomerSortFilterNotifier.new,
    );

final customersListProvider =
    AsyncNotifierProvider<CustomersListNotifier, List<Customer>>(
      CustomersListNotifier.new,
    );

class CustomersListNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    ref.watch(dataVersionProvider);
    final query = ref.watch(customerSearchQueryProvider);
    final sort = ref.watch(customerSortOrderProvider);
    final repo = ref.watch(customerRepositoryProvider);
    final customers = await _loadCustomers(repo, query);
    return applyCustomerSort(customers, sort);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final query = ref.read(customerSearchQueryProvider);
      final sort = ref.read(customerSortOrderProvider);
      final repo = ref.read(customerRepositoryProvider);
      final customers = await _loadCustomers(repo, query);
      return applyCustomerSort(customers, sort);
    });
  }
}

Future<List<Customer>> _loadCustomers(
  CustomerRepository repo,
  String query,
) async {
  if (query.trim().isEmpty) {
    return repo.getAll();
  }
  return repo.search(query);
}

final getCustomerDetailUseCaseProvider = Provider((ref) {
  return GetCustomerDetail(
    customers: ref.watch(customerRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
  );
});

final customerDetailProvider =
    FutureProvider.family<CustomerDetailData?, String>((ref, customerId) async {
      ref.watch(dataVersionProvider);
      return ref.watch(getCustomerDetailUseCaseProvider)(customerId);
    });

final customerOperationsProvider = Provider<CustomerOperations>((ref) {
  return CustomerOperations(ref.watch(customerRepositoryProvider));
});
