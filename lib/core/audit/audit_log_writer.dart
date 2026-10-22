import 'package:uuid/uuid.dart';
import 'package:utang_tracker/core/audit/audit_action.dart';
import 'package:utang_tracker/core/database/app_database.dart';

/// Writes one audit row. Call this from the repository that performs the
/// change so the log cannot miss an action the user performed.
Future<void> writeAuditLog(
  AppDatabase db, {
  required AuditAction action,
  required String entityId,
  required String summary,
  required DateTime createdAt,
}) async {
  await db
      .into(db.auditLogs)
      .insert(
        AuditLogsCompanion.insert(
          id: const Uuid().v4(),
          action: action.value,
          entityId: entityId,
          summary: summary,
          createdAt: createdAt.toUtc(),
        ),
      );
}
