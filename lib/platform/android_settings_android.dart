import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'android_settings.dart';

AndroidSettingsLauncher createAndroidSettingsLauncher() =>
    RealAndroidSettingsLauncher();

class RealAndroidSettingsLauncher implements AndroidSettingsLauncher {
  static const _autostartIntents = [
    {
      'pkg': 'com.hihonor.systemmanager',
      'cls':
          'com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
    },
    {
      'pkg': 'com.huawei.systemmanager',
      'cls':
          'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
    },
    {
      'pkg': 'com.huawei.systemmanager',
      'cls':
          'com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity',
    },
    {
      'pkg': 'com.miui.securitycenter',
      'cls': 'com.miui.permcenter.autostart.AutoStartManagementActivity',
    },
    {
      'pkg': 'com.coloros.safecenter',
      'cls': 'com.coloros.safecenter.startupapp.StartupAppListActivity',
    },
    {
      'pkg': 'com.oplus.safecenter',
      'cls': 'com.oplus.safecenter.startupapp.StartupAppListActivity',
    },
    {
      'pkg': 'com.iqoo.secure',
      'cls': 'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
    },
    {
      'pkg': 'com.vivo.permissionmanager',
      'cls': 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
    },
    {
      'pkg': 'com.samsung.android.lool',
      'cls': 'com.samsung.android.sm.ui.battery.BatteryActivity',
    },
  ];

  Future<String> _packageName() async {
    final info = await PackageInfo.fromPlatform();
    return info.packageName;
  }

  Future<bool> _launch(AndroidIntent intent) async {
    try {
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('android intent failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    final pkg = await _packageName();
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:$pkg',
    );
    if (await _launch(intent)) return true;
    return openBatteryOptimizationSettings();
  }

  @override
  Future<bool> openBatteryOptimizationSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    return _launch(intent);
  }

  @override
  Future<bool> openAppDetailsSettings() async {
    final pkg = await _packageName();
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$pkg',
    );
    return _launch(intent);
  }

  @override
  Future<bool> openAutostartSettings() async {
    for (final item in _autostartIntents) {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: item['pkg'],
        componentName: '${item['pkg']}/${item['cls']}',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      if (await _launch(intent)) return true;
    }
    return openAppDetailsSettings();
  }

  @override
  Future<bool> openNotificationSettings() async {
    final pkg = await _packageName();
    final intent = AndroidIntent(
      action: 'android.settings.APP_NOTIFICATION_SETTINGS',
      arguments: {
        'android.provider.extra.APP_PACKAGE': pkg,
      },
    );
    if (await _launch(intent)) return true;
    return openAppDetailsSettings();
  }
}
