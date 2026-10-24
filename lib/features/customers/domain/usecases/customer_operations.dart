import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';

class CustomerOperations {
  const CustomerOperations(this._repository);

  final CustomerRepository _repository;

  Future<List<Customer>> getAll() => _repository.getAll();

  Future<List<Customer>> search(String query) => _repository.search(query);

  Future<Customer?> getById(String customerId) =>
      _repository.getById(customerId);

  Future<Customer> create({
    required String name,
    String? phone,
    String? notes,
  }) {
    return _repository.create(name: name, phone: phone, notes: notes);
  }

  Future<Customer> update(Customer customer) => _repository.update(customer);

  Future<void> delete(String customerId) => _repository.delete(customerId);
}
