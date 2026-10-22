import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/usecases/check_for_updates.dart';

import 'support/update_repository_fake.dart';

void main() {
  group('isNewerVersion', () {
    test('patch bump is newer', () {
      expect(isNewerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('minor bump is newer', () {
      expect(isNewerVersion('1.0.9', '1.1.0'), isTrue);
    });

    test('major bump is newer', () {
      expect(isNewerVersion('1.9.9', '2.0.0'), isTrue);
    });

    test('same version is not newer', () {
      expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    });

    test('older version is not newer', () {
      expect(isNewerVersion('1.2.1', '1.2.0'), isFalse);
    });

    test('double-digit minor comparison is correct', () {
      expect(isNewerVersion('1.9.9', '1.10.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.9'), isFalse);
    });

    test('missing patch segment defaults to 0', () {
      expect(isNewerVersion('1.0', '1.0.1'), isTrue);
    });

    test('malformed versions are treated as not newer', () {
      expect(isNewerVersion('1.0.0', '1.0.0.1'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0-beta'), isFalse);
      expect(isNewerVersion('1.0.0', ''), isFalse);
      expect(isNewerVersion('garbage', '1.2.3'), isFalse);
    });
  });

  group('draft and prerelease filtering', () {
    ReleaseAsset dummyAsset() => const ReleaseAsset(
      name: 'utang-tracker-universal-v1.0.0.apk',
      browserDownloadUrl: 'https://example.com/universal.apk',
      sizeBytes: 1000,
    );

    AppRelease makeRelease({bool isDraft = false, bool isPrerelease = false}) =>
        AppRelease(
          version: '1.0.0',
          releaseNotes: '',
          isDraft: isDraft,
          isPrerelease: isPrerelease,
          assets: [dummyAsset()],
        );

    test('draft release is filtered out (isDraft = true)', () {
      final release = makeRelease(isDraft: true);
      expect(release.isDraft, isTrue);
    });

    test('prerelease is filtered out (isPrerelease = true)', () {
      final release = makeRelease(isPrerelease: true);
      expect(release.isPrerelease, isTrue);
    });

    test('normal release passes through', () {
      final release = makeRelease();
      expect(release.isDraft, isFalse);
      expect(release.isPrerelease, isFalse);
    });
  });

  group('update availability logic', () {
    test('no update when versions are equal', () {
      expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    });

    test('no update when installed is newer (rollback scenario)', () {
      expect(isNewerVersion('1.3.0', '1.2.0'), isFalse);
    });

    test('update available when latest is newer', () {
      expect(isNewerVersion('1.1.0', '1.2.0'), isTrue);
    });

    test('update available with major version jump', () {
      expect(isNewerVersion('1.99.99', '2.0.0'), isTrue);
    });
  });

  test(
    'failed release fetch does not throttle the next update check',
    () async {
      final repo = FakeUpdateRepository(
        currentVersion: '1.0.0',
        fetchError: const AppException('No internet connection.'),
      );

      await expectLater(CheckForUpdates(repo)(), throwsA(isA<AppException>()));

      expect(repo.savedCheckTime, isNull);
    },
  );

  test('successful release fetch stores the last check time', () async {
    final repo = FakeUpdateRepository(currentVersion: '1.0.0');

    await CheckForUpdates(repo)();

    expect(repo.savedCheckTime, isNotNull);
  });
}
