import 'package:equatable/equatable.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';

class BackupStatus extends Equatable {
  const BackupStatus({
    required this.isSignedIn,
    this.email,
    this.lastBackupAt,
    this.hasCloudBackup = false,
    this.backups = const [],
    this.interval = BackupInterval.daily,
    this.lastBackupError,
  });

  final bool isSignedIn;
  final String? email;
  final DateTime? lastBackupAt;
  final bool hasCloudBackup;
  final List<BackupRecord> backups;
  final BackupInterval interval;
  final String? lastBackupError;

  @override
  List<Object?> get props => [
    isSignedIn,
    email,
    lastBackupAt,
    hasCloudBackup,
    backups,
    interval,
    lastBackupError,
  ];
}
