import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../platform/app_os.dart';
import '../services/app_clock.dart';
import 'reminder_skin.dart';

/// 同时展示多条到点提醒：一层遮罩 + 多张独立卡片。
/// Windows：前面打勾立即完成并同步；右下角「确定」只关窗；保留稍后提醒。
/// Android：仍是「完成」+「稍后提醒」。
class ReminderOverlayStack extends StatelessWidget {
  const ReminderOverlayStack({
    super.key,
    required this.items,
    required this.clock,
    required this.onComplete,
    required this.onSnooze,
    this.onDismiss,
    this.skin,
  });

  final List<TodoItem> items;
  final AppClock clock;
  final Future<void> Function(TodoItem item) onComplete;
  final Future<void> Function(TodoItem item) onSnooze;
  final Future<void> Function(TodoItem item)? onDismiss;
  final ReminderSkin? skin;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final skin = this.skin ?? ReminderSkin.fromTheme(Theme.of(context));
    final compact = isAndroidDevice;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: compact ? 8 : skin.blurSigma,
              sigmaY: compact ? 8 : skin.blurSigma,
            ),
            child: ColoredBox(color: skin.scrimColor),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ReminderCardHost(
                      item: item,
                      clock: clock,
                      skin: skin,
                      compact: compact,
                      onComplete: () => onComplete(item),
                      onSnooze: () => onSnooze(item),
                      onDismiss: onDismiss == null
                          ? null
                          : () => onDismiss!(item),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCardHost extends StatefulWidget {
  const _ReminderCardHost({
    required this.item,
    required this.clock,
    required this.skin,
    required this.compact,
    required this.onComplete,
    required this.onSnooze,
    this.onDismiss,
  });

  final TodoItem item;
  final AppClock clock;
  final ReminderSkin skin;
  final bool compact;
  final Future<void> Function() onComplete;
  final Future<void> Function() onSnooze;
  final Future<void> Function()? onDismiss;

  @override
  State<_ReminderCardHost> createState() => _ReminderCardHostState();
}

class _ReminderCardHostState extends State<_ReminderCardHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeThen(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _controller.reverse();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final timeText = widget.item.remindAt == null
        ? '无提醒时间'
        : widget.clock.format(widget.item.remindAt);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: ReminderCard(
              skin: widget.skin,
              title: widget.item.title,
              content: widget.item.contentPreview,
              timeText: timeText,
              glow: widget.compact ? 0 : _glow.value,
              busy: _busy,
              compact: widget.compact,
              onComplete: () => _closeThen(widget.onComplete),
              onSnooze: () => _closeThen(widget.onSnooze),
              onDismiss: widget.onDismiss == null
                  ? null
                  : () => _closeThen(widget.onDismiss!),
            ),
          ),
        );
      },
    );
  }
}

/// 单条提醒卡片。
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.skin,
    required this.title,
    required this.content,
    required this.timeText,
    required this.glow,
    required this.busy,
    required this.compact,
    required this.onComplete,
    required this.onSnooze,
    this.onDismiss,
  });

  final ReminderSkin skin;
  final String title;
  final String content;
  final String timeText;
  final double glow;
  final bool busy;
  final bool compact;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 360 : 460),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 16 : skin.cardRadius),
        boxShadow: [
          if (glow > 0)
            BoxShadow(
              color: skin.glowColor.withValues(alpha: skin.glowColor.a * glow),
              blurRadius: 36 * glow,
              spreadRadius: 6 * glow,
            ),
          BoxShadow(
            color: skin.shadowColor,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 16 : skin.cardRadius),
        child: ColoredBox(
          color: skin.cardColor,
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, compact ? 24 : 30, 28, 24),
            child: compact ? _androidBody() : _windowsBody(),
          ),
        ),
      ),
    );
  }

  Widget _androidBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          skin.eyebrowLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: skin.accentColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: skin.titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            content,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: skin.subtitleColor, fontSize: 14),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          timeText,
          textAlign: TextAlign.center,
          style: TextStyle(color: skin.subtitleColor, fontSize: 14),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: skin.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(skin.completeLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onSnooze,
                style: OutlinedButton.styleFrom(
                  foregroundColor: skin.accentColor,
                  side: BorderSide(color: skin.accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(skin.snoozeLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          skin.snoozeHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: skin.subtitleColor.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _windowsBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          skin.eyebrowLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: skin.accentColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: false,
                onChanged: busy ? null : (_) => onComplete(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: skin.titleColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: skin.subtitleColor, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    timeText,
                    style: TextStyle(color: skin.subtitleColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(
              onPressed: busy ? null : onSnooze,
              style: OutlinedButton.styleFrom(
                foregroundColor: skin.accentColor,
                side: BorderSide(color: skin.accentColor),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(skin.snoozeLabel),
            ),
            const Spacer(),
            FilledButton(
              onPressed: busy || onDismiss == null ? null : onDismiss,
              style: FilledButton.styleFrom(
                backgroundColor: skin.accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: Text(skin.confirmLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          skin.snoozeHint,
          style: TextStyle(
            color: skin.subtitleColor.withValues(alpha: 0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
