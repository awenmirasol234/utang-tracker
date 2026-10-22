import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';

abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getAll();
}
