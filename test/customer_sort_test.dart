import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer_sort_order.dart';

void main() {
  final older = _customer('1', 'Ana', DateTime.utc(2024));
  final middle = _customer('2', 'bert', DateTime.utc(2025));
  final newer = _customer('3', 'Cara', DateTime.utc(2026));

  test('sorts customers by name A-Z', () {
    final sorted = applyCustomerSort([
      newer,
      middle,
      older,
    ], CustomerSortOrder.nameAsc);

    expect(sorted.map((customer) => customer.name), ['Ana', 'bert', 'Cara']);
  });

  test('sorts customers by name Z-A', () {
    final sorted = applyCustomerSort([
      older,
      middle,
      newer,
    ], CustomerSortOrder.nameDesc);

    expect(sorted.map((customer) => customer.name), ['Cara', 'bert', 'Ana']);
  });

  test('sorts customers by newest', () {
    final sorted = applyCustomerSort([
      older,
      newer,
      middle,
    ], CustomerSortOrder.newest);

    expect(sorted.map((customer) => customer.id), ['3', '2', '1']);
  });

  test('sorts customers by oldest', () {
    final sorted = applyCustomerSort([
      newer,
      older,
      middle,
    ], CustomerSortOrder.oldest);

    expect(sorted.map((customer) => customer.id), ['1', '2', '3']);
  });
}

Customer _customer(String customerId, String name, DateTime createdAt) {
  return Customer(
    id: customerId,
    name: name,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
