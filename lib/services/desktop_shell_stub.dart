import 'desktop_shell.dart';
import 'settings_service.dart';

class StubDesktopShell implements DesktopShell {
  @override
  Future<void> init() async {}

  @override
  Future<void> applyLaunchAtStartup(bool enabled) async {}

  @override
  Future<void> showMainWindow() async {}

  @override
  Future<void> hideToTray() async {}

  @override
  Future<void> quitApp() async {}

  @override
  void dispose() {}
}

DesktopShell? createDesktopShell({
  required SettingsService settings,
  required TrayAction onShowWindow,
  required TrayAction onQuit,
  bool Function()? isReminderShowing,
}) {
  return null;
}
