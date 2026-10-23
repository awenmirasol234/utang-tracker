import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/features/backup/data/services/database_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates and validates a consistent database snapshot', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final service = DatabaseBackupService(database);

    final snapshot = await service.createSnapshot();
    addTearDown(() async {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
    });

    expect(await snapshot.exists(), isTrue);
    await service.validate(snapshot);
  });

  test('rejects a non-database file', () async {
    final database = AppDatabase.forTesting();
    addTearDown(database.close);
    final service = DatabaseBackupService(database);
    final file = File('${Directory.systemTemp.path}/not-a-database.sqlite');
    await file.writeAsString('not a sqlite database');
    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    expect(() => service.validate(file), throwsA(isA<Exception>()));
  });
}
