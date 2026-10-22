import 'package:flutter/material.dart';
import 'package:utang_tracker/core/utils/date_formatters.dart';

extension DateTimeDisplayContext on BuildContext {
  String smartTimestamp(DateTime value, {DateTime? relativeTo}) {
    return DateFormatters.smartTimestamp(
      value,
      relativeTo: relativeTo ?? DateTime.now(),
      locale: Localizations.localeOf(this).toLanguageTag(),
      use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(this),
    );
  }

  String smartDate(DateTime value, {DateTime? relativeTo}) {
    return DateFormatters.smartDate(
      value,
      relativeTo: relativeTo ?? DateTime.now(),
      locale: Localizations.localeOf(this).toLanguageTag(),
    );
  }

  String smartDateRange(DateTime start, DateTime end, {DateTime? relativeTo}) {
    return DateFormatters.smartDateRange(
      start,
      end,
      relativeTo: relativeTo ?? DateTime.now(),
      locale: Localizations.localeOf(this).toLanguageTag(),
    );
  }

  String fullTimestamp(DateTime value) {
    return DateFormatters.fullTimestamp(
      value,
      locale: Localizations.localeOf(this).toLanguageTag(),
      use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(this),
    );
  }
}
