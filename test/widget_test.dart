import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_todo/services/local_store.dart';
import 'package:sync_todo/widgets/todo_editor_sheet.dart';

void main() {
  test('config example keeps placeholders', () {
    final text = File('lib/config.example.dart').readAsStringSync();
    expect(text, contains('YOUR_SUPABASE_HOST'));
    expect(text, contains('REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY'));
  });

  test('damaged local cache falls back instead of blocking startup', () {
    expect(decodeLocalCacheJson('\u0000\u0000', []), isEmpty);
    expect(decodeLocalCacheJson('[', const ['fallback']), ['fallback']);
    expect(decodeLocalCacheJson('[]', const ['fallback']), isEmpty);
    expect(decodeLocalCacheJson('[1, 2]', []), [1, 2]);
  });

  test('temporary cache file can replace an existing cache file', () {
    final dir = Directory.systemTemp.createTempSync('sync_todo_cache');
    try {
      final target = File('${dir.path}${Platform.pathSeparator}cache.json')
        ..writeAsStringSync('old');
      final temp = File('${target.path}.tmp')..writeAsStringSync('[]');
      temp.renameSync(target.path);
      expect(target.readAsStringSync(), '[]');
      expect(temp.existsSync(), isFalse);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('adjustTimeOfDay wraps hours and minutes independently', () {
    const t = TimeOfDay(hour: 23, minute: 59);
    expect(adjustTimeOfDay(t, hours: 1), const TimeOfDay(hour: 0, minute: 59));
    // 分钟循环不向小时进位，和滚轮选择器的行为一致。
    expect(adjustTimeOfDay(t, minutes: 1), const TimeOfDay(hour: 23, minute: 0));
    expect(
      adjustTimeOfDay(const TimeOfDay(hour: 0, minute: 0), minutes: -1),
      const TimeOfDay(hour: 0, minute: 59),
    );
    expect(
      adjustTimeOfDay(const TimeOfDay(hour: 10, minute: 30), minutes: -5),
      const TimeOfDay(hour: 10, minute: 25),
    );
  });
}
