import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../models/note_todo_link.dart';
import 'local_store.dart';

class NoteRepository extends ChangeNotifier {
  NoteRepository({
    required LocalStore store,
    required SupabaseClient client,
  })  : _store = store,
        _client = client;

  final LocalStore _store;
  final SupabaseClient _client;

  final List<NoteItem> _notes = [];
  final List<FolderItem> _folders = [];
  final List<NoteTodoLink> _links = [];

  bool _loading = false;
  bool _syncing = false;
  String? _error;
  String? _userId;

  List<NoteItem> get notes => List.unmodifiable(_notes);
  List<FolderItem> get folders => List.unmodifiable(_folders);
  List<NoteTodoLink> get links => List.unmodifiable(_links);
  bool get loading => _loading;
  bool get syncing => _syncing;
  String? get error => _error;

  List<NoteItem> get activeNotes =>
      _notes.where((e) => !e.isDeleted).toList();

  List<FolderItem> get activeFolders =>
      _folders.where((e) => !e.isDeleted).toList();

  List<NoteItem> get trashNotes => _notes.where((e) => e.isDeleted).toList();

  List<FolderItem> get trashFolders =>
      _folders.where((e) => e.isDeleted).toList();

  Future<void> bindUser(
    String userId, {
    List<NoteItem>? notes,
    List<FolderItem>? folders,
    List<NoteTodoLink>? links,
  }) async {
    _userId = userId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _notes
        ..clear()
        ..addAll(notes ?? []);
      _folders
        ..clear()
        ..addAll(folders ?? []);
      _links
        ..clear()
        ..addAll(links ?? []);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> unbind() async {
    _userId = null;
    _notes.clear();
    _folders.clear();
    _links.clear();
    notifyListeners();
  }

  Future<bool> _online() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((e) => e != ConnectivityResult.none);
  }

  Future<void> _persistNotes() async {
    final uid = _userId;
    if (uid == null) return;
    await _store.saveNotes(uid, _notes);
  }

  Future<void> _persistFolders() async {
    final uid = _userId;
    if (uid == null) return;
    await _store.saveFolders(uid, _folders);
  }

  Future<void> _persistLinks() async {
    final uid = _userId;
    if (uid == null) return;
    await _store.saveLinks(uid, _links);
  }

  void _upsertNoteLocal(NoteItem item) {
    final index = _notes.indexWhere((e) => e.id == item.id);
    if (index < 0) {
      _notes.add(item);
    } else if (!item.updatedAt.isBefore(_notes[index].updatedAt)) {
      _notes[index] = item;
    }
  }

  void _upsertFolderLocal(FolderItem item) {
    final index = _folders.indexWhere((e) => e.id == item.id);
    if (index < 0) {
      _folders.add(item);
    } else if (!item.updatedAt.isBefore(_folders[index].updatedAt)) {
      _folders[index] = item;
    }
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
      await Future.wait([
        _pullFolders(uid),
        _pullNotes(uid),
        _pullLinks(uid),
      ]);
      await _persistFolders();
      await _persistNotes();
      await _persistLinks();
      _error = null;
    } catch (e) {
      if (!silent) _error = '同步笔记失败：$e';
    } finally {
      if (!silent) _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pullFolders(String uid) async {
    final rows = await _client.from('folders').select().eq('user_id', uid);
    final remote = (rows as List)
        .map((e) => FolderItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final map = {for (final item in _folders) item.id: item};
    for (final r in remote) {
      final local = map[r.id];
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        map[r.id] = r;
      }
    }
    _folders
      ..clear()
      ..addAll(map.values);
  }

  Future<void> _pullNotes(String uid) async {
    final rows = await _client.from('notes').select().eq('user_id', uid);
    final remote = (rows as List)
        .map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final map = {for (final item in _notes) item.id: item};
    for (final r in remote) {
      final local = map[r.id];
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        map[r.id] = r;
      }
    }
    _notes
      ..clear()
      ..addAll(map.values);
  }

