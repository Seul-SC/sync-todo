import 'package:flutter/material.dart';

import '../platform/app_os.dart';

enum AppThemeMode { light, lightGreen, skyBlue, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.light => '浅色',
        AppThemeMode.lightGreen => '浅绿',
        AppThemeMode.skyBlue => '天蓝',
        AppThemeMode.dark => '深色',
      };
}

class AppThemes {
  static ThemeData of(AppThemeMode mode) {
    return switch (mode) {
      // 香草 / 杏仁色：柔和低饱和
      AppThemeMode.light => _build(
          brightness: Brightness.light,
          seed: const Color(0xFFC9B8A8),
          primary: const Color(0xFFA8988A),
          surface: const Color(0xFFFBF8F4),
          sidebar: const Color(0xFFF3EFE9),
          card: const Color(0xFFFFFCF8),
        ),
      // 抹茶马卡龙
      AppThemeMode.lightGreen => _build(
          brightness: Brightness.light,
          seed: const Color(0xFFB5D3B8),
          primary: const Color(0xFF88B08E),
          surface: const Color(0xFFF6FAF5),
          sidebar: const Color(0xFFEAF3EA),
          card: const Color(0xFFFAFDF9),
        ),
      // 粉蓝马卡龙
      AppThemeMode.skyBlue => _build(
          brightness: Brightness.light,
          seed: const Color(0xFFB4D0E2),
          primary: const Color(0xFF8AADC2),
          surface: const Color(0xFFF5F9FC),
          sidebar: const Color(0xFFE8F1F7),
          card: const Color(0xFFFAFCFE),
        ),
      // 暮色巧克力，避免纯黑刺眼
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
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      primary: primary,
    );
    final dense = isWindowsDesktop;
    final onSurface = brightness == Brightness.dark
        ? const Color(0xFFE8E2E6)
        : const Color(0xFF4A4541);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        onSurface: onSurface,
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF2A2628)
            : Colors.white,
      ),
      scaffoldBackgroundColor: surface,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      extensions: [AppColors(sidebar: sidebar)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 8 : 14),
          side: BorderSide(
            color: onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: onSurface.withValues(alpha: 0.08),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF3A383C)
            : Colors.white.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.08)),
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
        foregroundColor: brightness == Brightness.dark
            ? const Color(0xFF2A2628)
            : Colors.white,
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
