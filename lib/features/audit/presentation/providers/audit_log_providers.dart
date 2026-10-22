import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/audit/audit_log_entry.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';

final auditLogEntriesProvider = FutureProvider<List<AuditLogEntry>>((ref) async {
  return ref.watch(auditLogRepositoryProvider).getAll();
});
