import 'dart:io';

import 'desktop_shell.dart';
import 'desktop_shell_stub.dart' as stub;
import 'desktop_shell_windows.dart' as win;
import 'settings_service.dart';

DesktopShell? createDesktopShell({
  required SettingsService settings,
  required TrayAction onShowWindow,
  required TrayAction onQuit,
  bool Function()? isReminderShowing,
}) {
  if (Platform.isWindows) {
    return win.createDesktopShell(
      settings: settings,
      onShowWindow: onShowWindow,
      onQuit: onQuit,
      isReminderShowing: isReminderShowing,
    );
  }
  return stub.createDesktopShell(
    settings: settings,
    onShowWindow: onShowWindow,
    onQuit: onQuit,
    isReminderShowing: isReminderShowing,
  );
}
