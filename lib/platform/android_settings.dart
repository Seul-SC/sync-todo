import 'android_settings_stub.dart'
    if (dart.library.io) 'android_settings_io.dart' as impl;

/// 打开系统设置：通知、电池白名单、各厂商自启动页。非 Android 为空操作。
abstract class AndroidSettingsLauncher {
  Future<bool> requestIgnoreBatteryOptimizations();
  Future<bool> openBatteryOptimizationSettings();
  Future<bool> openAppDetailsSettings();
  Future<bool> openAutostartSettings();
  Future<bool> openNotificationSettings();
}

AndroidSettingsLauncher createAndroidSettingsLauncher() =>
    impl.createAndroidSettingsLauncher();
