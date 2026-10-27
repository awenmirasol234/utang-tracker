import 'package:utang_tracker/features/customers/domain/entities/customer.dart';

enum CustomerSortOrder {
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  newest('Newest'),
  oldest('Oldest');

  const CustomerSortOrder(this.label);

  final String label;
}

List<Customer> applyCustomerSort(
  List<Customer> customers,
  CustomerSortOrder sort,
) {
  final sorted = List<Customer>.from(customers);
  final int Function(Customer first, Customer second) comparator =
      switch (sort) {
        CustomerSortOrder.nameAsc =>
          (first, second) =>
              first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        CustomerSortOrder.nameDesc =>
          (first, second) =>
              second.name.toLowerCase().compareTo(first.name.toLowerCase()),
        CustomerSortOrder.newest =>
          (first, second) => second.createdAt.compareTo(first.createdAt),
        CustomerSortOrder.oldest =>
          (first, second) => first.createdAt.compareTo(second.createdAt),
      };
  sorted.sort(comparator);
  return sorted;
}
