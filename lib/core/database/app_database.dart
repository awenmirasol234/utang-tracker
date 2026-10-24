import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:utang_tracker/core/database/database_location.dart';
import 'package:utang_tracker/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Customers, Debts, DebtItems, Payments, AuditLogs])
class AppDatabase extends _$AppDatabase {
  static const applicationId = 0x5554414e;
  static const currentSchemaVersion = 8;

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting() : super(NativeDatabase.memory());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: DatabaseLocation.databaseName,
      native: DriftNativeOptions(
        databasePath: () async => (await DatabaseLocation.liveFile()).path,
      ),
    );
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(customers, customers.deletedAt);
        await m.addColumn(debts, debts.deletedAt);
        await m.addColumn(debtItems, debtItems.deletedAt);
        await m.addColumn(payments, payments.deletedAt);
      }
      if (from < 3) {
        await customStatement('''
CREATE TABLE debt_items_new (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL REFERENCES debts (id),
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit_price INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        await customStatement('''
INSERT INTO debt_items_new (
  id, debt_id, product_name, quantity, unit_price, subtotal, deleted_at
)
SELECT id, debt_id, product_name, quantity, unit_price, subtotal, deleted_at
FROM debt_items;
''');
        await customStatement('DROP TABLE debt_items;');
        await customStatement(
          'ALTER TABLE debt_items_new RENAME TO debt_items;',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_debt_items_debt_id ON debt_items (debt_id)',
        );
      }
      if (from < 4) {
        await m.addColumn(debtItems, debtItems.unit);
      }
      if (from < 5) {
        await customStatement('''
CREATE TABLE debt_items_v5 (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL REFERENCES debts (id),
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL DEFAULT 'piece',
  price INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        await customStatement('''
INSERT INTO debt_items_v5 (
  id, debt_id, product_name, quantity, unit, price, deleted_at
)
SELECT id, debt_id, product_name, quantity, unit, subtotal, deleted_at
FROM debt_items;
''');
        await customStatement('DROP TABLE debt_items;');
        await customStatement(
          'ALTER TABLE debt_items_v5 RENAME TO debt_items;',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_debt_items_debt_id ON debt_items (debt_id)',
        );
      }
      if (from < 6) {
        // The table is created in its version 6 shape. The details column is
        // added by the version 8 step below.
        await customStatement('''
CREATE TABLE audit_logs (
  id TEXT NOT NULL PRIMARY KEY,
  action TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  summary TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
''');
      }
      if (from < 7) {
        await _translateAuditSummaries();
      }
      if (from < 8) {
        await m.addColumn(auditLogs, auditLogs.details);
      }
      await _createIndexes();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA application_id = $applicationId');
    },
  );

  /// Rewrites the Taglish audit log summaries written by earlier versions
  /// into English. Each pattern is anchored to the start of the summary and
  /// the customer name is preserved.
  Future<void> _translateAuditSummaries() async {
    const replacements = <({String legacy, String english})>[
      (legacy: 'Nag-add si ', english: 'Added customer '),
      (legacy: 'Na-update si ', english: 'Updated customer '),
      (legacy: 'Na-delete si ', english: 'Deleted customer '),
      (legacy: 'Bag-ong utang ni ', english: 'New debt for '),
      (legacy: 'Na-update ang utang ni ', english: 'Updated debt for '),
      (
        legacy: 'Nag-add items sa utang ni ',
        english: 'Added items to debt for ',
      ),
      (legacy: 'Nagbayad ni ', english: 'Paid by '),
    ];
    for (final replacement in replacements) {
      await customStatement(
        'UPDATE audit_logs SET summary = ? || SUBSTR(summary, LENGTH(?) + 1) '
        'WHERE summary LIKE ?',
        [replacement.english, replacement.legacy, '${replacement.legacy}%'],
      );
    }
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_debts_customer_id ON debts (customer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_debts_status ON debts (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_debts_transaction_date ON debts (transaction_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_debt_items_debt_id ON debt_items (debt_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_debt_id ON payments (debt_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments (payment_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at)',
    );
  }
}
