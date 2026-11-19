import 'package:uuid/uuid.dart';

import 'todo_item.dart';

class FolderItem {
  FolderItem({
    required this.id,
    required this.userId,
    this.parentId,
    required this.name,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? parentId;
  final String name;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  FolderItem copyWith({
    String? parentId,
    bool clearParentId = false,
    String? name,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
  }) {
    return FolderItem(
      id: id,
      userId: userId,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'parent_id': parentId,
        'name': name,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpsertParams() => {
        'p_id': id,
        'p_parent_id': parentId,
        'p_name': name,
        'p_deleted_at': deletedAt?.toUtc().toIso8601String(),
        'p_created_at': createdAt.toUtc().toIso8601String(),
        'p_updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '',
      deletedAt: TodoItem.parseTime(json['deleted_at']),
      createdAt: TodoItem.parseTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: TodoItem.parseTime(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static FolderItem create({
    required String userId,
    required String name,
    String? parentId,
  }) {
    final now = DateTime.now().toUtc();
    return FolderItem(
      id: const Uuid().v4(),
      userId: userId,
      parentId: parentId,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }
}
