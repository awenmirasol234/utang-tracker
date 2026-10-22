import 'package:drift/drift.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/features/audit/data/repositories/audit_mappers.dart';
import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';
import 'package:utang_tracker/features/audit/domain/repositories/audit_log_repository.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  AuditLogRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<AuditLogEntry>> getAll() async {
    final rows =
        await (_db.select(_db.auditLogs)
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    return rows.map(mapAuditLogEntry).toList();
  }
}
