import 'dart:io';

import 'desktop_bootstrap_stub.dart' as stub;
import 'desktop_bootstrap_windows.dart' as win;

Future<void> bootstrapDesktopWindow({bool startHidden = false}) async {
  if (Platform.isWindows) {
    await win.bootstrapDesktopWindow(startHidden: startHidden);
    return;
  }
  await stub.bootstrapDesktopWindow();
}
