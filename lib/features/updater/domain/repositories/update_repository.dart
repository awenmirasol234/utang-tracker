import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';

abstract class UpdateRepository {
  Future<AppRelease?> fetchLatestRelease();

  Future<String> downloadApk(
    ReleaseAsset asset,
    void Function(double progress) onProgress,
  );

  Future<String?> findDownloadedApk(ReleaseAsset asset);

  Future<void> saveLastCheckTime(DateTime time);
  Future<DateTime?> loadLastCheckTime();

  Future<void> saveDismissedVersion(String version);
  Future<String?> loadDismissedVersion();

  Future<void> cleanupOldApks();

  Future<String> getCurrentVersion();

  Future<List<String>> getSupportedAbis();

  Future<String> loadReleaseNotes();

  Future<bool> isAssetAvailable(ReleaseAsset asset);
}
