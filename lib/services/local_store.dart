import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../models/note_todo_link.dart';
import '../models/todo_item.dart';

class LocalCache {
  LocalCache({
    required this.todos,
    required this.notes,
    required this.folders,
    required this.links,
  });

  final List<TodoItem> todos;
  final List<NoteItem> notes;
  final List<FolderItem> folders;
  final List<NoteTodoLink> links;
}

/// 把缓存解析失败当作缓存未命中，让云端同步有机会修复它。
dynamic decodeLocalCacheJson(String raw, dynamic fallback) {
  try {
    if (raw.trim().isEmpty) return fallback;
    return jsonDecode(raw);
  } on FormatException {
    return fallback;
  }
}

class LocalStore {
  Future<Directory> _dir() async => getApplicationSupportDirectory();

  Future<File> _file(String name) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<dynamic> _readJson(String name, dynamic fallback) async {
    try {
      final file = await _file(name);
      if (!await file.exists()) return fallback;
      final raw = await file.readAsString();
      return decodeLocalCacheJson(raw, fallback);
    } catch (e) {
      debugPrint('read local cache $name failed: $e');
      return fallback;
    }
  }

  Future<void> _writeJson(String name, dynamic value) async {
    final file = await _file(name);
    await file.parent.create(recursive: true);
    // 先完整写入临时文件再替换，避免中途退出留下半个 JSON 文件。
    final temp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsString(jsonEncode(value), flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<LocalCache> loadAll(String userId) async {
    final todos = await _loadTodos(userId);
    final notesRaw = await _readJson('notes_$userId.json', []);
    final foldersRaw = await _readJson('folders_$userId.json', []);
    final linksRaw = await _readJson('links_$userId.json', []);
    return LocalCache(
      todos: todos,
      notes: _asList(notesRaw)
          .map((e) => NoteItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      folders: _asList(foldersRaw)
          .map((e) => FolderItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      links: _asList(linksRaw)
          .map((e) => NoteTodoLink.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<List<TodoItem>> _loadTodos(String userId) async {
    final raw = await _readJson('todos_$userId.json', null);
    if (raw == null) return [];
    // 兼容旧版：文件本身就是待办数组
    final list = raw is List ? raw : (raw is Map && raw['todos'] is List ? raw['todos'] : []);
    return _asList(list)
        .map((e) => TodoItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveTodos(String userId, List<TodoItem> items) async {
    await _writeJson('todos_$userId.json', items.map((e) => e.toJson()).toList());
  }

  Future<void> saveNotes(String userId, List<NoteItem> items) async {
    await _writeJson('notes_$userId.json', items.map((e) => e.toJson()).toList());
  }

  Future<void> saveFolders(String userId, List<FolderItem> items) async {
    await _writeJson('folders_$userId.json', items.map((e) => e.toJson()).toList());
  }

  Future<void> saveLinks(String userId, List<NoteTodoLink> items) async {
    await _writeJson('links_$userId.json', items.map((e) => e.toJson()).toList());
  }

  List<dynamic> _asList(dynamic raw) {
    if (raw is List) return raw;
    return const [];
  }
}
