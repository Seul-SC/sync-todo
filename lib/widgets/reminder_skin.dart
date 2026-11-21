import 'package:flutter/material.dart';

/// 提醒小窗的视觉令牌。
/// 当前从应用主题推导；以后换皮肤只需替换 [ReminderSkin]，不必改布局结构。
class ReminderSkin {
  const ReminderSkin({
    required this.scrimColor,
    required this.blurSigma,
    required this.cardColor,
    required this.cardRadius,
    required this.titleColor,
    required this.subtitleColor,
    required this.accentColor,
    required this.glowColor,
    required this.shadowColor,
    required this.eyebrowLabel,
    required this.completeLabel,
    required this.confirmLabel,
    required this.snoozeLabel,
    required this.snoozeHint,
  });

  final Color scrimColor;
  final double blurSigma;
  final Color cardColor;
  final double cardRadius;
  final Color titleColor;
  final Color subtitleColor;
  final Color accentColor;
  final Color glowColor;
  final Color shadowColor;
  final String eyebrowLabel;
  final String completeLabel;
  final String confirmLabel;
  final String snoozeLabel;
  final String snoozeHint;

  /// 默认皮肤：跟随当前 Theme。
  factory ReminderSkin.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final card = theme.cardTheme.color ?? scheme.surface;
    return ReminderSkin(
      scrimColor: Colors.black.withValues(alpha: 0.58),
      blurSigma: 12,
      cardColor: card,
      cardRadius: 22,
      titleColor: scheme.onSurface,
      subtitleColor: scheme.onSurface.withValues(alpha: 0.62),
      accentColor: scheme.primary,
      glowColor: scheme.primary.withValues(alpha: 0.38),
      shadowColor: Colors.black.withValues(alpha: 0.36),
      eyebrowLabel: '待办提醒',
      completeLabel: '完成',
      confirmLabel: '确定',
      snoozeLabel: '稍后提醒',
      snoozeHint: '稍后提醒将延后 10 分钟',
    );
  }
}
