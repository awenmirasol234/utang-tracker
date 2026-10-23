import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/database/database_location.dart';
import 'package:utang_tracker/core/error/app_exception.dart';

class DatabaseBackupService {
  DatabaseBackupService(this._database);

  final AppDatabase _database;

  Future<void> closeDatabase() => _database.close();

  Future<File> createSnapshot() async {
    final temporaryDirectory = Directory.systemTemp;
    final snapshotPath = p.join(
      temporaryDirectory.path,
      'utang_tracker_backup_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final snapshot = File(snapshotPath);
    if (await snapshot.exists()) {
      await snapshot.delete();
    }

    final escapedPath = snapshotPath.replaceAll("'", "''");
    try {
      await _database.customStatement("VACUUM INTO '$escapedPath'");
      await validate(snapshot);
      return snapshot;
    } catch (_) {
      if (await snapshot.exists()) {
        await snapshot.delete();
      }
      rethrow;
    }
  }

  Future<void> validate(File snapshot) async {
    if (!await snapshot.exists()) {
      throw const AppException('The backup file could not be found.');
    }

    Database? sqliteDatabase;
    try {
      sqliteDatabase = sqlite3.open(snapshot.path, mode: OpenMode.readOnly);
      final applicationId = sqliteDatabase
          .select('PRAGMA application_id')
          .first['application_id'];
      final schemaVersion = sqliteDatabase
          .select('PRAGMA user_version')
          .first['user_version'];
      final tableNames = sqliteDatabase
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();

      const requiredTables = {
        'customers',
        'debts',
        'debt_items',
        'payments',
        'audit_logs',
      };
      if (applicationId != AppDatabase.applicationId ||
          schemaVersion < 1 ||
          schemaVersion > AppDatabase.currentSchemaVersion ||
          !tableNames.containsAll(requiredTables)) {
        throw const AppException(
          'This backup is not compatible with this version of Utang Tracker.',
        );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('The backup file is invalid or damaged.');
    } finally {
      sqliteDatabase?.close();
    }
  }

  Future<void> replaceLiveDatabase(File snapshot) async {
    final liveFile = await DatabaseLocation.liveFile();
    final rollbackFile = File('${liveFile.path}.restore-rollback');
    final walFile = File('${liveFile.path}-wal');
    final shmFile = File('${liveFile.path}-shm');

    if (await rollbackFile.exists()) {
      await rollbackFile.delete();
    }
    if (await liveFile.exists()) {
      await liveFile.copy(rollbackFile.path);
    }

    try {
      await snapshot.copy(liveFile.path);
      if (await walFile.exists()) {
        await walFile.delete();
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
      if (await rollbackFile.exists()) {
        await rollbackFile.delete();
      }
    } catch (_) {
      if (await rollbackFile.exists()) {
        await rollbackFile.copy(liveFile.path);
      }
      throw const AppException('The local database could not be restored.');
    }
  }
}
