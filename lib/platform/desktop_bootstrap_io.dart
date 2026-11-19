import 'dart:io';

import 'desktop_bootstrap_stub.dart' as stub;
import 'desktop_bootstrap_windows.dart' as win;

Future<void> bootstrapDesktopWindow() async {
  if (Platform.isWindows) {
    await win.bootstrapDesktopWindow();
    return;
  }
  await stub.bootstrapDesktopWindow();
}
