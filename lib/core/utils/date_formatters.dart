import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final _dayKey = DateFormat('yyyy-MM-dd');
  static const _timestampSeparator = ' • ';
  static const _rangeSeparator = ' - ';

  static String smartTimestamp(
    DateTime value, {
    required DateTime relativeTo,
    required String locale,
    required bool use24HourFormat,
  }) {
    final localValue = value.toLocal();
    final date = _smartDateLabel(
      localValue,
      relativeTo: relativeTo,
      locale: locale,
    );
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    String localizedTime;
    if (use24HourFormat) {
      localizedTime = DateFormat.Hm(canonicalLocale).format(localValue);
    } else {
      localizedTime = DateFormat.jm(canonicalLocale).format(localValue);
    }
    final time = localizedTime
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    return '$date$_timestampSeparator$time';
  }

  static String smartDate(
    DateTime value, {
    required DateTime relativeTo,
    required String locale,
  }) {
    return _smartDateLabel(
      value.toLocal(),
      relativeTo: relativeTo,
      locale: locale,
    );
  }

  static String smartDateRange(
    DateTime start,
    DateTime end, {
    required DateTime relativeTo,
    required String locale,
  }) {
    final startLabel = smartDate(start, relativeTo: relativeTo, locale: locale);
    if (isSameLocalDay(start, end)) return startLabel;
    final endLabel = smartDate(end, relativeTo: relativeTo, locale: locale);
    return '$startLabel$_rangeSeparator$endLabel';
  }

  static String dayKey(DateTime date) => _dayKey.format(date.toLocal());

  /// Formats a stored `yyyy-MM-dd` day key as a friendly date.
  /// Returns the value unchanged when it is not a day key.
  static String friendlyDayKey(String dayKey, {required String locale}) {
    DateTime parsed;
    try {
      parsed = _dayKey.parseStrict(dayKey);
    } on FormatException {
      return dayKey;
    }
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    return DateFormat.yMMMd(canonicalLocale).format(parsed);
  }

  static String fullDate(DateTime date, {required String locale}) {
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    return DateFormat.yMMMMd(canonicalLocale).format(date.toLocal());
  }

  /// Absolute date and time, for records where the exact moment matters.
  static String fullTimestamp(
    DateTime value, {
    required String locale,
    required bool use24HourFormat,
  }) {
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    final localValue = value.toLocal();
    final date = DateFormat.yMMMMd(canonicalLocale).format(localValue);
    final String time;
    if (use24HourFormat) {
      time = DateFormat.Hm(canonicalLocale).format(localValue);
    } else {
      time = DateFormat.jm(canonicalLocale).format(localValue);
    }
    final localizedTime = time
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    return '$date$_timestampSeparator$localizedTime';
  }

  static bool isSameLocalDay(DateTime first, DateTime second) {
    final localA = first.toLocal();
    final localB = second.toLocal();
    return localA.year == localB.year && localA.month == localB.month && localA.day == localB.day;
  }

  static String _smartDateLabel(
    DateTime localValue, {
    required DateTime relativeTo,
    required String locale,
  }) {
    final localReference = relativeTo.toLocal();
    final valueDay = DateTime.utc(
      localValue.year,
      localValue.month,
      localValue.day,
    );
    final referenceDay = DateTime.utc(
      localReference.year,
      localReference.month,
      localReference.day,
    );
    final daysAgo = referenceDay.difference(valueDay).inDays;

    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';

    final canonicalLocale = Intl.canonicalizedLocale(locale);
    if (daysAgo >= 2 && daysAgo <= 6) {
      return DateFormat.E(canonicalLocale).format(localValue);
    }
    if (localValue.year == localReference.year) {
      return DateFormat.MMMd(canonicalLocale).format(localValue);
    }
    return DateFormat.yMMMd(canonicalLocale).format(localValue);
  }
}
