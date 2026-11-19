import 'package:uuid/uuid.dart';

import 'todo_item.dart';

class NoteItem {
  NoteItem({
    required this.id,
    required this.userId,
    this.folderId,
    required this.title,
    this.content = '',
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? folderId;
  final String title;
  final String content;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  String get preview {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    final first = trimmed.split(RegExp(r'\r?\n')).first;
    return first.length > 80 ? '${first.substring(0, 80)}…' : first;
  }

  NoteItem copyWith({
    String? folderId,
    bool clearFolderId = false,
    String? title,
    String? content,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id,
      userId: userId,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      content: content ?? this.content,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'folder_id': folderId,
        'title': title,
        'content': content,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpsertParams() => {
        'p_id': id,
        'p_folder_id': folderId,
        'p_title': title,
        'p_content': content,
        'p_deleted_at': deletedAt?.toUtc().toIso8601String(),
        'p_created_at': createdAt.toUtc().toIso8601String(),
        'p_updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      folderId: json['folder_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      deletedAt: TodoItem.parseTime(json['deleted_at']),
      createdAt: TodoItem.parseTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: TodoItem.parseTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static NoteItem create({
    required String userId,
    String title = '',
    String content = '',
    String? folderId,
  }) {
    final now = DateTime.now().toUtc();
    return NoteItem(
      id: const Uuid().v4(),
      userId: userId,
      folderId: folderId,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }
}
