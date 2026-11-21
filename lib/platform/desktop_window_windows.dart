import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_window.dart';

DesktopWindowBridge createDesktopWindowBridge() => WindowsDesktopWindowBridge();

class WindowsDesktopWindowBridge implements DesktopWindowBridge {
  bool _popupWindowActive = false;
  bool _wasHidden = false;
  Size? _savedSize;
  Offset? _savedPosition;
  bool _savedMaximized = false;
  bool _savedAlwaysOnTop = false;
  bool _savedSkipTaskbar = false;
  bool _savedResizable = true;
  TitleBarStyle _savedTitleBarStyle = TitleBarStyle.normal;
  Future<void>? _transition;

  bool get isPopupWindowActive => _popupWindowActive;

  Future<void> _serialized(Future<void> Function() action) async {
    while (_transition != null) {
      await _transition;
    }
    final done = Completer<void>();
    _transition = done.future;
    try {
      await action();
    } finally {
      done.complete();
      if (identical(_transition, done.future)) {
        _transition = null;
      }
    }
  }

  @override
  Future<void> enterReminderFullscreen() async {
    await _serialized(() async {
      if (_popupWindowActive) return;
      _wasHidden = !(await windowManager.isVisible());
      _savedMaximized = await windowManager.isMaximized();
      _savedSize = await windowManager.getSize();
      _savedPosition = await windowManager.getPosition();
      _savedAlwaysOnTop = await windowManager.isAlwaysOnTop();
      _savedSkipTaskbar = await windowManager.isSkipTaskbar();
      _savedResizable = true;
      _savedTitleBarStyle = TitleBarStyle.normal;

      final display = await screenRetriever.getPrimaryDisplay();
      final origin = display.visiblePosition ?? Offset.zero;
      final area = display.visibleSize ?? display.size;
      final visible = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        area.width,
        area.height,
      );

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      if (_savedMaximized) {
        await windowManager.unmaximize();
      }
      await windowManager.setPosition(Offset(visible.left, visible.top));
      await windowManager.setSize(Size(visible.width, visible.height));
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
      _popupWindowActive = true;
    });
  }

  @override
  Future<void> leaveReminderFullscreen() async {
    await _serialized(() async {
      if (!_popupWindowActive) return;
      try {
        await windowManager.setResizable(_savedResizable);
        await windowManager.setAlwaysOnTop(_savedAlwaysOnTop);
        await windowManager.setTitleBarStyle(
          _savedTitleBarStyle,
          windowButtonVisibility: true,
        );
        if (_savedSize != null) {
          await windowManager.setSize(_savedSize!);
        } else {
          await windowManager.setSize(const Size(1100, 720));
        }
        if (_savedPosition != null) {
          await windowManager.setPosition(_savedPosition!);
        } else {
          await windowManager.center();
        }
        if (_savedMaximized) {
          await windowManager.maximize();
        }
        if (_wasHidden) {
          await windowManager.hide();
          await windowManager.setSkipTaskbar(true);
        } else {
          await windowManager.setSkipTaskbar(_savedSkipTaskbar);
          await windowManager.show();
          await windowManager.focus();
        }
      } catch (e) {
        debugPrint('leaveReminderFullscreen error: $e');
        try {
          await windowManager.setResizable(true);
          await windowManager.setAlwaysOnTop(false);
          await windowManager.setTitleBarStyle(
            TitleBarStyle.normal,
            windowButtonVisibility: true,
          );
          await windowManager.setSize(const Size(1100, 720));
          await windowManager.center();
          await windowManager.show();
        } catch (_) {}
      }
      _popupWindowActive = false;
      _wasHidden = false;
    });
  }

  @override
  Future<void> showMainWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hideToTray() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}
