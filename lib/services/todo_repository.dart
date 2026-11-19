import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/todo_item.dart';
import 'app_clock.dart';
import 'local_store.dart';

class TodoRepository extends ChangeNotifier {
  TodoRepository({
    required LocalStore store,
    required SupabaseClient client,
    required AppClock Function() clock,
  })  : _store = store,
        _client = client,
        _clock = clock;

  final LocalStore _store;
  final SupabaseClient _client;
  final AppClock Function() _clock;

  final List<TodoItem> _items = [];
  bool _loading = false;
  bool _syncing = false;
  String? _error;
  String? _userId;

  List<TodoItem> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get syncing => _syncing;
  String? get error => _error;
  String? get userId => _userId;
  AppClock get clock => _clock();

  List<TodoItem> get activeItems =>
      _items.where((e) => !e.isDeleted && !(e.completed && !e.isRecurring)).toList();

  List<TodoItem> get completedItems => _items
      .where((e) => !e.isDeleted && e.completed && !e.isRecurring)
      .toList();

  List<TodoItem> get trashItems =>
      _items.where((e) => e.isDeleted).toList();

  Future<void> bindUser(String userId, {List<TodoItem>? cached}) async {
    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items
        ..clear()
        ..addAll(cached ?? []);
      notifyListeners();
    } catch (e) {
      _error = '加载本地待办失败：$e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> unbind() async {
    _userId = null;
    _items.clear();
    notifyListeners();
  }

  Future<void> _persist() async {
    final uid = _userId;
    if (uid == null) return;
    await _store.saveTodos(uid, _items);
  }

  void _upsertLocal(TodoItem item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index < 0) {
      _items.add(item);
    } else if (!item.updatedAt.isBefore(_items[index].updatedAt)) {
      _items[index] = item;
    }
  }

  Future<bool> _online() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((e) => e != ConnectivityResult.none);
  }

  Future<void> pull({bool silent = false}) async {
    final uid = _userId;
    if (uid == null) return;
    if (!await _online()) {
      _error = null;
      notifyListeners();
      return;
    }

    if (!silent) {
      _syncing = true;
      notifyListeners();
    }
    try {
      final rows = await _client
          .from('todos')
          .select()
          .eq('user_id', uid)
          .order('updated_at');
      final remote = (rows as List)
          .map((e) => TodoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final map = <String, TodoItem>{
        for (final item in _items) item.id: item,
      };
      for (final r in remote) {
        final local = map[r.id];
        if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
          map[r.id] = r;
        }
      }
      _items
        ..clear()
        ..addAll(map.values);
      await _persist();
      _error = null;
    } catch (e) {
      if (!silent) {
        _error = '同步拉取失败：$e';
      }
    } finally {
      if (!silent) {
        _syncing = false;
      }
      notifyListeners();
    }
  }

  Future<void> pushItem(TodoItem item) async {
    if (!await _online()) return;
    try {
      await _client.rpc('upsert_todo', params: item.toUpsertParams());
    } catch (e) {
      debugPrint('pushItem failed: $e');
      try {
        await _client.from('todos').upsert(item.toJson());
      } catch (e2) {
        debugPrint('upsert fallback failed: $e2');
      }
    }
  }

  Future<void> pushAllDirty({bool silent = false}) async {
    if (_userId == null || !await _online()) return;
    if (!silent) {
      _syncing = true;
      notifyListeners();
    }
    try {
      for (final item in List<TodoItem>.from(_items)) {
        await pushItem(item);
      }
    } finally {
      if (!silent) {
        _syncing = false;
        notifyListeners();
      }
    }
  }

  Future<TodoItem> addTodo({
    required String title,
    String content = '',
    DateTime? remindAt,
    RecurrenceType recurrence = RecurrenceType.none,
    List<int> weekdays = const [],
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('未登录');
    final item = TodoItem.create(
      userId: uid,
      title: title,
      content: content,
      remindAt: remindAt,
      recurrence: recurrence,
      weekdays: weekdays,
    );
    _upsertLocal(item);
    await _persist();
    notifyListeners();
    unawaited(pushItem(item));
    return item;
  }

  Future<void> updateTodo(TodoItem item) async {
    final stamped = item.copyWith(updatedAt: DateTime.now().toUtc());
    _upsertLocal(stamped);
    await _persist();
    notifyListeners();
    unawaited(pushItem(stamped));
  }

  /// 循环待办完成：留下本次已完成快照，原系列推进到下一周期。
  Future<void> completeTodo(TodoItem item) async {
    if (item.isRecurring) {
      final now = DateTime.now().toUtc();
      final snapshot = TodoItem.create(
        userId: item.userId,
        title: item.title,
        content: item.content,
        remindAt: item.remindAt,
        recurrence: RecurrenceType.none,
        weekdays: const [],
        completed: true,
        seriesId: item.id,
      );
      final next = advanceRecurrence(item, clock);
      final series = item.copyWith(
        remindAt: next,
        completed: false,
        updatedAt: now,
      );
      _upsertLocal(snapshot);
      _upsertLocal(series);
      await _persist();
      notifyListeners();
      unawaited(pushItem(snapshot));
      unawaited(pushItem(series));
      return;
    }
    await updateTodo(
      item.copyWith(completed: true, updatedAt: DateTime.now().toUtc()),
    );
  }

  /// 取消完成只作用于该条（含循环快照），不会改回系列。
  Future<void> uncompleteTodo(TodoItem item) async {
    await updateTodo(
      item.copyWith(completed: false, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> snoozeTodo(
    TodoItem item, {
    Duration by = const Duration(minutes: 10),
  }) async {
    final now = clock.now();
    final base = item.remindAt != null ? clock.fromUtc(item.remindAt!) : now;
    final origin = base.isAfter(now) ? base : now;
    final next = origin.add(by);
    await updateTodo(
      item.copyWith(remindAt: clock.toUtc(next), updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> softDelete(TodoItem item) async {
    await updateTodo(
      item.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> restore(TodoItem item) async {
    await updateTodo(
      item.copyWith(
        clearDeletedAt: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  TodoItem? findById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 到期提醒候选：remind_at 在 [now-1min, now+1min]，且未完成、未删除。不提前、不补弹由调用方过滤。
  List<TodoItem> dueReminders(DateTime nowUtc, {Set<String> alreadyShown = const {}}) {
    final start = nowUtc.subtract(const Duration(minutes: 1));
    final end = nowUtc.add(const Duration(minutes: 1));
    return _items.where((item) {
      if (item.isDeleted) return false;
      if (item.completed && !item.isRecurring) return false;
      final at = item.remindAt;
      if (at == null) return false;
      if (alreadyShown.contains(item.id)) return false;
      return !at.isBefore(start) && !at.isAfter(end);
    }).toList();
  }

  List<TodoItem> upcomingReminders({int days = 14}) {
    final now = DateTime.now().toUtc();
    final end = now.add(Duration(days: days));
    final list = _items.where((item) {
      if (item.isDeleted) return false;
      if (item.completed && !item.isRecurring) return false;
      final at = item.remindAt;
      if (at == null) return false;
      return !at.isBefore(now) && !at.isAfter(end);
    }).toList();
    list.sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
    return list;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
