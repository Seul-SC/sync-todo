import 'package:flutter/material.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../services/note_repository.dart';
import '../services/settings_service.dart';
import '../services/todo_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/note_editor.dart';

class NotesPageWindows extends StatefulWidget {
  const NotesPageWindows({
    super.key,
    required this.notes,
    required this.todos,
    required this.settings,
  });

  final NoteRepository notes;
  final TodoRepository todos;
  final SettingsService settings;

  @override
  State<NotesPageWindows> createState() => _NotesPageWindowsState();
}

class _NotesPageWindowsState extends State<NotesPageWindows> {
  String? _selectedNoteId;
  final Set<String> _expanded = {};

  Future<void> _newFolder({String? parentId}) async {
    final name = await _prompt(context, title: '新建文件夹', hint: '文件夹名称');
    if (name == null || name.trim().isEmpty) return;
    final folder = await widget.notes.addFolder(name: name.trim(), parentId: parentId);
    setState(() => _expanded.add(folder.id));
  }

  Future<void> _renameFolder(FolderItem folder) async {
    final name = await _prompt(
      context,
      title: '重命名文件夹',
      hint: '文件夹名称',
      initial: folder.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await widget.notes.renameFolder(folder, name);
  }

  Future<void> _newNote({String? folderId}) async {
    final note = await widget.notes.addNote(title: '无标题', folderId: folderId);
    setState(() => _selectedNoteId = note.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notes,
      builder: (context, _) {
        final selected = _selectedNoteId == null
            ? null
            : widget.notes.findNote(_selectedNoteId!);
        final usable = selected != null && !selected.isDeleted;

        return Row(
          children: [
            SizedBox(
              width: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppThemes.sidebarOf(Theme.of(context)),
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '笔记',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: '新建文件夹',
                            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                            onPressed: () => _newFolder(),
                          ),
                          IconButton(
                            tooltip: '新建笔记',
                            icon: const Icon(Icons.note_add_outlined, size: 20),
                            onPressed: () => _newNote(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildTree()),
                  ],
                ),
              ),
            ),
            Expanded(
              child: usable
                  ? NoteEditor(
                      key: ValueKey(selected.id),
                      note: selected,
                      notes: widget.notes,
                      todos: widget.todos,
                      clock: widget.settings.clock,
                      onDeleted: () => setState(() => _selectedNoteId = null),
                    )
                  : const Center(child: Text('选择或新建一篇笔记')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTree() {
    final roots = widget.notes.childrenOf(null);
    final unfiled = widget.notes.notesInFolder(null);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...roots.map(_folderNode),
        if (unfiled.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('未分类', style: TextStyle(fontSize: 12)),
          ),
          ...unfiled.map(_noteNode),
        ],
        if (roots.isEmpty && unfiled.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('还没有笔记或文件夹'),
          ),
      ],
    );
  }

  Widget _folderNode(FolderItem folder) {
    final expanded = _expanded.contains(folder.id);
    final children = widget.notes.childrenOf(folder.id);
    final notes = widget.notes.notesInFolder(folder.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expanded.remove(folder.id);
            } else {
              _expanded.add(folder.id);
            }
          }),
          onSecondaryTap: () => _folderMenu(folder),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                ),
                const Icon(Icons.folder_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) {
                    switch (v) {
                      case 'note':
                        _newNote(folderId: folder.id);
                      case 'folder':
                        _newFolder(parentId: folder.id);
                      case 'rename':
                        _renameFolder(folder);
                      case 'delete':
                        widget.notes.softDeleteFolder(folder);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'note', child: Text('在此新建笔记')),
                    PopupMenuItem(value: 'folder', child: Text('新建子文件夹')),
                    PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                ...children.map(_folderNode),
                ...notes.map(_noteNode),
              ],
            ),
          ),
      ],
    );
  }

  Widget _noteNode(NoteItem note) {
    final selected = note.id == _selectedNoteId;
    return InkWell(
      onTap: () => setState(() => _selectedNoteId = note.id),
      child: Container(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : null,
        padding: const EdgeInsets.fromLTRB(28, 6, 12, 6),
        child: Row(
          children: [
            const Icon(Icons.notes_outlined, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note.title.trim().isEmpty ? '无标题' : note.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _folderMenu(FolderItem folder) async {
    await _renameFolder(folder);
  }
}

Future<String?> _prompt(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
