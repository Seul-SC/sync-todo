import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note_item.dart';
import '../models/todo_item.dart';
import '../platform/app_os.dart';
import '../services/app_clock.dart';
import '../services/note_repository.dart';

class TodoEditorResult {
  TodoEditorResult({
    required this.title,
    required this.content,
    required this.remindAt,
    required this.recurrence,
    required this.weekdays,
  });

  final String title;
  final String content;
  final DateTime? remindAt;
  final RecurrenceType recurrence;
  final List<int> weekdays;
}

Future<TodoEditorResult?> showTodoEditorSheet(
  BuildContext context, {
  TodoItem? existing,
  required AppClock clock,
  NoteRepository? notes,
}) {
  final body = Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: _TodoEditorBody(existing: existing, clock: clock, notes: notes),
  );
  if (isWindowsDesktop) {
    return showDialog<TodoEditorResult>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<TodoEditorResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => body,
  );
}

class _TodoEditorBody extends StatefulWidget {
  const _TodoEditorBody({this.existing, required this.clock, this.notes});
  final TodoItem? existing;
  final AppClock clock;
  final NoteRepository? notes;

  @override
  State<_TodoEditorBody> createState() => _TodoEditorBodyState();
}

class _TodoEditorBodyState extends State<_TodoEditorBody> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late bool _noRemind;
  late DateTime _date;
  late TimeOfDay _time;
  late RecurrenceType _recurrence;
  late Set<int> _weekdays;

  static const _weekdayLabels = {
    1: '一',
    2: '二',
    3: '三',
    4: '四',
    5: '五',
    6: '六',
    7: '日',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final clock = widget.clock;
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _noRemind = e == null ? false : e.remindAt == null;
    // 默认今天 12:00（所选时区），即使已经过了中午也不改到下一个整点。
    final base = e?.remindAt != null
        ? clock.fromUtc(e!.remindAt!)
        : clock.todayAt(12, 0);
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    _recurrence = e?.recurrence ?? RecurrenceType.none;
    _weekdays = {...(e?.weekdays ?? <int>[])};
    if (_weekdays.isEmpty) _weekdays.add(clock.now().weekday);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题不能为空')),
      );
      return;
    }
    DateTime? remindAt;
    if (!_noRemind) {
      remindAt = widget.clock.wallTimeToUtc(_date, _time.hour, _time.minute);
    }
    if (_recurrence == RecurrenceType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个星期')),
      );
      return;
    }
    Navigator.of(context).pop(TodoEditorResult(
      title: title,
      content: _content.text,
      remindAt: remindAt,
      recurrence: _noRemind ? RecurrenceType.none : _recurrence,
      weekdays: _recurrence == RecurrenceType.weekly && !_noRemind
          ? (_weekdays.toList()..sort())
          : const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy-MM-dd').format(_date);
    final timeLabel =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? '新建待办' : '编辑待办',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '要做什么？',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '可多行，不限长度',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('不提醒'),
              value: _noRemind,
              onChanged: (v) => setState(() => _noRemind = v),
            ),
            if (!_noRemind) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(timeLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('循环', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<RecurrenceType>(
                segments: const [
                  ButtonSegment(value: RecurrenceType.none, label: Text('不循环')),
                  ButtonSegment(value: RecurrenceType.daily, label: Text('每天')),
                  ButtonSegment(value: RecurrenceType.weekly, label: Text('每周')),
                ],
                selected: {_recurrence},
                onSelectionChanged: (s) =>
                    setState(() => _recurrence = s.first),
              ),
              if (_recurrence == RecurrenceType.weekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in _weekdayLabels.keys)
                      FilterChip(
                        label: Text(_weekdayLabels[d]!),
                        selected: _weekdays.contains(d),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _weekdays.add(d);
                            } else {
                              _weekdays.remove(d);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ],
            if (widget.existing != null && widget.notes != null) ...[
              const SizedBox(height: 16),
              _LinkedNotesSection(
                todoId: widget.existing!.id,
                notes: widget.notes!,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing == null ? '添加' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}


class _LinkedNotesSection extends StatelessWidget {
  const _LinkedNotesSection({required this.todoId, required this.notes});

  final String todoId;
  final NoteRepository notes;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notes,
      builder: (context, _) {
        final ids = notes.noteIdsForTodo(todoId);
        final items = ids
            .map(notes.findNote)
            .whereType<NoteItem>()
            .where((n) => !n.isDeleted)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '关联笔记',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final available = notes.activeNotes
                        .where((n) => !ids.contains(n.id))
                        .toList();
                    if (available.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('没有可关联的笔记')),
                      );
                      return;
                    }
                    final picked = await showDialog<NoteItem>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('关联笔记'),
                        content: SizedBox(
                          width: 420,
                          height: 360,
                          child: ListView(
                            children: [
                              for (final n in available)
                                ListTile(
                                  title: Text(
                                    n.title.trim().isEmpty ? '无标题' : n.title,
                                  ),
                                  onTap: () => Navigator.pop(context, n),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    );
                    if (picked != null) {
                      await notes.linkNoteTodo(picked.id, todoId);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('关联'),
                ),
              ],
            ),
            if (items.isEmpty)
              Text('还没有关联笔记', style: Theme.of(context).textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in items)
                    InputChip(
                      label: Text(n.title.trim().isEmpty ? '无标题' : n.title),
                      onDeleted: () => notes.unlinkNoteTodo(n.id, todoId),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
