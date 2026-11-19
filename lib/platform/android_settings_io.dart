import 'dart:io';

import 'android_settings.dart';
import 'android_settings_android.dart' as android;
import 'android_settings_stub.dart' as stub;

AndroidSettingsLauncher createAndroidSettingsLauncher() {
  if (Platform.isAndroid) {
    return android.createAndroidSettingsLauncher();
  }
  return stub.createAndroidSettingsLauncher();
}
