import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../platform/app_os.dart';
import '../platform/desktop_window.dart';
import 'notification_service.dart';
import 'todo_repository.dart';

/// 到点提醒控制器。
/// Windows：把主窗口铺成全屏遮罩，同时可显示多张自定义卡片。
/// Android：应用在前台时同时叠多张自定义卡片；被杀掉后由系统通知兜底。
class ReminderController extends ChangeNotifier with WidgetsBindingObserver {
  ReminderController({
    required TodoRepository repository,
    required VoidCallback onNeedOverlay,
    DesktopWindowBridge? window,
  })  : _repository = repository,
        _onNeedOverlay = onNeedOverlay,
        _window = window ??
            (isWindowsDesktop ? createDesktopWindowBridge() : null);

  final TodoRepository _repository;
  final VoidCallback _onNeedOverlay;
  final DesktopWindowBridge? _window;

  Timer? _timer;
  final List<TodoItem> _active = [];
  final Set<String> _firedKeys = {};
  bool _started = false;
  bool _windowEntered = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  List<TodoItem> get active => List.unmodifiable(_active);
  bool get isShowing => _active.isNotEmpty;

  /// 兼容旧调用：第一张正在显示的卡片。
  TodoItem? get current => _active.isEmpty ? null : _active.first;

  void start() {
    if (_started) {
      _tick();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _repository.removeListener(_onRepoChanged);
    _repository.addListener(_onRepoChanged);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    _tick();
    unawaited(_rescheduleSystemNotifications());
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _repository.removeListener(_onRepoChanged);
    _timer?.cancel();
    _timer = null;
    unawaited(dismissAll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _tick();
      unawaited(_rescheduleSystemNotifications());
    }
  }

  bool get _inForeground =>
      _lifecycle == AppLifecycleState.resumed ||
      _lifecycle == AppLifecycleState.inactive;

  void _onRepoChanged() {
    unawaited(_rescheduleSystemNotifications());
    if (_active.isEmpty) return;
    final remaining = <TodoItem>[];
    for (final item in List<TodoItem>.from(_active)) {
      final latest = _repository.findById(item.id);
      if (latest == null || latest.isDeleted) continue;
      if (latest.completed && !latest.isRecurring) continue;
      if (item.remindAt != latest.remindAt) continue;
      remaining.add(latest);
    }
    if (remaining.length != _active.length ||
        !_sameIds(remaining, _active)) {
      _active
        ..clear()
        ..addAll(remaining);
      notifyListeners();
      if (_active.isEmpty) {
        unawaited(_leavePopupIfNeeded());
      }
    }
  }

  bool _sameIds(List<TodoItem> a, List<TodoItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  String _fireKey(TodoItem item) {
    final at = item.remindAt?.toUtc().millisecondsSinceEpoch ?? 0;
    return '${item.id}@$at';
  }

  Future<void> _tick() async {
    if (isAndroidDevice && !_inForeground) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (_firedKeys.length > 200) {
      _firedKeys.clear();
    }

    final due = _repository.dueReminders(now);
    var added = false;
    for (final item in due) {
      final key = _fireKey(item);
      if (_firedKeys.contains(key)) continue;
      if (_active.any((e) => e.id == item.id)) continue;
      final at = item.remindAt!;
      if (now.difference(at) > const Duration(minutes: 1)) {
        _firedKeys.add(key);
        continue;
      }
      await _present(item);
      added = true;
    }
    if (added) {
      _onNeedOverlay();
      notifyListeners();
    }
  }

  Future<void> _present(TodoItem item) async {
    _firedKeys.add(_fireKey(item));
    _active.add(item);
    if (isWindowsDesktop && !_windowEntered) {
      try {
        await _window?.enterReminderFullscreen();
        _windowEntered = true;
      } catch (e) {
        debugPrint('showReminder window error: $e');
      }
    } else if (isAndroidDevice) {
      await NotificationService.instance.cancelItem(item);
    }
  }

  Future<void> showReminder(TodoItem item) async {
    if (_active.any((e) => e.id == item.id && e.remindAt == item.remindAt)) {
      return;
    }
    await _present(item);
    _onNeedOverlay();
    notifyListeners();
  }

  /// 验收用：立刻弹出指定待办的自定义提醒窗（不经过到点判定）。
  Future<void> previewReminder(TodoItem item) async {
    await showReminder(item);
  }

  Future<void> completeItem(TodoItem item) async {
    final latest = _repository.findById(item.id) ?? item;
    await _repository.completeTodo(latest);
    _active.removeWhere((e) => e.id == item.id);
    notifyListeners();
    await _leavePopupIfNeeded();
  }

  Future<void> snoozeItem(TodoItem item) async {
    final latest = _repository.findById(item.id) ?? item;
    await _repository.snoozeTodo(latest, by: const Duration(minutes: 10));
    _firedKeys.remove(_fireKey(latest));
    final refreshed = _repository.findById(latest.id);
    if (refreshed != null) {
      _firedKeys.remove(_fireKey(refreshed));
    }
    _active.removeWhere((e) => e.id == item.id);
    notifyListeners();
    await _leavePopupIfNeeded();
  }

  /// 只关掉本机这一张提醒窗，不标记完成、不改提醒时间。
  Future<void> dismissItem(TodoItem item) async {
    _active.removeWhere((e) => e.id == item.id);
    notifyListeners();
    await _leavePopupIfNeeded();
  }

  /// 兼容旧的单条接口。
  Future<void> completeCurrent() async {
    final item = current;
    if (item == null) return;
    await completeItem(item);
  }

  Future<void> snoozeCurrent() async {
    final item = current;
    if (item == null) return;
    await snoozeItem(item);
  }

  Future<void> dismissWithoutAction() async {
    await dismissAll();
  }

  Future<void> dismissAll() async {
    if (_active.isEmpty && !_windowEntered) return;
    _active.clear();
    notifyListeners();
    await _leavePopupIfNeeded();
  }

  Future<void> _leavePopupIfNeeded() async {
    if (_active.isNotEmpty) return;
    if (isWindowsDesktop && _windowEntered) {
      await _window?.leaveReminderFullscreen();
      _windowEntered = false;
    }
  }

  Future<void> _rescheduleSystemNotifications() async {
    if (!isAndroidDevice) return;
    await NotificationService.instance.scheduleUpcoming(
      _repository.upcomingReminders(),
      _repository.clock,
    );
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
