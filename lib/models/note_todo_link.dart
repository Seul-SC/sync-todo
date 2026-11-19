import 'todo_item.dart';

class NoteTodoLink {
  NoteTodoLink({
    required this.noteId,
    required this.todoId,
    required this.userId,
    required this.createdAt,
  });

  final String noteId;
  final String todoId;
  final String userId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'note_id': noteId,
        'todo_id': todoId,
        'user_id': userId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory NoteTodoLink.fromJson(Map<String, dynamic> json) {
    return NoteTodoLink(
      noteId: json['note_id'] as String,
      todoId: json['todo_id'] as String,
      userId: json['user_id'] as String,
      createdAt: TodoItem.parseTime(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}
