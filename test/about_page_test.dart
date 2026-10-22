import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/domain/repositories/update_repository.dart';
import 'package:utang_tracker/features/updater/presentation/pages/about_page.dart';

void main() {
  testWidgets('shows dated categorized notes and omits empty categories', (
    tester,
  ) async {
    await _pumpAboutPage(tester, '''
      {
        "version": "1.0.35",
        "date": "2026-08-05",
        "notes": {
          "added": [],
          "changed": ["Improved readability"],
          "fixed": ["Fixed payment spacing"]
        }
      }
      ''');

    expect(find.text('August 5, 2026'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('Improved readability'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Fixed payment spacing'), findsOneWidget);
    expect(find.text('Added'), findsNothing);
  });

  testWidgets('shows a fallback for malformed release notes', (tester) async {
    await _pumpAboutPage(tester, '{not json');

    expect(find.text('Release notes unavailable.'), findsOneWidget);
  });
}

Future<void> _pumpAboutPage(WidgetTester tester, String releaseNotes) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateRepositoryProvider.overrideWithValue(
          _FakeUpdateRepository(releaseNotes),
        ),
      ],
      child: const MaterialApp(home: AboutPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUpdateRepository implements UpdateRepository {
  const _FakeUpdateRepository(this.releaseNotes);

  final String releaseNotes;

  @override
  Future<String> getCurrentVersion() async => '1.0.35';

  @override
  Future<String> loadReleaseNotes() async => releaseNotes;

  @override
  Future<AppRelease?> fetchLatestRelease() async => null;

  @override
  Future<List<String>> getSupportedAbis() async => const [];

  @override
  Future<DateTime?> loadLastCheckTime() async => null;

  @override
  Future<String?> loadDismissedVersion() async => null;

  @override
  Future<void> saveLastCheckTime(DateTime time) async {}

  @override
  Future<void> saveDismissedVersion(String version) async {}

  @override
  Future<void> cleanupOldApks() async {}

  @override
  Future<String?> findDownloadedApk(ReleaseAsset asset) async => null;

  @override
  Future<String> downloadApk(
    ReleaseAsset asset,
    void Function(double progress) onProgress,
  ) => throw UnimplementedError();

  @override
  Future<bool> isAssetAvailable(ReleaseAsset asset) async => true;
}
