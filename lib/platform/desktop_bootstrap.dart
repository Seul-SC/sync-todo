import 'desktop_bootstrap_stub.dart'
    if (dart.library.io) 'desktop_bootstrap_io.dart' as impl;

/// 仅 Windows 会真正初始化 window_manager；其他平台为空操作。
/// [startHidden] 为 true 时（开机自启 --minimized）不显示主窗口。
Future<void> bootstrapDesktopWindow({bool startHidden = false}) =>
    impl.bootstrapDesktopWindow(startHidden: startHidden);
