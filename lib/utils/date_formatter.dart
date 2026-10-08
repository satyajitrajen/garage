import 'package:intl/intl.dart';

class AppDateFormatter {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _dayFormat = DateFormat('EEE, dd MMM');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);
  static String formatDayDate(DateTime date) => _dayFormat.format(date);

  /// Calendar days from today until [end] (local dates), so a 14-day trial
  /// started today reads 14 rather than 13 once a few minutes have passed.
  /// Negative once [end] has passed; 0 when it ends later today.
  static int daysUntil(DateTime end, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (end.isBefore(current)) return -1;
    final today = DateTime.utc(current.year, current.month, current.day);
    final endDay = DateTime.utc(end.year, end.month, end.day);
    return endDay.difference(today).inDays;
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(targetDate).inDays;

    if (diff == 0) return 'Today, ${_timeFormat.format(date)}';
    if (diff == 1) return 'Yesterday, ${_timeFormat.format(date)}';
    if (diff == -1) return 'Tomorrow, ${_timeFormat.format(date)}';
    if (diff > 1 && diff < 7) return '$diff days ago';
    return formatDate(date);
  }
}
