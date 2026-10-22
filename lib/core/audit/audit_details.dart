import 'dart:convert';

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

/// Encodes the details for storage. An empty list is stored as NULL.
String? encodeAuditDetails(List<AuditChangeDetail> details) {
  if (details.isEmpty) return null;
  final payload = details
      .map(
        (detail) => {
          'field': detail.field,
          'before': detail.before,
          'after': detail.after,
        },
      )
      .toList();
  return jsonEncode(payload);
}

/// Decodes the stored details. Unreadable payloads yield no details instead
/// of breaking the log.
List<AuditChangeDetail> decodeAuditDetails(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final details = <AuditChangeDetail>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    final field = _readString(entry, 'field');
    if (field == null) continue;
    details.add(
      AuditChangeDetail(
        field: field,
        before: _readString(entry, 'before'),
        after: _readString(entry, 'after'),
      ),
    );
  }
  return details;
}

String? _readString(Map<dynamic, dynamic> entry, String key) {
  final value = entry[key];
  if (value is String) return value;
  return null;
}
