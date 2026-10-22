import 'package:utang_tracker/core/domain/audit_change_detail.dart';

/// Builds a detail row only when the value actually changed.
List<AuditChangeDetail> auditChange({
  required String field,
  String? before,
  String? after,
}) {
  if (before == after) return const [];
  return [AuditChangeDetail(field: field, before: before, after: after)];
}
