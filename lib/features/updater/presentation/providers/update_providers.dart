import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';
import 'package:utang_tracker/features/updater/domain/usecases/check_for_updates.dart';

final checkForUpdatesProvider = Provider((ref) {
  return CheckForUpdates(ref.watch(updateRepositoryProvider));
});

final updateNotifierProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateNotAvailable extends UpdateState {
  const UpdateNotAvailable();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable({
    required this.release,
    required this.asset,
    required this.currentVersion,
  });

  final AppRelease release;
  final ReleaseAsset asset;
  final String currentVersion;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading({required this.release, required this.progress});

  final AppRelease release;

  final double progress;
}

class UpdateDownloaded extends UpdateState {
  const UpdateDownloaded({required this.release, required this.apkPath});

  final AppRelease release;
  final String apkPath;
}

class UpdateInstalling extends UpdateState {
  const UpdateInstalling();
}

class UpdatePermissionRequired extends UpdateState {
  const UpdatePermissionRequired({
    required this.release,
    required this.apkPath,
  });

  final AppRelease release;
  final String apkPath;
}

class UpdateError extends UpdateState {
  const UpdateError({
    required this.message,
    this.isNetworkError = false,
    this.isPermissionError = false,
  });

  final String message;
  final bool isNetworkError;
  final bool isPermissionError;
}

class UpdateNotifier extends Notifier<UpdateState> {
  static const _channel = MethodChannel(AppConstants.updaterChannel);

  bool _busy = false;
  bool _openingInstallSettings = false;

  @override
  UpdateState build() => const UpdateIdle();

  UpdateRepository get _repo => ref.read(updateRepositoryProvider);

  Future<void> checkForUpdates({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    state = const UpdateChecking();

    try {
      final result = await ref.read(checkForUpdatesProvider)(silent: silent);

      if (!result.updateAvailable) {
        if (result.error != null) {
          state = UpdateError(message: result.error!);
        } else {
          if (silent) {
            state = const UpdateIdle();
          } else {
            state = const UpdateNotAvailable();
          }
        }
        return;
      }

      state = UpdateAvailable(
        release: result.release!,
        asset: result.asset!,
        currentVersion: result.currentVersion!,
      );
    } on AppException catch (appException) {
      final isNetwork =
          appException.message.contains('internet') || appException.message.contains('Network error');
      state = UpdateError(message: appException.message, isNetworkError: isNetwork);
    } catch (caughtError) {
      state = UpdateError(message: 'Unexpected error: $caughtError');
    } finally {
      _busy = false;
    }
  }

  Future<void> download() async {
    final current = state;
    if (current is! UpdateAvailable) return;
    if (_busy) return;
    _busy = true;

    state = UpdateDownloading(release: current.release, progress: 0);

    try {
      await _repo.cleanupOldApks();
      final path = await _repo.downloadApk(current.asset, (p) {
        state = UpdateDownloading(release: current.release, progress: p);
      });
      state = UpdateDownloaded(release: current.release, apkPath: path);
    } on AppException catch (appException) {
      final isNetwork =
          appException.message.contains('internet') || appException.message.contains('interrupted');
      state = UpdateError(message: appException.message, isNetworkError: isNetwork);
    } catch (caughtError) {
      state = UpdateError(message: 'Download failed: $caughtError');
    } finally {
      _busy = false;
    }
  }

  Future<void> install() async {
    final current = state;
    final apkPath = switch (current) {
      UpdateDownloaded(:final apkPath) => apkPath,
      UpdatePermissionRequired(:final apkPath) => apkPath,
      _ => null,
    };
    if (apkPath == null) return;

    try {
      final canInstall =
          await _channel.invokeMethod<bool>('canInstallUnknownApps') ?? false;
      if (!canInstall) {
        AppRelease release;
        if (current is UpdateDownloaded) {
          release = current.release;
        } else {
          release = (current as UpdatePermissionRequired).release;
        }
        state = UpdatePermissionRequired(
          release: release,
          apkPath: apkPath,
        );
        return;
      }

      state = const UpdateInstalling();
      await _channel.invokeMethod<void>('installApk', {'path': apkPath});
      state = const UpdateIdle();
    } on PlatformException catch (platformException) {
      state = UpdateError(message: platformException.message ?? 'Installation failed.');
    }
  }

  Future<void> openInstallSettings() async {
    if (_openingInstallSettings || state is! UpdatePermissionRequired) return;
    _openingInstallSettings = true;
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
      await install();
    } on PlatformException catch (platformException) {
      state = UpdateError(message: platformException.message ?? 'Could not open settings.');
    } finally {
      _openingInstallSettings = false;
    }
  }

  Future<void> dismiss() async {
    final current = state;
    final version = switch (current) {
      UpdateAvailable(:final release) => release.version,
      UpdateDownloading(:final release) => release.version,
      UpdateDownloaded(:final release) => release.version,
      UpdatePermissionRequired(:final release) => release.version,
      _ => null,
    };
    if (version != null) await _repo.saveDismissedVersion(version);
    state = const UpdateIdle();
  }

  void reset() => state = const UpdateIdle();
}
