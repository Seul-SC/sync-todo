import 'package:uuid/uuid.dart';

import '../services/app_clock.dart';

enum RecurrenceType { none, daily, weekly }

class TodoItem {
  TodoItem({
    required this.id,
    required this.userId,
    required this.title,
    this.content = '',
    this.remindAt,
    this.recurrence = RecurrenceType.none,
    this.weekdays = const [],
    this.completed = false,
    this.seriesId,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime? remindAt;
  final RecurrenceType recurrence;
  final List<int> weekdays; // 1=Mon ... 7=Sun
  final bool completed;
  final String? seriesId;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRecurring => recurrence != RecurrenceType.none;
  bool get isDeleted => deletedAt != null;
  bool get hasReminder => remindAt != null;
  bool get isCompletionSnapshot =>
      seriesId != null && completed && !isRecurring;

  String get contentPreview {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    final lines = trimmed.split(RegExp(r'\r?\n'));
    final taken = lines.take(3).join('\n');
    return taken.length > 160 ? '${taken.substring(0, 160)}…' : taken;
  }

  TodoItem copyWith({
    String? title,
    String? content,
    DateTime? remindAt,
    bool clearRemindAt = false,
    RecurrenceType? recurrence,
    List<int>? weekdays,
    bool? completed,
    String? seriesId,
    bool clearSeriesId = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      recurrence: recurrence ?? this.recurrence,
      weekdays: weekdays ?? this.weekdays,
      completed: completed ?? this.completed,
      seriesId: clearSeriesId ? null : (seriesId ?? this.seriesId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'remind_at': remindAt?.toUtc().toIso8601String(),
        'recurrence': recurrence.name,
        'weekdays': weekdays,
        'completed': completed,
        'series_id': seriesId,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpsertParams() => {
        'p_id': id,
        'p_title': title,
        'p_content': content,
        'p_remind_at': remindAt?.toUtc().toIso8601String(),
        'p_recurrence': recurrence.name,
        'p_weekdays': weekdays.isEmpty ? null : weekdays,
        'p_completed': completed,
        'p_series_id': seriesId,
        'p_deleted_at': deletedAt?.toUtc().toIso8601String(),
        'p_created_at': createdAt.toUtc().toIso8601String(),
        'p_updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final recurrenceRaw = (json['recurrence'] as String?) ?? 'none';
    final recurrence = RecurrenceType.values.firstWhere(
      (e) => e.name == recurrenceRaw,
      orElse: () => RecurrenceType.none,
    );
    final weekdaysRaw = json['weekdays'];
    final weekdays = weekdaysRaw is List
        ? weekdaysRaw.map((e) => (e as num).toInt()).toList()
        : <int>[];

    return TodoItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      remindAt: parseTime(json['remind_at']),
      recurrence: recurrence,
      weekdays: weekdays,
      completed: json['completed'] as bool? ?? false,
      seriesId: json['series_id'] as String?,
      deletedAt: parseTime(json['deleted_at']),
      createdAt: parseTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: parseTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? parseTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static TodoItem create({
    required String userId,
    required String title,
    String content = '',
    DateTime? remindAt,
    RecurrenceType recurrence = RecurrenceType.none,
    List<int> weekdays = const [],
    bool completed = false,
    String? seriesId,
  }) {
    final now = DateTime.now().toUtc();
    return TodoItem(
      id: const Uuid().v4(),
      userId: userId,
      title: title.trim(),
      content: content,
      remindAt: remindAt?.toUtc(),
      recurrence: recurrence,
      weekdays: List<int>.from(weekdays)..sort(),
      completed: completed,
      seriesId: seriesId,
      createdAt: now,
      updatedAt: now,
    );
  }
}

enum TodoGroup { past, today, later, none, completed }

extension TodoGrouping on TodoItem {
  /// 分组按所选时区的「现在」计算：已到点未完成进「过去」。
  TodoGroup groupForClock(AppClock clock) {
    if (completed && !isRecurring) return TodoGroup.completed;
    if (remindAt == null) return TodoGroup.none;

    final now = clock.now();
    final remind = clock.fromUtc(remindAt!);
    if (!remind.isAfter(now)) return TodoGroup.past;
    if (remind.year == now.year &&
        remind.month == now.month &&
        remind.day == now.day) {
      return TodoGroup.today;
    }
    return TodoGroup.later;
  }
}

/// 循环待办：勾选后推进到「当前时区现在之后，且晚于本次原提醒」的下一次。
DateTime advanceRecurrence(TodoItem item, AppClock clock) {
  final now = clock.now();
  final base = item.remindAt != null ? clock.fromUtc(item.remindAt!) : now;
  final from = now.isAfter(base) ? now : base;
  final timeOfDay = Duration(hours: base.hour, minutes: base.minute);

  if (item.recurrence == RecurrenceType.daily) {
    var next = clock.dateAt(from.year, from.month, from.day).add(timeOfDay);
    if (!next.isAfter(from)) {
      next = next.add(const Duration(days: 1));
    }
    return clock.toUtc(next);
  }

  final days = item.weekdays.isEmpty ? <int>[base.weekday] : item.weekdays;
  for (var offset = 0; offset <= 14; offset++) {
    final day = clock.dateAt(from.year, from.month, from.day)
        .add(Duration(days: offset));
    if (!days.contains(day.weekday)) continue;
    final candidate = day.add(timeOfDay);
    if (candidate.isAfter(from)) return clock.toUtc(candidate);
  }

  return clock.toUtc(from.add(const Duration(days: 1)));
}
