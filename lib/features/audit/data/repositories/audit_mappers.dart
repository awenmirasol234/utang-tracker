import 'package:utang_tracker/core/audit/audit_details_codec.dart';
import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';

AuditLogEntry mapAuditLogEntry(AuditLogRow row) {
  return AuditLogEntry(
    id: row.id,
    action: AuditAction.fromValue(row.action),
    entityId: row.entityId,
    summary: row.summary,
    createdAt: row.createdAt,
    details: decodeAuditDetails(row.details),
  );
}
