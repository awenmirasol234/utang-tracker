import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/debts/data/repositories/debt_mappers.dart';
import 'package:utang_tracker/core/utils/date_time_utils.dart';
import 'package:utang_tracker/core/utils/debt_math.dart';
import 'package:utang_tracker/core/utils/string_utils.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/features/debts/domain/repositories/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._db, {Uuid? uuid, DateTime Function()? now})
    : _uuid = uuid ?? const Uuid(),
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  Expression<bool> get _activeDebt => _db.debts.deletedAt.isNull();

  @override
  Future<List<Debt>> getAll({DebtStatus? status}) async {
    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(_activeDebt & _db.customers.deletedAt.isNull());
    if (status != null) {
      query.where(_db.debts.status.equals(status.value));
    }
    query.orderBy([OrderingTerm.desc(_db.debts.transactionDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapDebt(debt, customerName: customer.name);
    }).toList();
  }

  @override
  Future<List<DebtDetail>> getAllWithItems() async {
    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(_activeDebt & _db.customers.deletedAt.isNull());
    query.orderBy([OrderingTerm.desc(_db.debts.transactionDate)]);

    final rows = await query.get();
    if (rows.isEmpty) {
      return [];
    }

    final debtIds = rows.map((row) => row.readTable(_db.debts).id).toList();
    final itemRows =
        await (_db.select(_db.debtItems)..where(
                  (table) =>
                      table.debtId.isIn(debtIds) & table.deletedAt.isNull(),
                ))
            .get();

    final itemsByDebt = <String, List<DebtItem>>{};
    for (final itemRow in itemRows) {
      final item = mapDebtItem(itemRow);
      itemsByDebt.putIfAbsent(item.debtId, () => []).add(item);
    }

    return rows.map((row) {
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return DebtDetail(
        debt: mapDebt(debt, customerName: customer.name),
        items: itemsByDebt[debt.id] ?? const [],
      );
    }).toList();
  }

  @override
  Future<List<Debt>> getByCustomer(String customerId) async {
    final query =
        _db.select(_db.debts).join([
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.debts.customerId),
            ),
          ])
          ..where(
            _db.debts.customerId.equals(customerId) &
                _activeDebt &
                _db.customers.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(_db.debts.transactionDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapDebt(debt, customerName: customer.name);
    }).toList();
  }

  @override
  Future<DebtDetail?> getById(String debtId) async {
    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(
      _db.debts.id.equals(debtId) &
          _activeDebt &
          _db.customers.deletedAt.isNull(),
    );

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final debtRow = row.readTable(_db.debts);
    final customer = row.readTable(_db.customers);
    final items = await (_db.select(
      _db.debtItems,
    )..where((table) => table.debtId.equals(debtId) & table.deletedAt.isNull())).get();

    return DebtDetail(
      debt: mapDebt(debtRow, customerName: customer.name),
      items: items.map(mapDebtItem).toList(),
    );
  }

  @override
  Future<List<Debt>> getRecent({int limit = 5, DebtStatus? status}) async {
    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(_activeDebt & _db.customers.deletedAt.isNull());
    if (status != null) {
      query.where(_db.debts.status.equals(status.value));
    }
    query
      ..orderBy([OrderingTerm.desc(_db.debts.createdAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapDebt(debt, customerName: customer.name);
    }).toList();
  }

  @override
  Future<Debt> create({
    String? id,
    required String customerId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) async {
    _validateItems(items);

    final customer =
        await (_db.select(_db.customers)
              ..where((table) => table.id.equals(customerId) & table.deletedAt.isNull()))
            .getSingleOrNull();
    if (customer == null) {
      throw const NotFoundException('Customer not found.');
    }

    final prepared = _prepareItems(items);
    final total = computeTotal(prepared.map((debtItem) => debtItem.price));
    final paid = Money.zero();
    final balance = total - paid;
    final status = deriveStatus(totalAmount: total, paidAmount: paid);

    final savedAt = _now();
    final now = savedAt.toUtc();
    final savedTransactionDate = combineLocalDateAndTime(
      transactionDate,
      savedAt,
    ).toUtc();
    final debtId = id ?? _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.debts)
          .insert(
            DebtsCompanion.insert(
              id: debtId,
              customerId: customerId,
              totalAmount: total.centavos,
              paidAmount: paid.centavos,
              balance: balance.centavos,
              status: status.value,
              transactionDate: savedTransactionDate,
              dueDate: Value(dueDate?.toUtc()),
              notes: Value(emptyToNull(notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );

      for (final item in prepared) {
        await _db
            .into(_db.debtItems)
            .insert(
              DebtItemsCompanion.insert(
                id: _uuid.v4(),
                debtId: debtId,
                productName: item.productName,
                quantity: item.quantity,
                unit: Value(item.unit),
                price: item.price.centavos,
              ),
            );
      }
    });

    final detail = await getById(debtId);
    return detail!.debt;
  }

  @override
  Future<Debt> update({
    required String debtId,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? notes,
    required List<DebtItemInput> items,
  }) async {
    final existing = await getById(debtId);
    if (existing == null) {
      throw const NotFoundException('Debt not found.');
    }
    if (!existing.debt.isEditable) {
      throw const ConflictException(
        'Cannot edit a debt after payments have been recorded.',
      );
    }

    _validateItems(items);
    final prepared = _prepareItems(items);
    final total = computeTotal(prepared.map((debtItem) => debtItem.price));
    final paid = Money.zero();
    final balance = total - paid;
    final status = deriveStatus(totalAmount: total, paidAmount: paid);
    final savedAt = _now();
    final now = savedAt.toUtc();
    final savedTransactionDate = combineLocalDateAndTime(
      transactionDate,
      savedAt,
    ).toUtc();

    await _db.transaction(() async {
      await (_db.update(_db.debtItems)
            ..where((table) => table.debtId.equals(debtId) & table.deletedAt.isNull()))
          .write(DebtItemsCompanion(deletedAt: Value(now)));

      final updated =
          await (_db.update(
            _db.debts,
          )..where((table) => table.id.equals(debtId) & table.deletedAt.isNull())).write(
            DebtsCompanion(
              totalAmount: Value(total.centavos),
              paidAmount: Value(paid.centavos),
              balance: Value(balance.centavos),
              status: Value(status.value),
              transactionDate: Value(savedTransactionDate),
              dueDate: Value(dueDate?.toUtc()),
              notes: Value(emptyToNull(notes)),
              updatedAt: Value(now),
            ),
          );
      if (updated == 0) {
        throw const NotFoundException('Debt not found.');
      }

      for (final item in prepared) {
        await _db
            .into(_db.debtItems)
            .insert(
              DebtItemsCompanion.insert(
                id: _uuid.v4(),
                debtId: debtId,
                productName: item.productName,
                quantity: item.quantity,
                unit: Value(item.unit),
                price: item.price.centavos,
              ),
            );
      }
    });

    final detail = await getById(debtId);
    return detail!.debt;
  }

  @override
  Future<Debt> addItems({
    required String debtId,
    required List<DebtItemInput> items,
  }) async {
    final existing = await getById(debtId);
    if (existing == null) {
      throw const NotFoundException('Debt not found.');
    }
    if (existing.debt.status == DebtStatus.paid) {
      throw const ConflictException(
        'Cannot add items to a fully paid debt.',
      );
    }

    _validateItems(items);
    final prepared = _prepareItems(items);
    final addedTotal = computeTotal(prepared.map((item) => item.price));
    final total = existing.debt.totalAmount + addedTotal;
    final paid = existing.debt.paidAmount;
    final balance = total - paid;
    final status = deriveStatus(totalAmount: total, paidAmount: paid);
    final now = _now().toUtc();

    await _db.transaction(() async {
      for (final item in prepared) {
        await _db
            .into(_db.debtItems)
            .insert(
              DebtItemsCompanion.insert(
                id: _uuid.v4(),
                debtId: debtId,
                productName: item.productName,
                quantity: item.quantity,
                unit: Value(item.unit),
                price: item.price.centavos,
              ),
            );
      }

      final updated =
          await (_db.update(
            _db.debts,
          )..where((table) => table.id.equals(debtId) & table.deletedAt.isNull())).write(
            DebtsCompanion(
              totalAmount: Value(total.centavos),
              balance: Value(balance.centavos),
              status: Value(status.value),
              updatedAt: Value(now),
            ),
          );
      if (updated == 0) {
        throw const NotFoundException('Debt not found.');
      }
    });

    final detail = await getById(debtId);
    return detail!.debt;
  }

  @override
  Future<int> countActive() async {
    final count = countAll();
    final query = _db.selectOnly(_db.debts)
      ..addColumns([count])
      ..where(
        _activeDebt &
            _db.debts.status.isIn([
              DebtStatus.unpaid.value,
              DebtStatus.partial.value,
            ]),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> outstandingBalanceCentavos() async {
    final sum = _db.debts.balance.sum();
    final query = _db.selectOnly(_db.debts)
      ..addColumns([sum])
      ..where(
        _activeDebt &
            _db.debts.status.isIn([
              DebtStatus.unpaid.value,
              DebtStatus.partial.value,
            ]),
      );
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  void _validateItems(List<DebtItemInput> items) {
    if (items.isEmpty) {
      throw const ValidationException('Add at least one debt item.');
    }
    for (final item in items) {
      if (item.productName.trim().isEmpty) {
        throw const ValidationException('Product name is required.');
      }
      if (item.quantity <= 0) {
        throw const ValidationException('Quantity must be greater than zero.');
      }
      if (item.unit.trim().isEmpty) {
        throw const ValidationException('Unit is required.');
      }
      if (item.unit.trim().length > 24) {
        throw const ValidationException('Unit must be 24 characters or fewer.');
      }
      if (!item.price.isPositive) {
        throw const ValidationException('Price must be greater than zero.');
      }
    }
  }

  List<({String productName, double quantity, String unit, Money price})>
  _prepareItems(List<DebtItemInput> items) {
    return items.map((item) {
      return (
        productName: item.productName.trim(),
        quantity: item.quantity,
        unit: DebtItemUnits.normalize(item.unit),
        price: item.price,
      );
    }).toList();
  }
}
