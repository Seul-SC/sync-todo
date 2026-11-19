import 'desktop_shell_stub.dart'
    if (dart.library.io) 'desktop_shell_io.dart' as impl;
import 'settings_service.dart';

typedef TrayAction = void Function();

/// Windows：关窗进托盘、托盘菜单、开机自启。其他平台为 no-op。
abstract class DesktopShell {
  Future<void> init();
  Future<void> applyLaunchAtStartup(bool enabled);
  Future<void> showMainWindow();
  Future<void> hideToTray();
  Future<void> quitApp();
  void dispose();
}

DesktopShell? createDesktopShell({
  required SettingsService settings,
  required TrayAction onShowWindow,
  required TrayAction onQuit,
  bool Function()? isReminderShowing,
}) {
  return impl.createDesktopShell(
    settings: settings,
    onShowWindow: onShowWindow,
    onQuit: onQuit,
    isReminderShowing: isReminderShowing,
  );
}
