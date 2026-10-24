import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';

AppRelease releaseWithAssets(
  List<ReleaseAsset> assets, {
  String releaseNotes = '',
}) => AppRelease(
  version: '1.1.0',
  releaseNotes: releaseNotes,
  isDraft: false,
  isPrerelease: false,
  assets: assets,
);

class FakeUpdateRepository implements UpdateRepository {
  FakeUpdateRepository({
    required this.currentVersion,
    this.supportedAbis = const ['arm64-v8a'],
    this.release,
    this.fetchError,
    this.downloadPath,
    this.downloadedApkPath,
  });

  final String currentVersion;
  final List<String> supportedAbis;
  final AppRelease? release;
  final AppException? fetchError;
  final String? downloadPath;
  final String? downloadedApkPath;
  DateTime? savedCheckTime;
  String? dismissedVersion;
  int fetchCount = 0;
  int lastCheckReads = 0;
  int downloadCount = 0;
  String? pendingVersion;
  String? pendingPath;

  @override
  Future<AppRelease?> fetchLatestRelease() async {
    fetchCount++;
    if (fetchError case final error?) throw error;
    return release;
  }

  @override
  Future<String> getCurrentVersion() async => currentVersion;

  @override
  Future<List<String>> getSupportedAbis() async => supportedAbis;

  @override
  Future<void> saveLastCheckTime(DateTime time) async {
    savedCheckTime = time;
  }

  @override
  Future<DateTime?> loadLastCheckTime() async {
    lastCheckReads++;
    return savedCheckTime;
  }

  @override
  Future<String?> loadDismissedVersion() async => dismissedVersion;

  @override
  Future<void> saveDismissedVersion(String version) async {
    dismissedVersion = version;
  }

  @override
  Future<void> cleanupOldApks() async {}

  @override
  Future<String?> findDownloadedApk(ReleaseAsset asset) async =>
      downloadedApkPath;

  @override
  Future<String> downloadApk(
    ReleaseAsset asset,
    void Function(double progress) onProgress,
  ) async {
    final path = downloadPath;
    if (path == null) throw UnimplementedError();
    downloadCount++;
    onProgress(1);
    return path;
  }

  @override
  Future<String> loadReleaseNotes() async => '{}';

  @override
  Future<bool> isAssetAvailable(ReleaseAsset asset) async => true;

  @override
  Future<void> savePendingApk(String version, String apkPath) async {
    pendingVersion = version;
    pendingPath = apkPath;
  }

  @override
  Future<PendingApk?> loadPendingApk() async {
    if (pendingVersion == null || pendingPath == null) return null;
    return PendingApk(version: pendingVersion!, apkPath: pendingPath!);
  }

  @override
  Future<void> clearPendingApk() async {
    pendingVersion = null;
    pendingPath = null;
  }
}
