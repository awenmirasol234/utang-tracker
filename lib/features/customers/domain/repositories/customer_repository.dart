import 'package:utang_tracker/features/customers/domain/entities/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAll();
  Future<List<Customer>> search(String query);
  Future<Customer?> getById(String customerId);
  Future<Customer> create({required String name, String? phone, String? notes});
  Future<Customer> update(Customer customer);
  Future<void> delete(String customerId);
  Future<int> count();
  Future<bool> hasDebts(String customerId);
}
