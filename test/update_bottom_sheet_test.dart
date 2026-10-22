import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/domain/entities/app_release.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_bottom_sheet.dart';

import 'support/update_repository_fake.dart';

void main() {
  testWidgets('update sheet renders markdown release notes as sections', (
    tester,
  ) async {
    final repo = FakeUpdateRepository(
      currentVersion: '1.0.0',
      release: releaseWithAssets(
        const [
          ReleaseAsset(
            name: 'utang-tracker-arm64-v8a-v1.1.0.apk',
            browserDownloadUrl: 'https://example.com/update.apk',
            sizeBytes: 1000,
          ),
        ],
        releaseNotes: '''What's new in v1.1.0

Release date: 2026-08-10

## Changed

- Improved update notes display

## Fixed

- Removed raw markdown markers
''',
      ),
    );
    final container = ProviderContainer(
      overrides: [updateRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(updateNotifierProvider.notifier).checkForUpdates();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateBottomSheet(context),
              child: const Text('Show update'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show update'));
    await tester.pumpAndSettle();

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('Improved update notes display'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Removed raw markdown markers'), findsOneWidget);
    expect(find.textContaining('##'), findsNothing);
  });
}
