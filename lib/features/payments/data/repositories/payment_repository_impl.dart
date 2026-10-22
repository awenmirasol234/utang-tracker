import 'package:drift/drift.dart';
import 'package:utang_tracker/core/audit/audit_details.dart';
import 'package:utang_tracker/core/audit/audit_log_writer.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/domain/audit_change_detail.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/utils/debt_math.dart';
import 'package:utang_tracker/core/utils/local_date_time.dart';
import 'package:utang_tracker/core/utils/string_utils.dart';
import 'package:utang_tracker/features/payments/data/repositories/payment_mappers.dart';
import 'package:utang_tracker/features/payments/domain/entities/payment.dart';
import 'package:utang_tracker/features/payments/domain/repositories/payment_repository.dart';
import 'package:uuid/uuid.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._db, {Uuid? uuid, DateTime Function()? now})
    : _uuid = uuid ?? const Uuid(),
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _now;

  Expression<bool> get _activePayment => _db.payments.deletedAt.isNull();
  Expression<bool> get _activeDebt => _db.debts.deletedAt.isNull();
  Expression<bool> get _activeCustomer => _db.customers.deletedAt.isNull();

  @override
  Future<List<Payment>> getAll() async {
    final query =
        _db.select(_db.payments).join([
            innerJoin(_db.debts, _db.debts.id.equalsExp(_db.payments.debtId)),
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.debts.customerId),
            ),
          ])
          ..where(_activePayment & _activeDebt & _activeCustomer)
          ..orderBy([OrderingTerm.desc(_db.payments.paymentDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final payment = row.readTable(_db.payments);
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapPayment(
        payment,
        customerName: customer.name,
        customerId: debt.customerId,
      );
    }).toList();
  }

  @override
  Future<List<Payment>> getByDebt(String debtId) async {
    final rows =
        await (_db.select(_db.payments)
              ..where((table) => table.debtId.equals(debtId) & table.deletedAt.isNull())
              ..orderBy([(table) => OrderingTerm.desc(table.paymentDate)]))
            .get();
    return rows.map(mapPayment).toList();
  }

  @override
  Future<List<Payment>> getByCustomer(String customerId) async {
    final query =
        _db.select(_db.payments).join([
            innerJoin(_db.debts, _db.debts.id.equalsExp(_db.payments.debtId)),
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.debts.customerId),
            ),
          ])
          ..where(
            _db.debts.customerId.equals(customerId) &
                _activePayment &
                _activeDebt &
                _activeCustomer,
          )
          ..orderBy([OrderingTerm.desc(_db.payments.paymentDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final payment = row.readTable(_db.payments);
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapPayment(
        payment,
        customerName: customer.name,
        customerId: debt.customerId,
      );
    }).toList();
  }

  @override
  Future<List<Payment>> getRecent({int limit = 5}) async {
    final query =
        _db.select(_db.payments).join([
            innerJoin(_db.debts, _db.debts.id.equalsExp(_db.payments.debtId)),
            innerJoin(
              _db.customers,
              _db.customers.id.equalsExp(_db.debts.customerId),
            ),
          ])
          ..where(_activePayment & _activeDebt & _activeCustomer)
          ..orderBy([OrderingTerm.desc(_db.payments.createdAt)])
          ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      final payment = row.readTable(_db.payments);
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);
      return mapPayment(
        payment,
        customerName: customer.name,
        customerId: debt.customerId,
      );
    }).toList();
  }

  @override
  Future<Money> collectedBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final sum = _db.payments.amount.sum();
    final query = _db.selectOnly(_db.payments)
      ..addColumns([sum])
      ..where(
        _activePayment &
            _db.payments.paymentDate.isBetweenValues(
              start.toUtc(),
              end.toUtc(),
            ),
      );
    final row = await query.getSingle();
    return Money.fromCentavos(row.read(sum) ?? 0);
  }

  @override
  Future<Payment> recordPayment({
    required String debtId,
    required Money amount,
    required DateTime paymentDate,
    required String paymentMethod,
    String? notes,
  }) async {
    if (!amount.isPositive) {
      throw const ValidationException(
        'Payment amount must be greater than zero.',
      );
    }
    if (paymentMethod.trim().isEmpty) {
      throw const ValidationException('Payment method is required.');
    }

    final paymentId = _uuid.v4();
    final savedAt = _now();
    final now = savedAt.toUtc();
    final savedPaymentDate = combineLocalDateAndTime(
      paymentDate,
      savedAt,
    ).toUtc();
    final normalizedNotes = emptyToNull(notes);

    await _db.transaction(() async {
      final debt =
          await (_db.select(_db.debts)
                ..where((table) => table.id.equals(debtId) & table.deletedAt.isNull()))
              .getSingleOrNull();
      if (debt == null) {
        throw const NotFoundException('Debt not found.');
      }

      final status = DebtStatus.fromValue(debt.status);
      if (status == DebtStatus.paid) {
        throw const ConflictException('This debt is already fully paid.');
      }

      final balance = Money.fromCentavos(debt.balance);
      if (amount > balance) {
        throw ValidationException(
          'Payment cannot exceed the remaining balance of ${balance.format()}.',
        );
      }

      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              id: paymentId,
              debtId: debtId,
              amount: amount.centavos,
              paymentDate: savedPaymentDate,
              paymentMethod: paymentMethod.trim(),
              notes: Value(normalizedNotes),
              createdAt: now,
            ),
          );

      final total = Money.fromCentavos(debt.totalAmount);
      final newPaid = Money.fromCentavos(debt.paidAmount) + amount;
      final newBalance = total - newPaid;
      final newStatus = deriveStatus(totalAmount: total, paidAmount: newPaid);

      await (_db.update(
        _db.debts,
      )..where((table) => table.id.equals(debtId) & table.deletedAt.isNull())).write(
        DebtsCompanion(
          paidAmount: Value(newPaid.centavos),
          balance: Value(newBalance.centavos),
          status: Value(newStatus.value),
          updatedAt: Value(now),
        ),
      );

      final customer =
          await (_db.select(_db.customers)
                ..where((table) => table.id.equals(debt.customerId)))
              .getSingleOrNull();

      await writeAuditLog(
        _db,
        action: AuditAction.paymentRecorded,
        entityId: paymentId,
        summary:
            'Paid by ${customer?.name ?? 'Customer'} (${amount.format()})',
        createdAt: now,
        details: [
          AuditChangeDetail(field: 'Amount', after: amount.format()),
          AuditChangeDetail(field: 'Method', after: paymentMethod.trim()),
          AuditChangeDetail(
            field: 'Payment date',
            after: DateFormatters.dayKey(savedPaymentDate),
          ),
          if (normalizedNotes != null)
            AuditChangeDetail(field: 'Notes', after: normalizedNotes),
          ...auditChange(
            field: 'Remaining balance',
            before: balance.format(),
            after: newBalance.format(),
          ),
        ],
        uuid: _uuid,
      );
    });

    final row = await (_db.select(
      _db.payments,
    )..where((table) => table.id.equals(paymentId) & table.deletedAt.isNull())).getSingle();
    return mapPayment(row);
  }
}
