import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_mappers.dart';
import 'package:utang_tracker/core/utils/string_utils.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Expression<bool> get _active => _db.customers.deletedAt.isNull();

  @override
  Future<List<Customer>> getAll() async {
    final rows =
        await (_db.select(_db.customers)
              ..where((table) => table.deletedAt.isNull())
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows.map(mapCustomer).toList();
  }

  @override
  Future<List<Customer>> search(String query) async {
    final searchQuery = query.trim().toLowerCase();
    if (searchQuery.isEmpty) return getAll();

    final rows =
        await (_db.select(_db.customers)
              ..where((table) => table.deletedAt.isNull() & table.name.lower().like('%$searchQuery%'))
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows.map(mapCustomer).toList();
  }

  @override
  Future<Customer?> getById(String customerId) async {
    final row = await (_db.select(
      _db.customers,
    )..where((table) => table.id.equals(customerId) & table.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : mapCustomer(row);
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Customer name is required.');
    }
    await _ensureUniqueName(trimmed);

    final now = DateTime.now().toUtc();
    final customerId = _uuid.v4();
    await _db
        .into(_db.customers)
        .insert(
          CustomersCompanion.insert(
            id: customerId,
            name: trimmed,
            phone: Value(emptyToNull(phone)),
            notes: Value(emptyToNull(notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final created = await getById(customerId);
    return created!;
  }

  @override
  Future<Customer> update(Customer customer) async {
    final trimmed = customer.name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Customer name is required.');
    }
    await _ensureUniqueName(trimmed, excludeId: customer.id);

    final now = DateTime.now().toUtc();
    final updated =
        await (_db.update(
          _db.customers,
        )..where((table) => table.id.equals(customer.id) & table.deletedAt.isNull())).write(
          CustomersCompanion(
            name: Value(trimmed),
            phone: Value(emptyToNull(customer.phone)),
            notes: Value(emptyToNull(customer.notes)),
            updatedAt: Value(now),
          ),
        );
    if (updated == 0) {
      throw const NotFoundException('Customer not found.');
    }
    final result = await getById(customer.id);
    return result!;
  }

  @override
  Future<void> delete(String customerId) async {
    final existing = await getById(customerId);
    if (existing == null) {
      throw const NotFoundException('Customer not found.');
    }
    if (await hasDebts(customerId)) {
      throw const ConflictException(
        'Cannot delete a customer who still has unpaid debts.',
      );
    }

    final now = DateTime.now().toUtc();
    final updated =
        await (_db.update(
          _db.customers,
        )..where((table) => table.id.equals(customerId) & table.deletedAt.isNull())).write(
          CustomersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    if (updated == 0) {
      throw const NotFoundException('Customer not found.');
    }
  }

  @override
  Future<int> count() async {
    final count = countAll();
    final query = _db.selectOnly(_db.customers)
      ..addColumns([count])
      ..where(_active);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<bool> hasDebts(String customerId) async {
    final row =
        await (_db.select(_db.debts)
              ..where(
                (table) =>
                    table.customerId.equals(customerId) &
                    table.deletedAt.isNull() &
                    table.status.equals(DebtStatus.paid.value).not(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> _ensureUniqueName(String name, {String? excludeId}) async {
    final existing =
        await (_db.select(_db.customers)
              ..where((table) {
                var expr =
                    table.deletedAt.isNull() &
                    table.name.lower().equals(name.toLowerCase());
                if (excludeId != null) {
                  expr = expr & table.id.equals(excludeId).not();
                }
                return expr;
              })
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A customer with this name already exists.',
      );
    }
  }
}
