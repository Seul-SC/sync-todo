import 'desktop_window.dart';

class StubDesktopWindowBridge implements DesktopWindowBridge {
  @override
  Future<void> enterReminderFullscreen() async {}

  @override
  Future<void> leaveReminderFullscreen() async {}

  @override
  Future<void> showMainWindow() async {}

  @override
  Future<void> hideToTray() async {}
}

DesktopWindowBridge createDesktopWindowBridge() => StubDesktopWindowBridge();
