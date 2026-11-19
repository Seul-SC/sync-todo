import 'dart:io';

import 'desktop_window.dart';
import 'desktop_window_stub.dart' as stub;
import 'desktop_window_windows.dart' as win;

DesktopWindowBridge createDesktopWindowBridge() {
  if (Platform.isWindows) {
    return win.createDesktopWindowBridge();
  }
  return stub.createDesktopWindowBridge();
}
