import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrapDesktopWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(880, 560),
    center: true,
    title: '同步待办',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
