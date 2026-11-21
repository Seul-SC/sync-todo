import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLogin {
  SavedLogin({required this.email, required this.password});

  final String email;
  final String password;
}

/// 记住登录邮箱和密码；会话仍由 Supabase 自动保持，退出登录前会一直留在当前账号。
class SavedCredentials {
  SavedCredentials(this._prefs);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _rememberKey = 'remember_credentials';
  static const _emailKey = 'saved_login_email';
  static const _passwordKey = 'saved_login_password';

  bool get remember => _prefs.getBool(_rememberKey) ?? true;

  Future<void> setRemember(bool value) async {
    await _prefs.setBool(_rememberKey, value);
    if (!value) {
      await clear();
    }
  }

  Future<SavedLogin?> load() async {
    if (!remember) return null;
    final email = (_prefs.getString(_emailKey) ?? '').trim();
    if (email.isEmpty) return null;
    var password = '';
    try {
      password = await _secure.read(key: _passwordKey) ?? '';
    } catch (_) {
      password = _prefs.getString(_passwordKey) ?? '';
    }
    return SavedLogin(email: email, password: password);
  }

  Future<void> save({required String email, required String password}) async {
    await _prefs.setBool(_rememberKey, true);
    await _prefs.setString(_emailKey, email);
    try {
      await _secure.write(key: _passwordKey, value: password);
      await _prefs.remove(_passwordKey);
    } catch (_) {
      await _prefs.setString(_passwordKey, password);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_emailKey);
    await _prefs.remove(_passwordKey);
    try {
      await _secure.delete(key: _passwordKey);
    } catch (_) {}
  }
}
