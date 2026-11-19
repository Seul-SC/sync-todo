import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_shell.dart';
import 'settings_service.dart';

DesktopShell createDesktopShell({
  required SettingsService settings,
  required TrayAction onShowWindow,
  required TrayAction onQuit,
  bool Function()? isReminderShowing,
}) {
  return WindowsDesktopShell(
    settings: settings,
    onShowWindow: onShowWindow,
    onQuit: onQuit,
    isReminderShowing: isReminderShowing,
  );
}

class WindowsDesktopShell with WindowListener, TrayListener implements DesktopShell {
  WindowsDesktopShell({
    required this.settings,
    required this.onShowWindow,
    required this.onQuit,
    this.isReminderShowing,
  });

  final SettingsService settings;
  final TrayAction onShowWindow;
  final TrayAction onQuit;
  final bool Function()? isReminderShowing;

  bool _quitting = false;

  @override
  Future<void> init() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('同步待办');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: '打开主窗口'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出程序'),
    ]));
    trayManager.addListener(this);

    launchAtStartup.setup(
      appName: '同步待办',
      appPath: Platform.resolvedExecutable,
      args: [],
    );
    await applyLaunchAtStartup(settings.launchAtStartup);
  }

  @override
  Future<void> applyLaunchAtStartup(bool enabled) async {
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      await settings.setLaunchAtStartup(enabled);
    } catch (e) {
      debugPrint('launch_at_startup error: $e');
    }
  }

  @override
  Future<void> showMainWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    onShowWindow();
  }

  @override
  Future<void> hideToTray() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  @override
  Future<void> quitApp() async {
    _quitting = true;
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    onQuit();
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    if (isReminderShowing?.call() == true) return;
    hideToTray();
  }

  @override
  void onTrayIconMouseDown() {
    showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showMainWindow();
      case 'quit':
        quitApp();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }
}
