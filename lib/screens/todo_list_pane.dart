import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../services/app_clock.dart';
import '../services/note_repository.dart';
import '../services/settings_service.dart';
import '../services/todo_repository.dart';
import '../widgets/todo_editor_sheet.dart';
import '../widgets/todo_tile.dart';

class TodoListPane extends StatefulWidget {
  const TodoListPane({
    super.key,
    required this.todos,
    required this.notes,
    required this.settings,
    this.dense = false,
    this.plain = false,
    this.showDateHeader = false,
    this.onRefresh,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final SettingsService settings;
  final bool dense;
  /// 安卓：干净的行内列表，少装饰。
  final bool plain;
  final bool showDateHeader;
  final Future<void> Function()? onRefresh;

  @override
  State<TodoListPane> createState() => _TodoListPaneState();
}

class _TodoListPaneState extends State<TodoListPane> {
  bool _completedExpanded = false;

  Future<void> _addOrEdit({TodoItem? existing}) async {
    final result = await showTodoEditorSheet(
      context,
      existing: existing,
      clock: widget.settings.clock,
      notes: widget.notes,
    );
    if (result == null) return;
    if (existing == null) {
      await widget.todos.addTodo(
        title: result.title,
        content: result.content,
        remindAt: result.remindAt,
        recurrence: result.recurrence,
        weekdays: result.weekdays,
      );
    } else {
      await widget.todos.updateTodo(
        existing.copyWith(
          title: result.title,
          content: result.content,
          remindAt: result.remindAt,
          clearRemindAt: result.remindAt == null,
          recurrence: result.recurrence,
          weekdays: result.weekdays,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [widget.todos, widget.notes, widget.settings],
      ),
      builder: (context, _) {
        final repo = widget.todos;
        final clock = widget.settings.clock;
        final grouped = <TodoGroup, List<TodoItem>>{
          TodoGroup.past: [],
          TodoGroup.today: [],
          TodoGroup.later: [],
          TodoGroup.none: [],
        };
        for (final item in repo.activeItems) {
          grouped[item.groupForClock(clock)]!.add(item);
        }
        for (final list in grouped.values) {
          list.sort((a, b) {
            final ar = a.remindAt;
            final br = b.remindAt;
            if (ar == null && br == null) {
              return b.updatedAt.compareTo(a.updatedAt);
            }
            if (ar == null) return 1;
            if (br == null) return -1;
            return ar.compareTo(br);
          });
        }
        final completed = repo.completedItems
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final body = repo.loading
            ? const Center(child: CircularProgressIndicator())
            : _isTotallyEmpty(grouped, completed)
                ? _emptyHint()
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      widget.plain ? 8 : 16,
                      widget.plain ? 4 : 8,
                      widget.plain ? 8 : 16,
                      96,
                    ),
                    children: [
                      if (widget.showDateHeader) _dateHeader(clock),
                      _section('过去', grouped[TodoGroup.past]!),
                      _section('今天', grouped[TodoGroup.today]!),
                      _section('以后', grouped[TodoGroup.later]!),
                      _section('无时间', grouped[TodoGroup.none]!),
                      const SizedBox(height: 8),
                      _completedSection(completed),
                    ],
                  );

        return Column(
          children: [
            if (repo.error != null)
              MaterialBanner(
                content: Text(repo.error!),
                actions: [
                  TextButton(
                    onPressed: () => repo.pull(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            Expanded(
              child: widget.onRefresh == null
                  ? body
                  : RefreshIndicator(
                      onRefresh: widget.onRefresh!,
                      child: body,
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _isTotallyEmpty(
    Map<TodoGroup, List<TodoItem>> grouped,
    List<TodoItem> completed,
  ) {
    return completed.isEmpty && grouped.values.every((items) => items.isEmpty);
  }

  Widget _emptyHint() {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(
          Icons.checklist_rounded,
          size: 72,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
        ),
        const SizedBox(height: 16),
        Text('还没有待办', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          '点击「添加」，新建第一条',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _dateHeader(AppClock clock) {
    final n = clock.now();
    const weeks = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final label = '${n.month}月${n.day}日  ${weeks[n.weekday]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Widget _section(String title, List<TodoItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(widget.plain ? 16 : 4, 18, 4, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
        ),
        ...items.map(_todoTile),
      ],
    );
  }

  Widget _completedSection(List<TodoItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(
            '已完成（${items.length}）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          trailing: Icon(
            _completedExpanded ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () => setState(() => _completedExpanded = !_completedExpanded),
        ),
        if (_completedExpanded) ...items.map(_todoTile),
      ],
    );
  }

  Widget _todoTile(TodoItem item) {
    return TodoTile(
      item: item,
      repository: widget.todos,
      clock: widget.settings.clock,
      dense: widget.dense,
      plain: widget.plain,
      linkedNoteCount: widget.notes.noteIdsForTodo(item.id).length,
      onEdit: () => _addOrEdit(existing: item),
    );
  }

  /// 给外层 FAB 调用。
  Future<void> addNew() => _addOrEdit();
}

/// 通过 key 让父级触发新建。
class TodoListPaneHost extends StatefulWidget {
  const TodoListPaneHost({
    super.key,
    required this.todos,
    required this.notes,
    required this.settings,
    this.dense = false,
    this.plain = false,
    this.showDateHeader = false,
    this.onRefresh,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final SettingsService settings;
  final bool dense;
  /// 安卓：干净的行内列表，少装饰。
  final bool plain;
  final bool showDateHeader;
  final Future<void> Function()? onRefresh;

  @override
  TodoListPaneHostState createState() => TodoListPaneHostState();
}

class TodoListPaneHostState extends State<TodoListPaneHost> {
  final GlobalKey<_TodoListPaneState> _inner = GlobalKey<_TodoListPaneState>();

  Future<void> addNew() async {
    await _inner.currentState?._addOrEdit();
  }

  @override
  Widget build(BuildContext context) {
    return TodoListPane(
      key: _inner,
      todos: widget.todos,
      notes: widget.notes,
      settings: widget.settings,
      dense: widget.dense,
      plain: widget.plain,
      showDateHeader: widget.showDateHeader,
      onRefresh: widget.onRefresh,
    );
  }
}
