import 'package:pub_semver/pub_semver.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';

class CheckForUpdates {
  const CheckForUpdates(this._repository);

  final UpdateRepository _repository;

  Future<CheckResult> call({bool silent = false}) async {
    final currentVersion = await _repository.getCurrentVersion();
    final release = await _repository.fetchLatestRelease();
    await _repository.saveLastCheckTime(DateTime.now());

    if (release == null || !isNewerVersion(currentVersion, release.version)) {
      return const CheckResult(updateAvailable: false);
    }

    final dismissed = await _repository.loadDismissedVersion();
    if (silent && dismissed == release.version) {
      return const CheckResult(updateAvailable: false);
    }

    final deviceAbis = await _repository.getSupportedAbis();
    final asset = selectApkAsset(release.assets, deviceAbis);
    if (asset == null) {
      return CheckResult(
        updateAvailable: false,
        error: 'No compatible APK found in this release.',
      );
    }

    try {
      final available = await _repository.isAssetAvailable(asset);
      if (!available) {
        return const CheckResult(
          updateAvailable: false,
          error:
              'Update is being prepared, please try again in a few minutes.',
        );
      }
    } on AppException catch (appException) {
      return CheckResult(updateAvailable: false, error: appException.message);
    }

    return CheckResult(
      updateAvailable: true,
      release: release,
      asset: asset,
      currentVersion: currentVersion,
      apkPath: await _repository.findDownloadedApk(asset),
    );
  }
}

class CheckResult {
  const CheckResult({
    required this.updateAvailable,
    this.release,
    this.asset,
    this.currentVersion,
    this.apkPath,
    this.error,
  });

  final bool updateAvailable;
  final AppRelease? release;
  final ReleaseAsset? asset;
  final String? currentVersion;
  final String? apkPath;
  final String? error;
}

ReleaseAsset? selectApkAsset(
  List<ReleaseAsset> assets,
  List<String> abis, {
  String prefix = AppConstants.apkAssetPrefix,
  String universalAbi = AppConstants.universalAbiName,
}) {
  for (final abi in abis) {
    final match = assets
        .where(
          (asset) =>
              asset.name.startsWith('$prefix-$abi-') &&
              asset.name.toLowerCase().endsWith('.apk'),
        )
        .firstOrNull;
    if (match != null) return match;
  }
  return assets
      .where(
        (asset) =>
            asset.name.startsWith('$prefix-$universalAbi-') &&
            asset.name.toLowerCase().endsWith('.apk'),
      )
      .firstOrNull;
}

bool isNewerVersion(String currentVersion, String latestVersion) {
  try {
    return Version.parse(_pad(latestVersion)) >
        Version.parse(_pad(currentVersion));
  } on FormatException {
    return false;
  }
}

String _pad(String value) {
  final parts = value.split('.');
  while (parts.length < 3) {
    parts.add('0');
  }
  return parts.join('.');
}
