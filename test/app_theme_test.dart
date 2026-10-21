import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/theme/app_theme.dart';

void main() {
  test('app bar titles use the shared 20 px size', () {
    final titleStyle = AppTheme.light().appBarTheme.titleTextStyle;

    expect(titleStyle?.fontSize, 20);
  });

  test('text theme defines the shared application type scale', () {
    final textTheme = AppTheme.light().textTheme;

    expect(textTheme.headlineMedium?.fontSize, 28);
    expect(textTheme.headlineSmall?.fontSize, 24);
    expect(textTheme.titleLarge?.fontSize, 21);
    expect(textTheme.titleMedium?.fontSize, 16);
    expect(textTheme.titleSmall?.fontSize, 15);
    expect(textTheme.bodyLarge?.fontSize, 16);
    expect(textTheme.bodyMedium?.fontSize, 14);
    expect(textTheme.bodySmall?.fontSize, 12);
    expect(textTheme.labelLarge?.fontSize, 14);
    expect(textTheme.labelMedium?.fontSize, 13);
    expect(textTheme.labelSmall?.fontSize, 11);

    for (final style in [
      textTheme.bodyLarge,
      textTheme.bodyMedium,
      textTheme.bodySmall,
    ]) {
      expect(style?.fontWeight, FontWeight.w500);
    }
  });

  test('every shared text role uses Poppins', () {
    final textTheme = AppTheme.light().textTheme;
    final styles = <String, TextStyle?>{
      'displayLarge': textTheme.displayLarge,
      'displayMedium': textTheme.displayMedium,
      'displaySmall': textTheme.displaySmall,
      'headlineLarge': textTheme.headlineLarge,
      'headlineMedium': textTheme.headlineMedium,
      'headlineSmall': textTheme.headlineSmall,
      'titleLarge': textTheme.titleLarge,
      'titleMedium': textTheme.titleMedium,
      'titleSmall': textTheme.titleSmall,
      'bodyLarge': textTheme.bodyLarge,
      'bodyMedium': textTheme.bodyMedium,
      'bodySmall': textTheme.bodySmall,
      'labelLarge': textTheme.labelLarge,
      'labelMedium': textTheme.labelMedium,
      'labelSmall': textTheme.labelSmall,
    };

    for (final entry in styles.entries) {
      expect(
        entry.value?.fontFamily,
        'Poppins',
        reason: '${entry.key} must inherit the application font family.',
      );
    }
  });

  test('component themes derive typography from the shared text theme', () {
    final theme = AppTheme.light();
    final textTheme = theme.textTheme;

    final elevatedTextStyle = theme.elevatedButtonTheme.style?.textStyle
        ?.resolve(<WidgetState>{});
    final outlinedTextStyle = theme.outlinedButtonTheme.style?.textStyle
        ?.resolve(<WidgetState>{});
    final textButtonStyle = theme.textButtonTheme.style?.textStyle?.resolve(
      <WidgetState>{},
    );
    final selectedNavigationStyle = theme.navigationBarTheme.labelTextStyle
        ?.resolve({WidgetState.selected});
    final unselectedNavigationStyle = theme.navigationBarTheme.labelTextStyle
        ?.resolve(<WidgetState>{});

    expect(elevatedTextStyle?.fontSize, textTheme.titleMedium?.fontSize);
    expect(outlinedTextStyle?.fontSize, textTheme.titleMedium?.fontSize);
    expect(textButtonStyle?.fontSize, textTheme.titleSmall?.fontSize);
    expect(
      theme.floatingActionButtonTheme.extendedTextStyle?.fontSize,
      textTheme.labelLarge?.fontSize,
    );
    expect(
      theme.chipTheme.labelStyle?.fontSize,
      textTheme.labelMedium?.fontSize,
    );
    expect(selectedNavigationStyle?.fontSize, textTheme.labelSmall?.fontSize);
    expect(
      theme.snackBarTheme.contentTextStyle?.fontSize,
      textTheme.bodyMedium?.fontSize,
    );
    expect(theme.dialogTheme.titleTextStyle?.fontSize, 21);
    expect(theme.dialogTheme.contentTextStyle?.fontSize, 14);
    expect(theme.tabBarTheme.labelStyle?.fontSize, 14);
    expect(theme.listTileTheme.titleTextStyle?.fontSize, 16);
    expect(theme.listTileTheme.subtitleTextStyle?.fontSize, 14);
    expect(theme.inputDecorationTheme.errorStyle?.fontSize, 12);

    final componentStyles = <String, TextStyle?>{
      'app bar': theme.appBarTheme.titleTextStyle,
      'elevated button': elevatedTextStyle,
      'outlined button': outlinedTextStyle,
      'text button': textButtonStyle,
      'extended FAB': theme.floatingActionButtonTheme.extendedTextStyle,
      'chip': theme.chipTheme.labelStyle,
      'selected chip': theme.chipTheme.secondaryLabelStyle,
      'selected navigation': selectedNavigationStyle,
      'unselected navigation': unselectedNavigationStyle,
      'snackbar': theme.snackBarTheme.contentTextStyle,
      'dialog title': theme.dialogTheme.titleTextStyle,
      'dialog content': theme.dialogTheme.contentTextStyle,
      'tab': theme.tabBarTheme.labelStyle,
      'unselected tab': theme.tabBarTheme.unselectedLabelStyle,
      'list tile title': theme.listTileTheme.titleTextStyle,
      'list tile subtitle': theme.listTileTheme.subtitleTextStyle,
      'list tile trailing': theme.listTileTheme.leadingAndTrailingTextStyle,
      'input hint': theme.inputDecorationTheme.hintStyle,
      'input label': theme.inputDecorationTheme.labelStyle,
      'input helper': theme.inputDecorationTheme.helperStyle,
      'input error': theme.inputDecorationTheme.errorStyle,
      'input counter': theme.inputDecorationTheme.counterStyle,
    };

    for (final entry in componentStyles.entries) {
      expect(
        entry.value?.fontFamily,
        'Poppins',
        reason: '${entry.key} must derive from the shared Poppins text theme.',
      );
    }

    final inputSupportingStyles = <String, TextStyle?>{
      'hint': theme.inputDecorationTheme.hintStyle,
      'label': theme.inputDecorationTheme.labelStyle,
      'helper': theme.inputDecorationTheme.helperStyle,
      'error': theme.inputDecorationTheme.errorStyle,
      'counter': theme.inputDecorationTheme.counterStyle,
    };

    for (final entry in inputSupportingStyles.entries) {
      expect(
        entry.value?.fontWeight,
        FontWeight.w500,
        reason:
            'Input ${entry.key} text must remain readable at medium weight.',
      );
    }
  });
}
