import 'package:flutter/material.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../services/desktop_shell.dart';
import '../services/note_repository.dart';
import '../services/reminder_controller.dart';
import '../services/settings_service.dart';
import '../services/sync_coordinator.dart';
import '../services/todo_repository.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/note_editor.dart';
import 'settings_page.dart';
import 'todo_list_pane.dart';
import 'trash_screen.dart';

/// 左侧栏常驻：待办、笔记文件夹树、回收站、设置。右边显示对应内容。
class WindowsShell extends StatefulWidget {
  const WindowsShell({
    super.key,
    required this.todos,
    required this.notes,
    required this.settings,
    required this.updates,
    required this.sync,
    this.desktop,
    this.reminder,
    required this.onSignOut,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final SettingsService settings;
  final UpdateService updates;
  final SyncCoordinator sync;
  final DesktopShell? desktop;
  final ReminderController? reminder;
  final Future<void> Function() onSignOut;

  @override
  State<WindowsShell> createState() => _WindowsShellState();
}

enum _WinKind { todos, folder, unfiled, note, trash, settings }

class _WindowsShellState extends State<WindowsShell> {
  _WinKind _kind = _WinKind.todos;
  String? _folderId;
  String? _noteId;
  final Set<String> _expanded = {};
  final _todoHost = GlobalKey<TodoListPaneHostState>();

  String get _title {
    switch (_kind) {
      case _WinKind.todos:
        return '待办';
      case _WinKind.unfiled:
        return '未分类';
      case _WinKind.trash:
        return '回收站';
      case _WinKind.settings:
        return '设置';
      case _WinKind.folder:
        return widget.notes.findFolder(_folderId ?? '')?.name ?? '文件夹';
      case _WinKind.note:
        final note = widget.notes.findNote(_noteId ?? '');
        final title = note?.title.trim() ?? '';
        return title.isEmpty ? '笔记' : title;
    }
  }

  void _selectTodos() => setState(() {
        _kind = _WinKind.todos;
        _folderId = null;
        _noteId = null;
      });

  void _selectTrash() => setState(() {
        _kind = _WinKind.trash;
        _folderId = null;
        _noteId = null;
      });

  void _selectSettings() => setState(() {
        _kind = _WinKind.settings;
        _folderId = null;
        _noteId = null;
      });

  void _selectFolder(String? id) => setState(() {
        _kind = id == null ? _WinKind.unfiled : _WinKind.folder;
        _folderId = id;
        _noteId = null;
        if (id != null) _expanded.add(id);
      });

  void _selectNote(NoteItem note) => setState(() {
        _kind = _WinKind.note;
        _noteId = note.id;
        _folderId = note.folderId;
        if (note.folderId != null) _expanded.add(note.folderId!);
      });

  Future<void> _newFolder({String? parentId}) async {
    final name = await _prompt(context, title: '新建文件夹', hint: '文件夹名称');
    if (name == null || name.trim().isEmpty) return;
    final folder =
        await widget.notes.addFolder(name: name.trim(), parentId: parentId);
    setState(() {
      _expanded.add(folder.id);
      if (parentId != null) _expanded.add(parentId);
    });
    _selectFolder(folder.id);
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
    setState(() {});
  }

  Future<void> _newNote({String? folderId}) async {
    final note = await widget.notes.addNote(title: '无标题', folderId: folderId);
    _selectNote(note);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sidebar = AppThemes.sidebarOf(theme);

    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: sidebar,
              border: Border(
                right: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 18, 16, 10),
                    child: Text(
                      '同步待办',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _navRow(
                    icon: Icons.check_circle_outline,
                    label: '待办',
                    selected: _kind == _WinKind.todos,
                    onTap: _selectTodos,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 4, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '笔记',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '新建文件夹',
                          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                          onPressed: () => _newFolder(),
                        ),
                        IconButton(
                          tooltip: '新建笔记',
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          onPressed: () => _newNote(folderId: _folderId),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.notes,
                      builder: (context, _) => _buildTree(),
                    ),
                  ),
                  const Divider(height: 1),
                  _navRow(
                    icon: Icons.delete_outline,
                    label: '回收站',
                    selected: _kind == _WinKind.trash,
                    onTap: _selectTrash,
                  ),
                  _navRow(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    selected: _kind == _WinKind.settings,
                    onTap: _selectSettings,
                  ),
                  AnimatedBuilder(
                    animation: widget.todos,
                    builder: (context, _) {
                      if (!widget.todos.syncing) {
                        return const SizedBox(height: 8);
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(
                          _title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '刷新',
                          onPressed: () => widget.sync.refresh(),
                          icon: const Icon(Icons.refresh),
                        ),
                        if (_kind == _WinKind.todos)
                          FilledButton.icon(
                            onPressed: () => _todoHost.currentState?.addNew(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        if (_kind == _WinKind.folder || _kind == _WinKind.unfiled)
                          FilledButton.icon(
                            onPressed: () => _newNote(folderId: _folderId),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('新建笔记'),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildRight()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTree() {
    final roots = widget.notes.childrenOf(null);
    final unfiled = widget.notes.notesInFolder(null);
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        ...roots.map(_folderNode),
        _navRow(
          icon: Icons.inbox_outlined,
          label: '未分类',
          selected: _kind == _WinKind.unfiled,
          onTap: () => _selectFolder(null),
          indent: 8,
        ),
        if (_expanded.contains('__unfiled__') || _kind == _WinKind.unfiled)
          ...unfiled.map(_noteNode),
        if (roots.isEmpty && unfiled.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Text('还没有笔记或文件夹', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _folderNode(FolderItem folder, {int depth = 0}) {
    final expanded = _expanded.contains(folder.id);
    final selected = _kind == _WinKind.folder && _folderId == folder.id;
    final children = widget.notes.childrenOf(folder.id);
    final notes = widget.notes.notesInFolder(folder.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.0 + depth * 12),
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _selectFolder(folder.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        if (expanded) {
                          _expanded.remove(folder.id);
                        } else {
                          _expanded.add(folder.id);
                        }
                      }),
                      child: Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                      ),
                    ),
                    const Icon(Icons.folder_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        folder.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
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
                            if (_folderId == folder.id) _selectTodos();
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
          ),
        ),
        if (expanded) ...[
          ...children.map((c) => _folderNode(c, depth: depth + 1)),
          ...notes.map((n) => _noteNode(n, depth: depth + 1)),
        ],
      ],
    );
  }

  Widget _noteNode(NoteItem note, {int depth = 0}) {
    final selected = _kind == _WinKind.note && _noteId == note.id;
    return Padding(
      padding: EdgeInsets.only(left: 20.0 + depth * 12),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _selectNote(note),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.notes_outlined, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.title.trim().isEmpty ? '无标题' : note.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    double indent = 8,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 2, 8, 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRight() {
    switch (_kind) {
      case _WinKind.todos:
        return TodoListPaneHost(
          key: _todoHost,
          todos: widget.todos,
          notes: widget.notes,
          settings: widget.settings,
          dense: true,
          onRefresh: widget.sync.refresh,
        );
      case _WinKind.trash:
        return TrashScreen(
          todos: widget.todos,
          notes: widget.notes,
          clock: widget.settings.clock,
          embedded: true,
        );
      case _WinKind.settings:
        return SettingsPage(
          settings: widget.settings,
          updates: widget.updates,
          todos: widget.todos,
          desktop: widget.desktop,
          reminder: widget.reminder,
          onSignOut: widget.onSignOut,
          embedded: true,
        );
      case _WinKind.note:
        final note = widget.notes.findNote(_noteId ?? '');
        if (note == null || note.isDeleted) {
          return const Center(child: Text('选择或新建一篇笔记'));
        }
        return NoteEditor(
          key: ValueKey(note.id),
          note: note,
          notes: widget.notes,
          todos: widget.todos,
          clock: widget.settings.clock,
          onDeleted: () => _selectFolder(note.folderId),
        );
      case _WinKind.folder:
      case _WinKind.unfiled:
        return _FolderNotesList(
          notes: widget.notes,
          folderId: _folderId,
          clockLabel: (n) => widget.settings.clock.format(n.updatedAt),
          onOpen: _selectNote,
          onAdd: () => _newNote(folderId: _folderId),
        );
    }
  }
}

class _FolderNotesList extends StatelessWidget {
  const _FolderNotesList({
    required this.notes,
    required this.folderId,
    required this.clockLabel,
    required this.onOpen,
    required this.onAdd,
  });

  final NoteRepository notes;
  final String? folderId;
  final String Function(NoteItem) clockLabel;
  final ValueChanged<NoteItem> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notes,
      builder: (context, _) {
        final items = notes.notesInFolder(folderId);
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '这个文件夹还是空的',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('新建笔记'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final note = items[index];
            return ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: Text(note.title.trim().isEmpty ? '无标题' : note.title),
              subtitle: Text(
                [
                  if (note.preview.isNotEmpty) note.preview,
                  clockLabel(note),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onOpen(note),
            );
          },
        );
      },
    );
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
