import 'package:equatable/equatable.dart';
import 'package:utang_tracker/core/domain/audit_action.dart';
import 'package:utang_tracker/core/domain/audit_change_detail.dart';

class AuditLogEntry extends Equatable {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityId,
    required this.summary,
    required this.createdAt,
    this.details = const [],
  });

  final String id;
  final AuditAction action;
  final String entityId;
  final String summary;
  final DateTime createdAt;

  /// The fields the change touched. Empty for entries written before the
  /// details were recorded.
  final List<AuditChangeDetail> details;

  @override
  List<Object?> get props => [id, action, entityId, summary, createdAt, details];
}
