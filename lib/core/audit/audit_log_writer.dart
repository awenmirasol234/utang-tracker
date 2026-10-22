import 'package:utang_tracker/core/database/app_database.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:uuid/uuid.dart';

/// Writes one audit row. Call this from the repository that performs the
/// change so the log cannot miss an action the user performed.
/// [createdAt] must be UTC, like every other timestamp written by the
/// repository layer.
Future<void> writeAuditLog(
  AppDatabase db, {
  required AuditAction action,
  required String entityId,
  required String summary,
  required DateTime createdAt,
  Uuid? uuid,
}) async {
  await db
      .into(db.auditLogs)
      .insert(
        AuditLogsCompanion.insert(
          id: (uuid ?? const Uuid()).v4(),
          action: action.value,
          entityId: entityId,
          summary: summary,
          createdAt: createdAt,
        ),
      );
}
