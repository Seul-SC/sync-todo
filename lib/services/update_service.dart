import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/app_os.dart';
import 'settings_service.dart';

class AppUpdateInfo {
  AppUpdateInfo({
    required this.version,
    this.build,
    this.notes = '',
    this.windowsUrl,
    this.androidUrl,
  });

  final String version;
  final int? build;
  final String notes;
  final String? windowsUrl;
  final String? androidUrl;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    String? urlOf(dynamic value, String key) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        final u = value['url'] ?? value[key];
        if (u is String && u.trim().isNotEmpty) return u.trim();
      }
      return null;
    }

    return AppUpdateInfo(
      version: '${json['version'] ?? ''}',
      build: json['build'] is num ? (json['build'] as num).toInt() : null,
      notes: '${json['notes'] ?? json['changelog'] ?? ''}',
      windowsUrl: urlOf(json['windows'], 'windows'),
      androidUrl: urlOf(json['android'], 'android'),
    );
  }

  String? get downloadUrl {
    if (isWindowsDesktop) return windowsUrl;
    if (isAndroidDevice) return androidUrl;
    return windowsUrl ?? androidUrl;
  }
}

class UpdateService extends ChangeNotifier {
  UpdateService(this._settings);

  final SettingsService _settings;

  bool checking = false;
  bool downloading = false;
  double progress = 0;
  String? error;
  AppUpdateInfo? latest;
  String currentVersion = '1.1.0';
  int currentBuild = 11;

  Future<void> loadCurrent() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
      currentBuild = int.tryParse(info.buildNumber) ?? currentBuild;
      notifyListeners();
    } catch (e) {
      debugPrint('package info: $e');
    }
  }

  bool isNewer(AppUpdateInfo remote) {
    final cmp = _compareVersion(remote.version, currentVersion);
    if (cmp > 0) return true;
    if (cmp == 0 && remote.build != null) {
      return remote.build! > currentBuild;
    }
    return false;
  }

  int _compareVersion(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((e) => e.isNotEmpty)
        .map(int.parse)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final da = i < pa.length ? pa[i] : 0;
      final db = i < pb.length ? pb[i] : 0;
      if (da != db) return da.compareTo(db);
    }
    return 0;
  }

  Future<AppUpdateInfo?> check({bool silent = false}) async {
    if (!silent) {
      checking = true;
      error = null;
      notifyListeners();
    }
    try {
      final url = _settings.updateManifestUrl;
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
      if (res.statusCode == 404 || res.statusCode == 403) {
        // 更新通道尚未发布或当前没有更新包时，视为已是最新版。
        latest = AppUpdateInfo(version: currentVersion, build: currentBuild);
        error = null;
        notifyListeners();
        return latest;
      }
      if (res.statusCode != 200) {
        throw Exception('服务器暂时无法检查更新（${res.statusCode}）');
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map) throw Exception('更新清单格式不正确');
      latest = AppUpdateInfo.fromJson(Map<String, dynamic>.from(json));
      error = null;
      notifyListeners();
      return latest;
    } catch (e) {
      if (!silent) {
        error = '无法检查更新，请检查网络后重试';
        notifyListeners();
      }
      return null;
    } finally {
      if (!silent) {
        checking = false;
        notifyListeners();
      }
    }
  }

  /// 返回 true 表示已启动 Windows 安装程序，调用方应退出应用以便覆盖文件。
  Future<bool> downloadAndInstall(AppUpdateInfo info) async {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) {
      error = '当前平台没有可用的下载地址';
      notifyListeners();
      return false;
    }
    downloading = true;
    progress = 0;
    error = null;
    notifyListeners();
    try {
      final dir = await getTemporaryDirectory();
      final name = url.split('/').last.split('?').first;
      final ext = isAndroidDevice
          ? (name.endsWith('.apk') ? name : 'sync-todo-update.apk')
          : (name.endsWith('.exe') ? name : 'SyncTodo-Setup.exe');
      final file = File('${dir.path}${Platform.pathSeparator}$ext');

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception('下载失败（${response.statusCode}）');
      }
      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress = received / total;
          notifyListeners();
        }
      }
      await sink.close();
      progress = 1;
      notifyListeners();

      if (isAndroidDevice) {
        // 打开系统安装确认，不自行静默安装。
        await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
        return false;
      }
      if (isWindowsDesktop) {
        await Process.start(
          file.path,
          const [],
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
        return true;
      }
      return false;
    } catch (e) {
      error = '下载或安装失败：$e';
      notifyListeners();
      return false;
    } finally {
      downloading = false;
      notifyListeners();
    }
  }
}
