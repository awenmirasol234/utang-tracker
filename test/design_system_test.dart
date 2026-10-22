import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen and component colors come from AppColors', () {
    final lib = Directory('lib');
    final offenders = <String>[];
    final directColor = RegExp(r'\bColor\s*\(');
    final frameworkColor = RegExp(r'\b(?:Colors|CupertinoColors)\.');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_colors.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (directColor.hasMatch(line) || frameworkColor.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Add semantic colors to AppColors instead of declaring them in '
          'screens, components, or AppTheme.\n${offenders.join('\n')}',
    );
  });

  test('font sizes are centralized in AppTheme', () {
    final lib = Directory('lib');
    final offenders = <String>[];
    final directFontSize = RegExp(r'\bfontSize\s*:');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_theme.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (directFontSize.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppTheme text roles or component themes instead of declaring '
          'font sizes in screens and widgets.\n${offenders.join('\n')}',
    );
  });

  test('font families are centralized in AppTheme', () {
    final lib = Directory('lib');
    final offenders = <String>[];
    final directFontFamily = RegExp(r'\bfontFamily(?:Fallback)?\s*:');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_theme.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (directFontFamily.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'All screens and widgets must inherit Poppins from AppTheme instead '
          'of declaring a font family locally.\n${offenders.join('\n')}',
    );
  });

  test('date display patterns are centralized in DateFormatters', () {
    final lib = Directory('lib');
    final offenders = <String>[];
    final directDateFormat = RegExp(r'\bDateFormat\s*(?:\.|\()');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('date_formatters.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (directDateFormat.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'All UI dates and timestamps must use the centralized smart '
          'formatter.\n${offenders.join('\n')}',
    );
  });

  test('spacing values come from AppSpacing', () {
    final lib = Directory('lib');
    final offenders = <String>[];
    // Only direct arguments are inspected, so a nested widget call inside a
    // SizedBox cannot report a number that belongs to the child.
    final spacingCall = RegExp(
      r'\b(?:EdgeInsets[\.\w]*|SizedBox)\(([^()]*)\)',
      dotAll: true,
    );
    final rawToken = RegExp(r'(?<![\w.])(?:4|8|12|16|18|20|24|32)(?![\w.])');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_spacing.dart')) continue;

      final source = entity.readAsStringSync();
      for (final match in spacingCall.allMatches(source)) {
        final arguments = match.group(1)!;
        if (!rawToken.hasMatch(arguments)) continue;
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add(
          '${entity.path}:$line: ${match.group(0)!.replaceAll('\n', ' ')}',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use the AppSpacing tokens instead of raw spacing numbers.\n'
          '${offenders.join('\n')}',
    );
  });
}
