import 'package:equatable/equatable.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';

class BackupStatus extends Equatable {
  const BackupStatus({
    required this.isSignedIn,
    this.email,
    this.lastBackupAt,
    this.backups = const [],
    this.interval = BackupInterval.daily,
    this.lastBackupError,
  });

  static const int maxBackups = 5;

  final bool isSignedIn;
  final String? email;
  final DateTime? lastBackupAt;
  final List<BackupRecord> backups;
  final BackupInterval interval;
  final String? lastBackupError;

  bool get hasCloudBackup => backups.isNotEmpty;

  @override
  List<Object?> get props => [
    isSignedIn,
    email,
    lastBackupAt,
    backups,
    interval,
    lastBackupError,
  ];
}
