import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'platform/app_os.dart';
import 'platform/desktop_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 开机自启传入 --minimized：只在托盘驻留，不弹出主窗口。
  final startHidden = args.contains('--minimized');
  await bootstrapDesktopWindow(startHidden: startHidden);
  final systemTimezone = await initializeAppTimezones();
  if (isAndroidDevice) {
    await NotificationService.instance.init();
  }

  // 即使钥匙仍是占位符也初始化，登录页会给出中文提示。
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs, systemTimezone: systemTimezone);

  runApp(SyncTodoApp(settings: settings));
}
