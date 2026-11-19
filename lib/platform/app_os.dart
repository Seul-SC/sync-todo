import 'package:flutter/foundation.dart';

/// 平台判断不依赖 dart:io，避免 Web 编译问题；Android / Windows 均可使用。
bool get isWindowsDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

bool get isAndroidDevice =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get isCupertinoMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
