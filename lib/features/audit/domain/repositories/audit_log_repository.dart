import 'package:utang_tracker/core/audit/audit_log_entry.dart';

abstract class AuditLogRepository {
  Future<List<AuditLogEntry>> getAll();
}
