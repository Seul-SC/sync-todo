import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note_item.dart';
import '../models/todo_item.dart';
import '../services/app_clock.dart';
import '../services/note_repository.dart';
import '../services/todo_repository.dart';
import 'link_todo_dialog.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.note,
    required this.notes,
    required this.todos,
    required this.clock,
    this.onDeleted,
    this.compact = false,
  });

  final NoteItem note;
  final NoteRepository notes;
  final TodoRepository todos;
  final AppClock clock;
  final VoidCallback? onDeleted;
  final bool compact;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _title;
  late TextEditingController _content;
  Timer? _debounce;
  late String _noteId;

  @override
  void initState() {
    super.initState();
    _noteId = widget.note.id;
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
    _title.addListener(_scheduleSave);
    _content.addListener(_scheduleSave);
  }

  @override
  void didUpdateWidget(covariant NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _debounce?.cancel();
      _title.text = widget.note.title;
      _content.text = widget.note.content;
      _noteId = widget.note.id;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flushSave();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flushSave);
  }

  void _flushSave() {
    final current = widget.notes.findNote(_noteId);
    if (current == null || current.isDeleted) return;
    if (current.title == _title.text && current.content == _content.text) {
      return;
    }
    unawaited(widget.notes.updateNote(
      current.copyWith(title: _title.text, content: _content.text),
    ));
  }

  Future<void> _addLink() async {
    final linked = widget.notes.todoIdsForNote(_noteId).toSet();
    final picked = await showLinkTodoDialog(
      context,
      todos: widget.todos,
      clock: widget.clock,
      alreadyLinked: linked,
    );
    if (picked != null) {
      await widget.notes.linkNoteTodo(_noteId, picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.notes, widget.todos]),
      builder: (context, _) {
        final latest = widget.notes.findNote(_noteId);
        if (latest == null || latest.isDeleted) {
          return const Center(child: Text('笔记不存在或已删除'));
        }
        final linkedIds = widget.notes.todoIdsForNote(_noteId);
        final linkedTodos = linkedIds
            .map(widget.todos.findById)
            .whereType<TodoItem>()
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        hintText: '笔记标题',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      _debounce?.cancel();
                      await widget.notes.softDeleteNote(latest);
                      widget.onDeleted?.call();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _content,
                  decoration: const InputDecoration(
                    hintText: '开始写笔记…',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '关联待办',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addLink,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('关联'),
                      ),
                    ],
                  ),
                  if (linkedTodos.isEmpty)
                    Text(
                      '还没有关联待办',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final todo in linkedTodos)
                          InputChip(
                            label: Text(todo.title),
                            onDeleted: () =>
                                widget.notes.unlinkNoteTodo(_noteId, todo.id),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
