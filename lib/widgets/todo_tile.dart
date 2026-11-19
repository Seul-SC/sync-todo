import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../services/app_clock.dart';
import '../services/todo_repository.dart';

class TodoTile extends StatelessWidget {
  const TodoTile({
    super.key,
    required this.item,
    required this.repository,
    required this.clock,
    required this.onEdit,
    this.linkedNoteCount = 0,
    this.dense = false,
    this.plain = false,
  });

  final TodoItem item;
  final TodoRepository repository;
  final AppClock clock;
  final VoidCallback onEdit;
  final int linkedNoteCount;
  final bool dense;

  /// 安卓系统待办风格：无卡片，标题与时间同一行。
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = item.remindAt == null
        ? null
        : clock.format(item.remindAt, plain ? 'HH:mm' : 'MM-dd HH:mm');
    String? badge;
    if (item.recurrence == RecurrenceType.daily) {
      badge = '每天';
    } else if (item.recurrence == RecurrenceType.weekly) {
      const labels = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};
      badge = '每周 ${item.weekdays.map((d) => labels[d]).join('')}';
    } else if (item.isCompletionSnapshot) {
      badge = '循环记录';
    }

    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final preview = item.contentPreview;
    final done = item.completed && !item.isRecurring;

    final titleStyle = done
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: plain ? 16 : null,
          )
        : TextStyle(
            fontSize: plain ? 16 : null,
            fontWeight: plain ? FontWeight.w500 : FontWeight.w500,
          );

    final checkbox = Checkbox(
      value: done,
      onChanged: (_) {
        if (done) {
          repository.uncompleteTodo(item);
        } else {
          repository.completeTodo(item);
        }
      },
    );

    if (plain) {
      final timeLabel = [
        if (time != null) time,
        if (badge != null) badge,
      ].join(' ');
      return InkWell(
        onTap: onEdit,
        onLongPress: () => repository.softDelete(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              checkbox,
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.title, style: titleStyle)),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    if (preview.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final parts = <String>[
      if (time != null) time,
      if (badge != null) badge,
      if (linkedNoteCount > 0) '笔记 $linkedNoteCount',
    ];

    return Card(
      margin: EdgeInsets.only(bottom: dense ? 6 : 8),
      child: ListTile(
        dense: dense,
        leading: checkbox,
        title: Text(item.title, style: titleStyle),
        subtitle: (parts.isEmpty && preview.isEmpty)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  if (parts.isNotEmpty) Text(parts.join(' · ')),
                ],
              ),
        isThreeLine: preview.isNotEmpty && parts.isNotEmpty,
        onTap: onEdit,
        trailing: IconButton(
          tooltip: '删除',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => repository.softDelete(item),
        ),
      ),
    );
  }
}
