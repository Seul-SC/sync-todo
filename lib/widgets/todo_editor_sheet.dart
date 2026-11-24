import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/note_item.dart';
import '../models/todo_item.dart';
import '../platform/app_os.dart';
import 'android_schedule_picker.dart';
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
  late final TitleContentController _body;
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
    _body = TitleContentController(text: TitleContentController.compose(e?.title, e?.content));
    _noRemind = e == null ? false : e.remindAt == null;
    // 打开新建待办并设置时间时，默认就是当前时间。
    final base = e?.remindAt != null
        ? clock.fromUtc(e!.remindAt!)
        : clock.now();
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    _recurrence = e?.recurrence ?? RecurrenceType.none;
    _weekdays = {...(e?.weekdays ?? <int>[])};
    if (_weekdays.isEmpty) _weekdays.add(clock.now().weekday);
  }

  @override
  void dispose() {
    _body.dispose();
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

  Future<void> _pickAndroidSchedule() async {
    final picked = await showAndroidSchedulePicker(
      context,
      date: _date,
      time: _time,
    );
    if (picked == null) return;
    setState(() {
      _date = picked.date;
      _time = picked.time;
    });
  }

  void _submit() {
    final parsed = _body.parsed();
    final title = parsed.$1;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写第一行标题')),
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
      content: parsed.$2,
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
              controller: _body,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '第一行是标题，下面是内容。也可以只写一行标题。',
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('不提醒'),
              value: _noRemind,
              onChanged: (v) => setState(() => _noRemind = v),
            ),
            if (!_noRemind) ...[
              if (isWindowsDesktop)
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
                    _WheelTimeField(
                      time: _time,
                      onChanged: (t) => setState(() => _time = t),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickAndroidSchedule,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text('$dateLabel  $timeLabel'),
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


/// 调整时间：小时按 24 循环、分钟按 60 循环。抽成纯函数方便测试。
TimeOfDay adjustTimeOfDay(TimeOfDay time, {int hours = 0, int minutes = 0}) {
  var hour = (time.hour + hours) % 24;
  if (hour < 0) hour += 24;
  var minute = (time.minute + minutes) % 60;
  if (minute < 0) minute += 60;
  return TimeOfDay(hour: hour, minute: minute);
}

class _WheelTimeField extends StatelessWidget {
  const _WheelTimeField({required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  void _adjust({int hours = 0, int minutes = 0}) {
    onChanged(adjustTimeOfDay(time, hours: hours, minutes: minutes));
  }

  bool get _shiftPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  void _onScroll(PointerEvent event, {required bool hour}) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    final dx = event.scrollDelta.dx;
    if (dy == 0 && dx == 0) return;
    final increase = dy < 0 || (dy == 0 && dx < 0);
    final step = increase ? 1 : -1;
    if (hour) {
      _adjust(hours: step);
      return;
    }
    _adjust(minutes: step * (_shiftPressed ? 5 : 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WheelDigit(
              value: time.hour.toString().padLeft(2, '0'),
              style: numberStyle,
              tooltip: '点击选中后，用滚轮、PgUp/PgDn 或 ↑ ↓ 调整小时',
              onScroll: (event) => _onScroll(event, hour: true),
              onIncrease: () => _adjust(hours: 1),
              onDecrease: () => _adjust(hours: -1),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(':', style: numberStyle),
            ),
            _WheelDigit(
              value: time.minute.toString().padLeft(2, '0'),
              style: numberStyle,
              tooltip: '点击选中后，用滚轮、PgUp/PgDn 或 ↑ ↓ 调整分钟，按住 Shift 一次跳 5 分钟',
              onScroll: (event) => _onScroll(event, hour: false),
              onIncrease: () => _adjust(minutes: _shiftPressed ? 5 : 1),
              onDecrease: () => _adjust(minutes: _shiftPressed ? -5 : -1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一位滚轮数字：滚轮、上下箭头按钮、键盘（PgUp/PgDn/↑↓）都能调。
/// 点击数字选中后有高亮，键盘调整作用于选中的那一项。
class _WheelDigit extends StatefulWidget {
  const _WheelDigit({
    required this.value,
    required this.style,
    required this.tooltip,
    required this.onScroll,
    required this.onIncrease,
    required this.onDecrease,
  });

  final String value;
  final TextStyle? style;
  final String tooltip;
  final void Function(PointerEvent event) onScroll;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  State<_WheelDigit> createState() => _WheelDigitState();
}

class _WheelDigitState extends State<_WheelDigit> {
  // 数字本身的焦点（接收键盘）；两个箭头按钮不参与 Tab 焦点遍历。
  final FocusNode _focusNode = FocusNode();
  final FocusNode _upButtonFocus = FocusNode(canRequestFocus: false);
  final FocusNode _downButtonFocus = FocusNode(canRequestFocus: false);

  @override
  void dispose() {
    _focusNode.dispose();
    _upButtonFocus.dispose();
    _downButtonFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.pageUp || key == LogicalKeyboardKey.arrowUp) {
      widget.onIncrease();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowDown) {
      widget.onDecrease();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            GestureBinding.instance.pointerSignalResolver
                .register(event, widget.onScroll);
          }
        },
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            onTap: _focusNode.requestFocus,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: ListenableBuilder(
                listenable: _focusNode,
                builder: (context, child) {
                  final focused = _focusNode.hasFocus;
                  return Container(
                    decoration: BoxDecoration(
                      color: focused
                          ? theme.colorScheme.primary.withValues(alpha: 0.10)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: focused
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      focusNode: _upButtonFocus,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 24),
                      iconSize: 18,
                      onPressed: widget.onIncrease,
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(widget.value, style: widget.style),
                    ),
                    IconButton(
                      focusNode: _downButtonFocus,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 24),
                      iconSize: 18,
                      onPressed: widget.onDecrease,
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

/// 第一行加粗作为标题，其余行作为内容。
class TitleContentController extends TextEditingController {
  TitleContentController({super.text});

  static String compose(String? title, String? content) {
    final t = (title ?? '').trimRight();
    final c = content ?? '';
    if (c.trim().isEmpty) return t;
    if (t.isEmpty) return c;
    return '$t\n$c';
  }

  (String, String) parsed() {
    final raw = text.replaceAll('\r\n', '\n');
    final breakAt = raw.indexOf('\n');
    if (breakAt < 0) {
      return (raw.trim(), '');
    }
    return (raw.substring(0, breakAt).trim(), raw.substring(breakAt + 1));
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    final breakAt = text.indexOf('\n');
    final titleStyle = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);
    if (breakAt < 0) {
      return TextSpan(style: titleStyle, text: text);
    }
    return TextSpan(
      children: [
        TextSpan(style: titleStyle, text: text.substring(0, breakAt)),
        TextSpan(style: style, text: text.substring(breakAt)),
      ],
    );
  }
}
