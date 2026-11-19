import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/user_settings.dart';

/// 把 UTC 转到所选时区（或系统时区）。禁止用 DateTime.toLocal() 做分组和展示。
class AppClock {
  AppClock({
    required this.preferredTimezone,
    required this.systemTimezone,
  });

  /// 'system' 或 IANA 名。
  final String preferredTimezone;

  /// 设备当前 IANA 时区。
  final String systemTimezone;

  String get resolvedTimezone {
    if (preferredTimezone == kSystemTimezoneId || preferredTimezone.isEmpty) {
      return systemTimezone;
    }
    return preferredTimezone;
  }

  tz.Location get location {
    try {
      return tz.getLocation(resolvedTimezone);
    } catch (_) {
      try {
        return tz.getLocation(systemTimezone);
      } catch (_) {
        return tz.getLocation('Asia/Shanghai');
      }
    }
  }

  tz.TZDateTime now() => tz.TZDateTime.now(location);

  tz.TZDateTime fromUtc(DateTime utc) =>
      tz.TZDateTime.from(utc.toUtc(), location);

  DateTime toUtc(tz.TZDateTime value) => value.toUtc();

  tz.TZDateTime dateAt(int year, int month, int day, [int hour = 0, int minute = 0]) {
    return tz.TZDateTime(location, year, month, day, hour, minute);
  }

  /// 所选时区里「今天」的指定时刻（用于默认 12:00，即使已过中午也不改）。
  tz.TZDateTime todayAt(int hour, int minute) {
    final n = now();
    return tz.TZDateTime(location, n.year, n.month, n.day, hour, minute);
  }

  /// 把「所选时区的年月日时分」写成 UTC。
  DateTime wallTimeToUtc(DateTime wallDate, int hour, int minute) {
    return tz.TZDateTime(
      location,
      wallDate.year,
      wallDate.month,
      wallDate.day,
      hour,
      minute,
    ).toUtc();
  }

  String format(DateTime? utc, [String pattern = 'yyyy-MM-dd HH:mm']) {
    if (utc == null) return '';
    final local = fromUtc(utc);
    final naive = DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    return DateFormat(pattern).format(naive);
  }

  DateTime wallDateOf(DateTime utc) {
    final local = fromUtc(utc);
    return DateTime(local.year, local.month, local.day);
  }

  int weekdayOf(DateTime utc) => fromUtc(utc).weekday;
}
