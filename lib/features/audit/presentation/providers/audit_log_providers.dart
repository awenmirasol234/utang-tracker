import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/audit/domain/entities/audit_log_entry.dart';

final auditLogEntriesProvider =
    AsyncNotifierProvider<AuditLogEntriesNotifier, List<AuditLogEntry>>(
      AuditLogEntriesNotifier.new,
    );

class AuditLogEntriesNotifier extends AsyncNotifier<List<AuditLogEntry>> {
  @override
  Future<List<AuditLogEntry>> build() {
    return ref.watch(auditLogRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(auditLogRepositoryProvider).getAll(),
    );
  }
}
