import 'android_settings.dart';

class StubAndroidSettingsLauncher implements AndroidSettingsLauncher {
  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => false;

  @override
  Future<bool> openBatteryOptimizationSettings() async => false;

  @override
  Future<bool> openAppDetailsSettings() async => false;

  @override
  Future<bool> openAutostartSettings() async => false;

  @override
  Future<bool> openNotificationSettings() async => false;
}

AndroidSettingsLauncher createAndroidSettingsLauncher() =>
    StubAndroidSettingsLauncher();
