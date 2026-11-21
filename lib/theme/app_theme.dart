import 'package:flutter/material.dart';

import '../platform/app_os.dart';

enum AppThemeMode { light, lightGreen, accompany, ripple, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.light => '浅色',
        AppThemeMode.lightGreen => '浅绿',
        AppThemeMode.accompany => '同行',
        AppThemeMode.ripple => '涟漪',
        AppThemeMode.dark => '深色',
      };

  /// 设置里展示的主题。旧版「天蓝」会在读取时映射为「涟漪」。
  static const visible = <AppThemeMode>[
    AppThemeMode.light,
    AppThemeMode.lightGreen,
    AppThemeMode.accompany,
    AppThemeMode.ripple,
    AppThemeMode.dark,
  ];
}

class AppThemes {
  static ThemeData of(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => _build(
          brightness: Brightness.light,
          seed: const Color(0xFF6B6B6B),
          primary: const Color(0xFF3F3F3F),
          surface: const Color(0xFFFFFFFF),
          sidebar: const Color(0xFFF5F5F5),
          card: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1A1A1A),
        ),
      AppThemeMode.lightGreen => _build(
          brightness: Brightness.light,
          seed: const Color(0xFF98FF98),
          primary: const Color(0xFF3EB489),
          surface: const Color(0xFFF2FFF2),
          sidebar: const Color(0xFFC8FFC8),
          card: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF1B3D2F),
        ),
      AppThemeMode.accompany => _build(
          brightness: Brightness.light,
          seed: const Color(0xFF194253),
          primary: const Color(0xFF194253),
          surface: const Color(0xFFF8FDFF),
          sidebar: const Color(0xFFEDF9FC),
          card: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF00232C),
          border: const Color(0xFFD5EEF4),
        ),
      AppThemeMode.ripple => _build(
          brightness: Brightness.light,
          seed: const Color(0xFF3A66AC),
          primary: const Color(0xFF3A66AC),
          surface: const Color(0xFFF5F9FF),
          sidebar: const Color(0xFFCBDDFE),
          card: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF001F4F),
          border: const Color(0xFFDCE8FF),
        ),
      // 暮色巧克力，避免纯黑刺眼（这一轮不改深色）
      AppThemeMode.dark => _build(
          brightness: Brightness.dark,
          seed: const Color(0xFFC3B6C8),
          primary: const Color(0xFFB9A8B4),
          surface: const Color(0xFF2B292C),
          sidebar: const Color(0xFF232126),
          card: const Color(0xFF343236),
        ),
    };
  }

  static Color sidebarOf(ThemeData theme) {
    return theme.extension<AppColors>()?.sidebar ?? theme.colorScheme.surface;
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color primary,
    required Color surface,
    required Color sidebar,
    required Color card,
    Color? onSurface,
    Color? border,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      primary: primary,
    );
    final dense = isWindowsDesktop;
    final on = onSurface ??
        (brightness == Brightness.dark
            ? const Color(0xFFE8E2E6)
            : const Color(0xFF4A4541));
    final borderColor = border ?? on.withValues(alpha: 0.08);
    final onPrimary = brightness == Brightness.dark
        ? const Color(0xFF2A2628)
        : Colors.white;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: surface,
        primary: primary,
        onSurface: on,
        onPrimary: onPrimary,
        surfaceContainerLowest: card,
        surfaceContainerLow: card,
        surfaceContainer: card,
        surfaceContainerHigh: card,
        surfaceContainerHighest: brightness == Brightness.dark ? card : surface,
        secondaryContainer: card,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      extensions: [AppColors(sidebar: sidebar)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: on,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 14),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: card,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF3A383C)
            : card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: sidebar,
        indicatorColor: primary.withValues(alpha: 0.16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.16),
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.sidebar});

  final Color sidebar;

  @override
  AppColors copyWith({Color? sidebar}) =>
      AppColors(sidebar: sidebar ?? this.sidebar);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(sidebar: Color.lerp(sidebar, other.sidebar, t) ?? sidebar);
  }
}
