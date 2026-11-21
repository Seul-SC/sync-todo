import 'package:flutter/material.dart';

class AndroidSchedule {
  AndroidSchedule({required this.date, required this.time});

  final DateTime date;
  final TimeOfDay time;
}

/// 按荣耀「待办助手」风格：先看日期日历，再上下滑选择时、分。
Future<AndroidSchedule?> showAndroidSchedulePicker(
  BuildContext context, {
  required DateTime date,
  required TimeOfDay time,
}) {
  return showModalBottomSheet<AndroidSchedule>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _AndroidScheduleSheet(date: date, time: time),
  );
}

class _AndroidScheduleSheet extends StatefulWidget {
  const _AndroidScheduleSheet({required this.date, required this.time});

  final DateTime date;
  final TimeOfDay time;

  @override
  State<_AndroidScheduleSheet> createState() => _AndroidScheduleSheetState();
}

class _AndroidScheduleSheetState extends State<_AndroidScheduleSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  bool _showWheels = false;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _time = widget.time;
    _visibleMonth = DateTime(_date.year, _date.month);
    _hourCtrl = FixedExtentScrollController(initialItem: _time.hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _time.minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_date.year}年${_date.month.toString().padLeft(2, '0')}月${_date.day.toString().padLeft(2, '0')}日';

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _submit() {
    Navigator.pop(
      context,
      AndroidSchedule(date: _date, time: _time),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _kvRow(
              theme,
              label: '日期',
              value: _dateLabel,
              onTap: () => setState(() => _showWheels = false),
            ),
            const SizedBox(height: 8),
            if (!_showWheels) _calendar(theme),
            if (_showWheels) ...[
              _kvRow(
                theme,
                label: '时间',
                value: _timeLabel,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              _wheels(theme),
            ] else ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showWheels = true),
                  child: const Text('设置时间'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(
    ThemeData theme, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const Spacer(),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _calendar(ThemeData theme) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Monday=1 ... Sunday=7, weekday of first
    final lead = (first.weekday + 6) % 7; // 0 if Monday
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_visibleMonth.year, _visibleMonth.month, d);
      final selected = _sameDay(day, _date);
      final isToday = _sameDay(day, today);
      cells.add(
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _date = day),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              isToday && !selected ? '今天' : '$d',
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w400,
                fontSize: isToday && !selected ? 12 : 14,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_visibleMonth.year}年${_visibleMonth.month}月',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }

  Widget _wheels(ThemeData theme) {
    Widget wheel({
      required FixedExtentScrollController controller,
      required int count,
      required ValueChanged<int> onChanged,
    }) {
      return Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          perspective: 0.003,
          diameterRatio: 1.4,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) {
              final selected = controller.hasClients
                  ? controller.selectedItem == index
                  : index == (count == 24 ? _time.hour : _time.minute);
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          wheel(
            controller: _hourCtrl,
            count: 24,
            onChanged: (h) => setState(() {
              _time = TimeOfDay(hour: h, minute: _time.minute);
            }),
          ),
          wheel(
            controller: _minuteCtrl,
            count: 60,
            onChanged: (m) => setState(() {
              _time = TimeOfDay(hour: _time.hour, minute: m);
            }),
          ),
        ],
      ),
    );
  }
}
