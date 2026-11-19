import 'package:flutter/material.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../models/todo_item.dart';
import '../services/app_clock.dart';
import '../services/note_repository.dart';
import '../services/todo_repository.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({
    super.key,
    required this.todos,
    required this.notes,
    required this.clock,
    this.embedded = false,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final AppClock clock;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([todos, notes]),
      builder: (context, _) {
        final todoItems = todos.trashItems
          ..sort((a, b) => (b.deletedAt ?? b.updatedAt)
              .compareTo(a.deletedAt ?? a.updatedAt));
        final noteItems = notes.trashNotes
          ..sort((a, b) => (b.deletedAt ?? b.updatedAt)
              .compareTo(a.deletedAt ?? a.updatedAt));
        final folderItems = notes.trashFolders
          ..sort((a, b) => (b.deletedAt ?? b.updatedAt)
              .compareTo(a.deletedAt ?? a.updatedAt));

        final empty = todoItems.isEmpty && noteItems.isEmpty && folderItems.isEmpty;
        final body = empty
            ? const Center(child: Text('回收站是空的'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (folderItems.isNotEmpty) ...[
                    _header(context, '文件夹'),
                    ...folderItems.map((f) => _folderTile(context, f)),
                  ],
                  if (noteItems.isNotEmpty) ...[
                    _header(context, '笔记'),
                    ...noteItems.map((n) => _noteTile(context, n)),
                  ],
                  if (todoItems.isNotEmpty) ...[
                    _header(context, '待办'),
                    ...todoItems.map((t) => _todoTile(context, t)),
                  ],
                ],
              );

        if (embedded) return body;
        return Scaffold(
          appBar: AppBar(title: const Text('回收站')),
          body: body,
        );
      },
    );
  }

  Widget _header(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _todoTile(BuildContext context, TodoItem item) {
    final when = item.deletedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.check_box_outlined),
        title: Text(item.title),
        subtitle: when == null
            ? null
            : Text('删除于 ${clock.format(when)}'),
        trailing: TextButton(
          onPressed: () => todos.restore(item),
          child: const Text('恢复'),
        ),
      ),
    );
  }

  Widget _noteTile(BuildContext context, NoteItem item) {
    final when = item.deletedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.notes_outlined),
        title: Text(item.title.isEmpty ? '无标题' : item.title),
        subtitle: when == null ? null : Text('删除于 ${clock.format(when)}'),
        trailing: TextButton(
          onPressed: () => notes.restoreNote(item),
          child: const Text('恢复'),
        ),
      ),
    );
  }

  Widget _folderTile(BuildContext context, FolderItem item) {
    final when = item.deletedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(item.name),
        subtitle: Text(
          [
            if (when != null) '删除于 ${clock.format(when)}',
            '恢复时将同时恢复其中的子文件夹和笔记',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => notes.restoreFolder(item),
          child: const Text('恢复'),
        ),
      ),
    );
  }
}
