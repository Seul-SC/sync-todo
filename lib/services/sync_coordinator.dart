import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'note_repository.dart';
import 'settings_service.dart';
import 'todo_repository.dart';

/// 同步模型 B：打开/刷新拉取，改动即时推送，30 秒静默后台同步，Realtime 尽快同步弹窗状态。
class SyncCoordinator {
  SyncCoordinator({
    required this.todos,
    required this.notes,
    required this.settings,
    required this.store,
    required this.client,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final SettingsService settings;
  final LocalStore store;
  final SupabaseClient client;

  Timer? _bgSync;
  RealtimeChannel? _channel;
  String? _userId;

  Future<void> bindUser(String userId) async {
    _userId = userId;
    final cache = await store.loadAll(userId);
    await todos.bindUser(userId, cached: cache.todos);
    await notes.bindUser(
      userId,
      notes: cache.notes,
      folders: cache.folders,
      links: cache.links,
    );
    await settings.bindUser(userId, client);
    await pullAll();
    _startBackgroundSync();
    _subscribeRealtime(userId);
  }

  Future<void> unbind() async {
    _stopBackgroundSync();
    await _unsubscribeRealtime();
    await todos.unbind();
    await notes.unbind();
    await settings.unbind();
    _userId = null;
  }

  Future<void> pullAll({bool silent = false}) async {
    await todos.pull(silent: silent);
    await notes.pull(silent: silent);
    await settings.pullRemote();
  }

  Future<void> pushAll({bool silent = false}) async {
    await todos.pushAllDirty(silent: silent);
    await notes.pushAllDirty(silent: silent);
  }

  Future<void> refresh() async {
    await pushAll();
    await pullAll();
  }

  void _startBackgroundSync() {
    _bgSync?.cancel();
    _bgSync = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_silentRound());
    });
  }

  Future<void> _silentRound() async {
    await pushAll(silent: true);
    await pullAll(silent: true);
  }

  void _stopBackgroundSync() {
    _bgSync?.cancel();
    _bgSync = null;
  }

  void _subscribeRealtime(String userId) {
    unawaited(_unsubscribeRealtime());
    final channel = client.channel('sync-user-$userId');
    void onChange(PostgresChangePayload _) {
      unawaited(pullAll(silent: true));
    }

    for (final table in const [
      'todos',
      'notes',
      'folders',
      'note_todo_links',
      'user_settings',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: table == 'user_settings' ? 'user_id' : 'user_id',
          value: userId,
        ),
        callback: onChange,
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _unsubscribeRealtime() async {
    final ch = _channel;
    _channel = null;
    if (ch == null) return;
    try {
      await client.removeChannel(ch);
    } catch (e) {
      debugPrint('remove realtime channel: $e');
    }
  }

  void dispose() {
    _stopBackgroundSync();
    unawaited(_unsubscribeRealtime());
  }
}
