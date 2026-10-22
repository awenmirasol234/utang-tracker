import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';

void main() {
  test('schema 3 debt items migrate to piece units and final prices', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        _createIndexedTables(database);
        database.execute('''
CREATE TABLE debt_items (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit_price INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('''
INSERT INTO debt_items (
  id, debt_id, product_name, quantity, unit_price, subtotal, deleted_at
) VALUES ('item-1', 'debt-1', 'Rice', 2, 5000, 10000, NULL);
''');
        database.execute('PRAGMA user_version = 3;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final item = await database.select(database.debtItems).getSingle();

    expect(item.unit, DebtItemUnits.piece);
    expect(item.price, 10000);
    expect(database.schemaVersion, 8);
  });

  test('schema 4 custom units and subtotals migrate without changes', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        _createIndexedTables(database);
        database.execute('''
CREATE TABLE debt_items (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL DEFAULT 'piece',
  unit_price INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('''
INSERT INTO debt_items (
  id, debt_id, product_name, quantity, unit, unit_price, subtotal, deleted_at
) VALUES ('item-1', 'debt-1', 'Rice', 2, 'kg', 5000, 10000, NULL);
''');
        database.execute('PRAGMA user_version = 4;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final item = await database.select(database.debtItems).getSingle();

    expect(item.unit, DebtItemUnits.kilogram);
    expect(item.price, 10000);

    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll([
        'idx_debts_customer_id',
        'idx_debts_status',
        'idx_debts_transaction_date',
        'idx_debt_items_debt_id',
        'idx_payments_debt_id',
        'idx_payments_payment_date',
      ]),
    );
  });

  test('schema 5 creates the audit log table', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('''
CREATE TABLE debts (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  total_amount INTEGER NOT NULL,
  paid_amount INTEGER NOT NULL,
  balance INTEGER NOT NULL,
  status TEXT NOT NULL,
  transaction_date INTEGER NOT NULL,
  due_date INTEGER NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('''
CREATE TABLE debt_items (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL DEFAULT 'piece',
  price INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  payment_date INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
        database.execute('PRAGMA user_version = 5;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'audit_logs'",
        )
        .get();
    expect(tables.length, 1);

    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_audit_logs_created_at'",
        )
        .get();
    expect(indexes.length, 1);
  });

  test('schema 6 audit summaries migrate to English', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        _createVersion6Tables(database);
        database.execute('''
INSERT INTO audit_logs (id, action, entity_id, summary, created_at) VALUES
  ('log-1', 'customer_created', 'customer-1', 'Nag-add si Maria Santos', 0),
  ('log-2', 'customer_updated', 'customer-1', 'Na-update si Maria Santos', 0),
  ('log-3', 'customer_deleted', 'customer-1', 'Na-delete si Maria Santos', 0),
  ('log-4', 'debt_created', 'debt-1', 'Bag-ong utang ni Maria Santos', 0),
  ('log-5', 'debt_updated', 'debt-1', 'Na-update ang utang ni Maria Santos', 0),
  ('log-6', 'debt_items_added', 'debt-1', 'Nag-add items sa utang ni Maria Santos', 0),
  ('log-7', 'payment_recorded', 'payment-1', 'Nagbayad ni Maria Santos (₱20.00)', 0);
''');
        database.execute('PRAGMA user_version = 6;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final rows = await database.select(database.auditLogs).get();

    expect(
      rows.map((row) => row.summary),
      [
        'Added customer Maria Santos',
        'Updated customer Maria Santos',
        'Deleted customer Maria Santos',
        'New debt for Maria Santos',
        'Updated debt for Maria Santos',
        'Added items to debt for Maria Santos',
        'Paid by Maria Santos (₱20.00)',
      ],
    );
  });

  test('schema 8 adds the audit details column', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        _createVersion6Tables(database);
        database.execute('''
INSERT INTO audit_logs (id, action, entity_id, summary, created_at) VALUES
  ('log-1', 'customer_created', 'customer-1', 'Added customer Maria Santos', 0);
''');
        database.execute('PRAGMA user_version = 7;');
      },
    );
    final database = AppDatabase(executor);
    addTearDown(database.close);

    final rows = await database.select(database.auditLogs).get();

    expect(rows.length, 1);
    expect(rows.first.summary, 'Added customer Maria Santos');
    expect(rows.first.details, isNull);
  });
}

void _createVersion6Tables(dynamic database) {
  database.execute('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
  database.execute('''
CREATE TABLE debts (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  total_amount INTEGER NOT NULL,
  paid_amount INTEGER NOT NULL,
  balance INTEGER NOT NULL,
  status TEXT NOT NULL,
  transaction_date INTEGER NOT NULL,
  due_date INTEGER NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
  database.execute('''
CREATE TABLE debt_items (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL DEFAULT 'piece',
  price INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
  database.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  payment_date INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
  database.execute('''
CREATE TABLE audit_logs (
  id TEXT NOT NULL PRIMARY KEY,
  action TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  summary TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
''');
}

void _createIndexedTables(dynamic database) {
  database.execute('''
CREATE TABLE debts (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  status TEXT NOT NULL,
  transaction_date INTEGER NOT NULL
);
''');
  database.execute('''
CREATE TABLE payments (
  id TEXT NOT NULL PRIMARY KEY,
  debt_id TEXT NOT NULL,
  payment_date INTEGER NOT NULL
);
''');
}
