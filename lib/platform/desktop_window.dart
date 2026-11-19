import 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_io.dart' as impl;

/// Windows 自定义提醒窗需要的窗口控制；其他平台为 no-op。
/// 桌面插件只出现在 windows 实现文件中。
abstract class DesktopWindowBridge {
  Future<void> enterReminderFullscreen();
  Future<void> leaveReminderFullscreen();
  Future<void> showMainWindow();
  Future<void> hideToTray();
}

DesktopWindowBridge createDesktopWindowBridge() =>
    impl.createDesktopWindowBridge();