  Future<void> _pullLinks(String uid) async {
    final rows =
        await _client.from('note_todo_links').select().eq('user_id', uid);
    final remote = (rows as List)
        .map((e) => NoteTodoLink.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    // 链接无 LWW 时间戳冲突：以远端为准，并并入本地尚未推送的
    final keys = {for (final l in remote) '${l.noteId}|${l.todoId}'};
    final merged = [...remote];
    for (final local in _links) {
      final key = '${local.noteId}|${local.todoId}';
      if (!keys.contains(key)) {
        merged.add(local);
      }
    }
    // 上面会把已在远端删除的本地链接加回来。离线新建的链接没有 deleted 标记。
    // 采用：拉取时若在线，以远端集合为准；离线新建的会在 push 时上去。
    // 为避免刚删的链接被拉回，pushAll 先推删除。这里直接用远端覆盖，
    // 并把「本地有、远端无」且 createdAt 很新（10 分钟内）的保留（离线新建）。
    final now = DateTime.now().toUtc();
    final keptLocal = _links.where((local) {
      final key = '${local.noteId}|${local.todoId}';
      if (keys.contains(key)) return false;
      return now.difference(local.createdAt).inMinutes.abs() <= 30;
    });
    _links
      ..clear()
      ..addAll(remote)
      ..addAll(keptLocal);
  }

  Future<void> pushFolder(FolderItem item) async {
    if (!await _online()) return;
    try {
      await _client.rpc('upsert_folder', params: item.toUpsertParams());
    } catch (e) {
      debugPrint('pushFolder failed: $e');
      try {
        await _client.from('folders').upsert(item.toJson());
      } catch (e2) {
        debugPrint('upsert folder fallback failed: $e2');
      }
    }
  }

  Future<void> pushNote(NoteItem item) async {
    if (!await _online()) return;
    try {
      await _client.rpc('upsert_note', params: item.toUpsertParams());
    } catch (e) {
      debugPrint('pushNote failed: $e');
      try {
        await _client.from('notes').upsert(item.toJson());
      } catch (e2) {
        debugPrint('upsert note fallback failed: $e2');
      }
    }
  }

  Future<void> _pushLink(NoteTodoLink link) async {
    if (!await _online()) return;
    try {
      await _client.from('note_todo_links').upsert(link.toJson());
    } catch (e) {
      debugPrint('push link failed: $e');
    }
  }

  Future<void> pushAllDirty({bool silent = false}) async {
    if (_userId == null || !await _online()) return;
    if (!silent) {
      _syncing = true;
      notifyListeners();
    }
    try {
      for (final f in List<FolderItem>.from(_folders)) {
        await pushFolder(f);
      }
      for (final n in List<NoteItem>.from(_notes)) {
        await pushNote(n);
      }
      await _reconcileLinks();
    } finally {
      if (!silent) {
        _syncing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reconcileLinks() async {
    if (_userId == null || !await _online()) return;
    for (final l in List<NoteTodoLink>.from(_links)) {
      await _pushLink(l);
    }
  }

  Future<FolderItem> addFolder({required String name, String? parentId}) async {
    final uid = _userId;
    if (uid == null) throw StateError('未登录');
    final item = FolderItem.create(userId: uid, name: name, parentId: parentId);
    _upsertFolderLocal(item);
    await _persistFolders();
    notifyListeners();
    unawaited(pushFolder(item));
    return item;
  }

  Future<void> renameFolder(FolderItem folder, String name) async {
    final stamped = folder.copyWith(
      name: name.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    _upsertFolderLocal(stamped);
    await _persistFolders();
    notifyListeners();
    unawaited(pushFolder(stamped));
  }

  Set<String> descendantFolderIds(String folderId, {bool includeSelf = true}) {
    final ids = <String>{};
    if (includeSelf) ids.add(folderId);
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in _folders) {
        if (f.parentId != null &&
            ids.contains(f.parentId) &&
            ids.add(f.id)) {
          changed = true;
        }
      }
    }
    return ids;
  }

  Future<void> softDeleteFolder(FolderItem folder) async {
    final now = DateTime.now().toUtc();
    final ids = descendantFolderIds(folder.id);
    for (final f in List<FolderItem>.from(_folders)) {
      if (ids.contains(f.id) && !f.isDeleted) {
        _upsertFolderLocal(
          f.copyWith(deletedAt: now, updatedAt: now),
        );
      }
    }
    for (final n in List<NoteItem>.from(_notes)) {
      if (n.folderId != null && ids.contains(n.folderId) && !n.isDeleted) {
        _upsertNoteLocal(n.copyWith(deletedAt: now, updatedAt: now));
      }
    }
    await _persistFolders();
    await _persistNotes();
    notifyListeners();
    unawaited(pushAllDirty(silent: true));
  }

  Future<void> restoreFolder(FolderItem folder) async {
    final now = DateTime.now().toUtc();
    final ids = descendantFolderIds(folder.id);
    for (final f in List<FolderItem>.from(_folders)) {
      if (ids.contains(f.id) && f.isDeleted) {
        _upsertFolderLocal(
          f.copyWith(clearDeletedAt: true, updatedAt: now),
        );
      }
    }
    for (final n in List<NoteItem>.from(_notes)) {
      if (n.folderId != null && ids.contains(n.folderId) && n.isDeleted) {
        _upsertNoteLocal(
          n.copyWith(clearDeletedAt: true, updatedAt: now),
        );
      }
    }
    await _persistFolders();
    await _persistNotes();
    notifyListeners();
    unawaited(pushAllDirty(silent: true));
  }

  Future<NoteItem> addNote({
    String title = '无标题',
    String content = '',
    String? folderId,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('未登录');
    final item = NoteItem.create(
      userId: uid,
      title: title,
      content: content,
      folderId: folderId,
    );
    _upsertNoteLocal(item);
    await _persistNotes();
    notifyListeners();
    unawaited(pushNote(item));
    return item;
  }

  Future<void> updateNote(NoteItem item) async {
    final stamped = item.copyWith(updatedAt: DateTime.now().toUtc());
    _upsertNoteLocal(stamped);
    await _persistNotes();
    notifyListeners();
    unawaited(pushNote(stamped));
  }

  Future<void> softDeleteNote(NoteItem note) async {
    await updateNote(
      note.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> restoreNote(NoteItem note) async {
    await updateNote(
      note.copyWith(
        clearDeletedAt: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> linkNoteTodo(String noteId, String todoId) async {
    final uid = _userId;
    if (uid == null) return;
    final exists = _links.any((l) => l.noteId == noteId && l.todoId == todoId);
    if (exists) return;
    final link = NoteTodoLink(
      noteId: noteId,
      todoId: todoId,
      userId: uid,
      createdAt: DateTime.now().toUtc(),
    );
    _links.add(link);
    await _persistLinks();
    notifyListeners();
    unawaited(_pushLink(link));
  }

  Future<void> unlinkNoteTodo(String noteId, String todoId) async {
    _links.removeWhere((l) => l.noteId == noteId && l.todoId == todoId);
    await _persistLinks();
    notifyListeners();
    final uid = _userId;
    if (uid == null || !await _online()) return;
    try {
      await _client
          .from('note_todo_links')
          .delete()
          .eq('note_id', noteId)
          .eq('todo_id', todoId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('unlink failed: $e');
    }
  }

  List<String> todoIdsForNote(String noteId) => _links
      .where((l) => l.noteId == noteId)
      .map((l) => l.todoId)
      .toList();

  List<String> noteIdsForTodo(String todoId) => _links
      .where((l) => l.todoId == todoId)
      .map((l) => l.noteId)
      .toList();

  NoteItem? findNote(String id) {
    try {
      return _notes.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  FolderItem? findFolder(String id) {
    try {
      return _folders.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<FolderItem> childrenOf(String? parentId) {
    return activeFolders
        .where((f) => f.parentId == parentId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<NoteItem> notesInFolder(String? folderId) {
    return activeNotes
        .where((n) => n.folderId == folderId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  void dispose() {
    super.dispose();
  }
}
