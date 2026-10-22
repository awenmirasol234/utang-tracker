import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';

void main() {
  testWidgets('amounts use the shared Poppins semibold treatment', (
    tester,
  ) async {
    final amount = Money.fromPesos(125);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                MoneyText(amount, key: const Key('default-amount')),
                MoneyText(
                  amount,
                  key: const Key('headline-amount'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final defaultFinder = find.descendant(
      of: find.byKey(const Key('default-amount')),
      matching: find.byType(Text),
    );
    final headlineFinder = find.descendant(
      of: find.byKey(const Key('headline-amount')),
      matching: find.byType(Text),
    );
    final defaultText = tester.widget<Text>(defaultFinder);
    final headlineText = tester.widget<Text>(headlineFinder);
    final textTheme = Theme.of(tester.element(defaultFinder)).textTheme;

    for (final text in [defaultText, headlineText]) {
      expect(text.style?.fontFamily, 'Poppins');
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    }

    expect(defaultText.style?.fontSize, textTheme.titleMedium?.fontSize);
    expect(headlineText.style?.fontSize, textTheme.headlineMedium?.fontSize);
  });
}
