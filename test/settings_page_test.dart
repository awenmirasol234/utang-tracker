import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('settings page shows About menu item', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('App version and updates'), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(
      listView.padding,
      const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        0,
        AppSpacing.pagePadding,
        AppSpacing.xxl,
      ),
    );
  });
}
