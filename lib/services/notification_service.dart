import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';
import '../platform/app_os.dart';
import 'app_clock.dart';

/// Android 被系统杀掉后的系统通知兜底。Windows 绝不会调用本服务发通知。
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzReady = false;
  String systemTimezone = 'Asia/Shanghai';

  Future<void> initTimezones() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      if (name.isNotEmpty) {
        systemTimezone = name;
        tz.setLocalLocation(tz.getLocation(name));
      }
    } catch (e) {
      debugPrint('flutter_timezone failed: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
        systemTimezone = 'Asia/Shanghai';
      } catch (_) {}
    }
    _tzReady = true;
  }

  Future<void> init() async {
    await initTimezones();
    if (!isAndroidDevice || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    const channel = AndroidNotificationChannel(
      'sync_todo_reminders',
      '待办提醒',
      description: '待办到点时的提醒通知',
      importance: Importance.max,
      playSound: true,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!isAndroidDevice) return false;
    await init();
    final status = await Permission.notification.request();
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('exact alarm permission: $e');
    }
    return status.isGranted;
  }

  Future<bool> isNotificationGranted() async {
    if (!isAndroidDevice) return false;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  int _idFor(TodoItem item) {
    final key = '${item.id}@${item.remindAt?.toUtc().millisecondsSinceEpoch ?? 0}';
    return key.hashCode & 0x7fffffff;
  }

  Future<void> cancelAll() async {
    if (!isAndroidDevice) return;
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> cancelItem(TodoItem item) async {
    if (!isAndroidDevice || !_initialized) return;
    await _plugin.cancel(_idFor(item));
  }

  Future<void> scheduleUpcoming(List<TodoItem> items, AppClock clock) async {
    if (!isAndroidDevice) return;
    await init();
    await cancelAll();
    final now = DateTime.now().toUtc();
    for (final item in items) {
      final at = item.remindAt;
      if (at == null) continue;
      if (at.isBefore(now)) continue;
      try {
        final when = tz.TZDateTime.from(at.toUtc(), clock.location);
        await _plugin.zonedSchedule(
          _idFor(item),
          '待办提醒',
          item.title,
          when,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'sync_todo_reminders',
              '待办提醒',
              channelDescription: '待办到点时的提醒通知',
              importance: Importance.max,
              priority: Priority.max,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('schedule reminder failed: $e');
      }
    }
  }
}

/// 在 main 启动时初始化时区数据库（Windows / Android 都需要）。
Future<String> initializeAppTimezones() async {
  await NotificationService.instance.initTimezones();
  return NotificationService.instance.systemTimezone;
}
