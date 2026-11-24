import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrapDesktopWindow({bool startHidden = false}) async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(880, 560),
    center: true,
    title: '同步待办',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    if (startHidden) {
      // 开机自启：不弹主窗口、不进任务栏，托盘图标照常出现。
      await windowManager.setSkipTaskbar(true);
      return;
    }
    await windowManager.show();
    await windowManager.focus();
  });
}
