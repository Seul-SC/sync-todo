import 'dart:ffi';
import 'package:ffi/ffi.dart';
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

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

int _endMenu() {
  try {
    return _user32.lookupFunction<Int32 Function(), int Function()>('EndMenu')();
  } catch (_) {
    return 0;
  }
}

/// 托盘菜单在主窗口隐藏时，需要先把窗口设为前台，点桌面才能把菜单关掉。
void _focusAppWindowForTrayMenu() {
  try {
    final findWindow = _user32.lookupFunction<
        IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
        int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');
    final setForeground = _user32.lookupFunction<
        Int32 Function(IntPtr),
        int Function(int)>('SetForegroundWindow');
    final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    final title = '同步待办'.toNativeUtf16();
    try {
      final hwnd = findWindow(className, title);
      if (hwnd != 0) {
        setForeground(hwnd);
      }
    } finally {
      malloc.free(className);
      malloc.free(title);
    }
  } catch (_) {}
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

  Future<void> _closeTrayMenu() async {
    _endMenu();
  }

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
    await _closeTrayMenu();
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
    onShowWindow();
  }

  @override
  Future<void> hideToTray() async {
    await _closeTrayMenu();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  @override
  Future<void> quitApp() async {
    if (_quitting) {
      exit(0);
    }
    _quitting = true;
    try {
      await _closeTrayMenu();
    } catch (_) {}
    try {
      await trayManager.destroy().timeout(const Duration(milliseconds: 400));
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    try {
      await windowManager.destroy().timeout(const Duration(milliseconds: 600));
    } catch (_) {}
    onQuit();
    exit(0);
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    if (isReminderShowing?.call() == true) return;
    hideToTray();
  }

  @override
  void onWindowBlur() {
    _closeTrayMenu();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'blur' || eventName == 'move') {
      _closeTrayMenu();
    }
  }

  @override
  void onTrayIconMouseDown() {
    _closeTrayMenu();
    showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    _focusAppWindowForTrayMenu();
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
