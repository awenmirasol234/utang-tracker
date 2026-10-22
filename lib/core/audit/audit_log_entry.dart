import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/audit/audit_action.dart';

class AuditLogEntry extends Equatable {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityId,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final AuditAction action;
  final String entityId;
  final String summary;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, action, entityId, summary, createdAt];
}
