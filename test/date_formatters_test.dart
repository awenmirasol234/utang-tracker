import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';

void main() {
  final reference = DateTime(2026, 7, 20, 10);

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  String timestamp(
    DateTime value, {
    DateTime? relativeTo,
    String locale = 'en_US',
    bool use24HourFormat = false,
  }) {
    return DateFormatters.smartTimestamp(
      value,
      relativeTo: relativeTo ?? reference,
      locale: locale,
      use24HourFormat: use24HourFormat,
    );
  }

  group('smart timestamp', () {
    test('uses Today for the reference calendar day', () {
      expect(timestamp(DateTime(2026, 7, 20, 13, 30)), 'Today • 1:30 PM');
    });

    test('uses Yesterday for the previous calendar day', () {
      expect(timestamp(DateTime(2026, 7, 19, 13, 30)), 'Yesterday • 1:30 PM');
    });

    test('uses the weekday for dates two through six days ago', () {
      expect(timestamp(DateTime(2026, 7, 17, 13, 30)), 'Fri • 1:30 PM');
      expect(timestamp(DateTime(2026, 7, 14, 13, 30)), 'Tue • 1:30 PM');
    });

    test('uses month and day at the seven-day boundary', () {
      expect(timestamp(DateTime(2026, 7, 13, 13, 30)), 'Jul 13 • 1:30 PM');
    });

    test('uses month and day for older dates in the current year', () {
      expect(timestamp(DateTime(2026, 1, 5, 13, 30)), 'Jan 5 • 1:30 PM');
    });

    test('includes the year outside the current year', () {
      expect(
        timestamp(DateTime(2025, 7, 18, 13, 30)),
        'Jul 18, 2025 • 1:30 PM',
      );
    });

    test('prioritizes recent-day rules across a year boundary', () {
      expect(
        timestamp(
          DateTime(2025, 12, 31, 13, 30),
          relativeTo: DateTime(2026, 1, 2, 10),
        ),
        'Wed • 1:30 PM',
      );
    });

    test('uses calendar labels rather than recent labels for future dates', () {
      expect(timestamp(DateTime(2026, 7, 21, 13, 30)), 'Jul 21 • 1:30 PM');
      expect(
        timestamp(DateTime(2027, 7, 21, 13, 30)),
        'Jul 21, 2027 • 1:30 PM',
      );
    });

    test('honors the 24-hour clock preference', () {
      expect(
        timestamp(DateTime(2026, 7, 20, 13, 30), use24HourFormat: true),
        'Today • 13:30',
      );
    });

    test('uses locale-aware weekday and month patterns', () {
      expect(
        DateFormatters.smartDate(
          DateTime(2026, 7, 17),
          relativeTo: reference,
          locale: 'fr_FR',
        ),
        DateFormat.E('fr_FR').format(DateTime(2026, 7, 17)),
      );
      expect(
        DateFormatters.smartDate(
          DateTime(2026, 1, 5),
          relativeTo: reference,
          locale: 'fr_FR',
        ),
        DateFormat.MMMd('fr_FR').format(DateTime(2026, 1, 5)),
      );
    });

    test('converts UTC values to local time before display', () {
      final utc = DateTime.utc(2026, 7, 20, 13, 30);
      final local = utc.toLocal();
      final localReference = DateTime(local.year, local.month, local.day, 23);
      final localTime = DateFormat.jm(
        'en_US',
      ).format(local).replaceAll('\u202f', ' ');

      expect(timestamp(utc, relativeTo: localReference), 'Today • $localTime');
    });
  });

  group('smart date-only displays', () {
    test('omits time while keeping relative labels', () {
      expect(
        DateFormatters.smartDate(
          DateTime(2026, 7, 20, 23, 59),
          relativeTo: reference,
          locale: 'en_US',
        ),
        'Today',
      );
    });

    test('formats single-day and multi-day ranges centrally', () {
      expect(
        DateFormatters.smartDateRange(
          DateTime(2026, 7, 20),
          DateTime(2026, 7, 20, 23, 59),
          relativeTo: reference,
          locale: 'en_US',
        ),
        'Today',
      );
      expect(
        DateFormatters.smartDateRange(
          DateTime(2026, 7, 19),
          DateTime(2026, 7, 20),
          relativeTo: reference,
          locale: 'en_US',
        ),
        'Yesterday - Today',
      );
    });
  });

  group('friendly day key', () {
    test('formats a stored day key as a friendly date', () {
      expect(
        DateFormatters.friendlyDayKey('2026-07-20', locale: 'en_US'),
        'Jul 20, 2026',
      );
    });

    test('keeps the value when it is not a day key', () {
      expect(
        DateFormatters.friendlyDayKey('not a date', locale: 'en_US'),
        'not a date',
      );
    });
  });

  testWidgets('context adapter uses the device 24-hour preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: Builder(
              builder: (context) => Text(
                context.smartTimestamp(
                  DateTime(2026, 7, 20, 13, 30),
                  relativeTo: reference,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Today • 13:30'), findsOneWidget);
  });
}
