import 'package:utang_tracker/features/backup/domain/entities/backup_interval.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_record.dart';
import 'package:utang_tracker/features/backup/domain/entities/backup_status.dart';

abstract class CloudBackupRepository {
  Future<BackupStatus> getStatus();

  Future<BackupStatus> signIn();

  Future<void> signOut();

  Future<BackupStatus> backup({required bool interactive});

  Future<BackupStatus> restore(BackupRecord backup);

  Future<BackupStatus> setInterval(BackupInterval interval);
}
