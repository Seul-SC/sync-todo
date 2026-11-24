import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_settings.dart';
import '../theme/app_theme.dart';
import 'app_clock.dart';
import 'network_guard.dart';

class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs, {String systemTimezone = 'Asia/Shanghai'})
      : _systemTimezone = systemTimezone;

  final SharedPreferences _prefs;
  String _systemTimezone;
  String? _userId;
  SupabaseClient? _client;
  DateTime? _timezoneUpdatedAt;

  static const _themeKey = 'theme_mode';
  static const _launchKey = 'launch_at_startup';
  static const _tzKey = 'timezone';
  static const _tzUpdatedKey = 'timezone_updated_at';
  static const _manifestUrlKey = 'update_manifest_url';
  static const _notifGuideKey = 'notification_guide_shown';

  String get systemTimezone => _systemTimezone;

  void setSystemTimezone(String name) {
    if (name.isEmpty || name == _systemTimezone) return;
    _systemTimezone = name;
    notifyListeners();
  }

  AppThemeMode get themeMode {
    final raw = _prefs.getString(_themeKey);
    // 旧版「天蓝」并入「涟漪」
    if (raw == 'skyBlue') return AppThemeMode.ripple;
    return AppThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppThemeMode.light,
    );
  }

  bool get launchAtStartup => _prefs.getBool(_launchKey) ?? true;

  String get timezone => _prefs.getString(_tzKey) ?? kSystemTimezoneId;

  bool get notificationGuideShown => _prefs.getBool(_notifGuideKey) ?? false;

  String get updateManifestUrl {
    final custom = _prefs.getString(_manifestUrlKey);
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    return defaultUpdateManifestUrl();
  }

  static String defaultUpdateManifestUrl() {
    // 更新清单托管在 Gitee 仓库（国内访问稳定，不占自建服务器带宽）。
    // 自建部署时可在设置页覆盖为任意地址。
    return 'https://gitee.com/seul-sc/sync-todo/raw/main/update/version.json';
  }

  AppClock get clock => AppClock(
        preferredTimezone: timezone,
        systemTimezone: _systemTimezone,
      );

  Future<void> bindUser(String userId, SupabaseClient client) async {
    _userId = userId;
    _client = client;
    _timezoneUpdatedAt = DateTime.tryParse(
      _prefs.getString(_tzUpdatedKey) ?? '',
    )?.toUtc();
  }

  Future<void> unbind() async {
    _userId = null;
    _client = null;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    await _prefs.setBool(_launchKey, enabled);
    notifyListeners();
  }

  Future<void> setNotificationGuideShown(bool shown) async {
    await _prefs.setBool(_notifGuideKey, shown);
    notifyListeners();
  }

  Future<void> setUpdateManifestUrl(String url) async {
    await _prefs.setString(_manifestUrlKey, url.trim());
    notifyListeners();
  }

  Future<void> setTimezone(String id) async {
    final now = DateTime.now().toUtc();
    await _prefs.setString(_tzKey, id);
    await _prefs.setString(_tzUpdatedKey, now.toIso8601String());
    _timezoneUpdatedAt = now;
    notifyListeners();
    await _pushRemote();
  }

  Future<void> pullRemote() async {
    final uid = _userId;
    final client = _client;
    if (uid == null || client == null) return;
    try {
      final row = await withNetworkTimeout(client
          .from('user_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle());
      if (row == null) {
        await _pushRemote();
        return;
      }
      final remote = UserSettings.fromJson(Map<String, dynamic>.from(row));
      final localAt = _timezoneUpdatedAt;
      if (localAt == null || remote.updatedAt.isAfter(localAt)) {
        await _prefs.setString(_tzKey, remote.timezone);
        await _prefs.setString(
          _tzUpdatedKey,
          remote.updatedAt.toIso8601String(),
        );
        _timezoneUpdatedAt = remote.updatedAt;
        notifyListeners();
      } else if (localAt.isAfter(remote.updatedAt)) {
        await _pushRemote();
      }
    } catch (e) {
      debugPrint('pull user_settings failed: $e');
    }
  }

  Future<void> _pushRemote() async {
    final uid = _userId;
    final client = _client;
    if (uid == null || client == null) return;
    final updatedAt = _timezoneUpdatedAt ?? DateTime.now().toUtc();
    try {
      await withNetworkTimeout(client.rpc('upsert_user_settings', params: {
        'p_timezone': timezone,
        'p_updated_at': updatedAt.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('push user_settings failed: $e');
      try {
        await withNetworkTimeout(client.from('user_settings').upsert({
          'user_id': uid,
          'timezone': timezone,
          'updated_at': updatedAt.toIso8601String(),
        }));
      } catch (e2) {
        debugPrint('upsert user_settings fallback failed: $e2');
      }
    }
  }
}
