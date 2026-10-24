import 'package:drift/drift.dart';
import 'package:utang_tracker/core/audit/audit_details.dart';
import 'package:utang_tracker/core/audit/audit_log_writer.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/domain/audit_change_detail.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/utils/string_utils.dart';
import 'package:utang_tracker/features/customers/data/repositories/customer_mappers.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/domain/repositories/customer_repository.dart';
import 'package:uuid/uuid.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(this._db, {Uuid? uuid, DateTime Function()? now})
    : _uuid = uuid ?? const Uuid(),
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  Expression<bool> get _active => _db.customers.deletedAt.isNull();
  Expression<bool> get _activeDebt => _db.debts.deletedAt.isNull();

  @override
  Future<List<Customer>> getAll() async {
    final rows =
        await (_db.select(_db.customers)
              ..where((table) => _active)
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
              ..where(
                (table) => _active & table.name.lower().like('%$searchQuery%'),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows.map(mapCustomer).toList();
  }

  @override
  Future<Customer?> getById(String customerId) async {
    final row =
        await (_db.select(_db.customers)
              ..where((table) => table.id.equals(customerId) & _active))
            .getSingleOrNull();
    if (row == null) return null;
    return mapCustomer(row);
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Name is required.');
    }
    await _ensureUniqueName(trimmed);

    final now = _now().toUtc();
    final customerId = _uuid.v4();
    final normalizedPhone = emptyToNull(phone);
    final normalizedNotes = emptyToNull(notes);
    await _db
        .into(_db.customers)
        .insert(
          CustomersCompanion.insert(
            id: customerId,
            name: trimmed,
            phone: Value(normalizedPhone),
            notes: Value(normalizedNotes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await writeAuditLog(
      _db,
      action: AuditAction.customerCreated,
      entityId: customerId,
      summary: 'Added customer $trimmed',
      createdAt: now,
      details: [
        AuditChangeDetail(field: 'Name', after: trimmed),
        if (normalizedPhone != null)
          AuditChangeDetail(field: 'Phone', after: normalizedPhone),
        if (normalizedNotes != null)
          AuditChangeDetail(field: 'Notes', after: normalizedNotes),
      ],
      uuid: _uuid,
    );
    final created = await getById(customerId);
    return created!;
  }

  @override
  Future<Customer> update(Customer customer) async {
    final trimmed = customer.name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Name is required.');
    }
    final previous = await getById(customer.id);
    if (previous == null) {
      throw const NotFoundException('Customer not found.');
    }
    await _ensureUniqueName(trimmed, excludeId: customer.id);

    final now = _now().toUtc();
    final normalizedPhone = emptyToNull(customer.phone);
    final normalizedNotes = emptyToNull(customer.notes);
    final updated =
        await (_db.update(
          _db.customers,
        )..where((table) => table.id.equals(customer.id) & _active)).write(
          CustomersCompanion(
            name: Value(trimmed),
            phone: Value(normalizedPhone),
            notes: Value(normalizedNotes),
            updatedAt: Value(now),
          ),
        );
    if (updated == 0) {
      throw const NotFoundException('Customer not found.');
    }
    await writeAuditLog(
      _db,
      action: AuditAction.customerUpdated,
      entityId: customer.id,
      summary: 'Updated customer $trimmed',
      createdAt: now,
      details: [
        ...auditChange(field: 'Name', before: previous.name, after: trimmed),
        ...auditChange(
          field: 'Phone',
          before: previous.phone,
          after: normalizedPhone,
        ),
        ...auditChange(
          field: 'Notes',
          before: previous.notes,
          after: normalizedNotes,
        ),
      ],
      uuid: _uuid,
    );
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

    final now = _now().toUtc();
    final updated =
        await (_db.update(
          _db.customers,
        )..where((table) => table.id.equals(customerId) & _active)).write(
          CustomersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    if (updated == 0) {
      throw const NotFoundException('Customer not found.');
    }
    await writeAuditLog(
      _db,
      action: AuditAction.customerDeleted,
      entityId: customerId,
      summary: 'Deleted customer ${existing.name}',
      createdAt: now,
      details: [
        AuditChangeDetail(field: 'Name', before: existing.name),
        if (existing.phone != null)
          AuditChangeDetail(field: 'Phone', before: existing.phone),
      ],
      uuid: _uuid,
    );
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
                    _activeDebt &
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
                    _active & table.name.lower().equals(name.toLowerCase());
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
