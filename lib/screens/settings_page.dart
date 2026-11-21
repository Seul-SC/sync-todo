import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/todo_item.dart';
import '../models/user_settings.dart';
import '../platform/android_settings.dart';
import '../platform/app_os.dart';
import '../services/desktop_shell.dart';
import '../services/notification_service.dart';
import '../services/reminder_controller.dart';
import '../services/settings_service.dart';
import '../services/todo_repository.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/about_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.updates,
    required this.todos,
    this.desktop,
    this.reminder,
    required this.onSignOut,
    this.embedded = false,
  });

  final SettingsService settings;
  final UpdateService updates;
  final TodoRepository todos;
  final DesktopShell? desktop;
  final ReminderController? reminder;
  final Future<void> Function() onSignOut;
  final bool embedded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _androidSettings = createAndroidSettingsLauncher();
  bool? _notifGranted;

  @override
  void initState() {
    super.initState();
    widget.updates.loadCurrent();
    if (isAndroidDevice) {
      NotificationService.instance.isNotificationGranted().then((v) {
        if (mounted) setState(() => _notifGranted = v);
      });
    }
  }

  Future<void> _pickTheme() async {
    final selected = await showDialog<AppThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('主题'),
        children: [
          for (final mode in AppThemeModeLabel.visible)
            RadioListTile<AppThemeMode>(
              title: Text(mode.label),
              value: mode,
              groupValue: widget.settings.themeMode,
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (selected != null) {
      await widget.settings.setThemeMode(selected);
    }
  }

  Future<void> _pickTimezone() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('时区'),
        children: [
          for (final opt in kTimezoneOptions)
            RadioListTile<String>(
              title: Text(opt.label),
              subtitle: opt.id == kSystemTimezoneId
                  ? Text(widget.settings.systemTimezone)
                  : Text(opt.id),
              value: opt.id,
              groupValue: widget.settings.timezone,
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
    if (selected != null) {
      await widget.settings.setTimezone(selected);
    }
  }

  String _timezoneLabel() {
    final id = widget.settings.timezone;
    final found = kTimezoneOptions.where((e) => e.id == id);
    if (found.isNotEmpty) {
      if (id == kSystemTimezoneId) {
        return '${found.first.label}（${widget.settings.systemTimezone}）';
      }
      return '${found.first.label}（$id）';
    }
    return id;
  }

  Future<void> _requestNotification() async {
    final ok = await NotificationService.instance.requestPermission();
    if (mounted) setState(() => _notifGranted = ok);
    if (!ok) {
      await _androidSettings.openNotificationSettings();
    }
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已允许通知')),
      );
    }
  }

  Future<void> _checkUpdate({bool silent = false}) async {
    final info = await widget.updates.check(silent: silent);
    if (!mounted) return;
    if (info == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.updates.error ?? '无法检查更新')),
        );
      }
      return;
    }
    if (!widget.updates.isNewer(info)) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版（${widget.updates.currentVersion}）')),
        );
      }
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 ${info.version}'),
        content: Text(
          info.notes.trim().isEmpty ? '有新版本可用，要现在下载吗？' : info.notes,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下载'),
          ),
        ],
      ),
    );
    if (go == true) {
      await _download(info);
    }
  }

  Future<void> _download(info) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.updates,
          builder: (context, _) {
            return AlertDialog(
              title: const Text('正在下载更新'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: widget.updates.progress == 0 ? null : widget.updates.progress),
                  const SizedBox(height: 12),
                  Text('${(widget.updates.progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                  if (widget.updates.error != null)
                    Text(widget.updates.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            );
          },
        );
      },
    );
    final shouldQuit = await widget.updates.downloadAndInstall(info);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (widget.updates.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.updates.error!)),
      );
      return;
    }
    if (shouldQuit && isWindowsDesktop) {
      await widget.desktop?.quitApp();
    } else if (isAndroidDevice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在系统对话框中确认安装')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedBuilder(
      animation: Listenable.merge([widget.settings, widget.updates]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _sectionTitle('外观'),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题'),
              subtitle: Text(widget.settings.themeMode.label),
              onTap: _pickTheme,
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('时区'),
              subtitle: Text(_timezoneLabel()),
              onTap: _pickTimezone,
            ),
            if (isWindowsDesktop) ...[
              _sectionTitle('电脑'),
              SwitchTheme(
                data: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return const Color(0xFFBDBDBD);
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(context).colorScheme.primary;
                    }
                    return const Color(0xFF9E9E9E).withValues(alpha: 0.35);
                  }),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.power_settings_new,
                    color: widget.settings.launchAtStartup
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  title: const Text('开机自启'),
                  subtitle: const Text('只有程序在运行时才能弹出待办提醒。关闭程序后，到点不会提醒。'),
                  isThreeLine: true,
                  value: widget.settings.launchAtStartup,
                  onChanged: (v) async {
                    await widget.desktop?.applyLaunchAtStartup(v);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('预览提醒弹窗'),
                onTap: () async {
                  final sample = widget.todos.activeItems.isNotEmpty
                      ? widget.todos.activeItems.first
                      : TodoItem.create(userId: 'preview', title: '提醒预览');
                  await widget.reminder?.previewReminder(sample);
                },
              ),
            ],
            if (isAndroidDevice) ...[
              _sectionTitle('通知与后台'),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知权限'),
                subtitle: Text(
                  _notifGranted == true
                      ? '已允许。应用在前台用弹窗提醒，被系统杀掉后用系统通知兜底。'
                      : '未允许。荣耀等手机会杀后台，没有通知权限时可能收不到提醒。',
                ),
                trailing: TextButton(
                  onPressed: _requestNotification,
                  child: Text(_notifGranted == true ? '已开启' : '去开启'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.battery_saver_outlined),
                title: const Text('电池白名单'),
                subtitle: const Text(
                  '请允许「同步待办」忽略电池优化，并加入自启动名单，这样到点才更可能弹出提醒。',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () =>
                      _androidSettings.requestIgnoreBatteryOptimizations(),
                  child: const Text('去设置'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('自启动 / 后台运行'),
                subtitle: const Text(
                  '荣耀、华为等系统需要在「启动管理」里允许应用自启动和后台活动。点下面按钮会尽量打开对应设置页；如果没有跳到正确页面，请到系统设置里手动添加白名单。',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => _androidSettings.openAutostartSettings(),
                  child: const Text('去设置'),
                ),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('打开应用系统设置'),
              ),
            ],
            _sectionTitle('更新'),
            ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              title: const Text('检查更新'),
              subtitle: Text(
                '当前版本 ${widget.updates.currentVersion}（${widget.updates.currentBuild}）',
              ),
              trailing: widget.updates.checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: widget.updates.checking ? null : () => _checkUpdate(),
            ),
            _sectionTitle('关于'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: const Text('作者、仓库链接和问题反馈'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutAppSheet(context),
            ),
            _sectionTitle('账号'),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出当前账号吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('退出'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await widget.onSignOut();
              },
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: body,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 首次进入 Android 时引导通知权限和白名单。
Future<void> showAndroidPermissionGuide({
  required BuildContext context,
  required SettingsService settings,
}) async {
  if (!isAndroidDevice) return;
  if (settings.notificationGuideShown) return;
  await settings.setNotificationGuideShown(true);
  if (!context.mounted) return;
  final launcher = createAndroidSettingsLauncher();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('开启提醒权限'),
      content: const Text(
        '为了尽可能做到「有通知就有提醒」，请允许通知权限，并把本应用加入自启动和电池白名单。荣耀等手机会限制后台，不开启时到点可能无法弹出提醒。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: () async {
            await launcher.requestIgnoreBatteryOptimizations();
          },
          child: const Text('电池白名单'),
        ),
        FilledButton(
          onPressed: () async {
            await NotificationService.instance.requestPermission();
            await launcher.openAutostartSettings();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('去开启'),
        ),
      ],
    ),
  );
}
