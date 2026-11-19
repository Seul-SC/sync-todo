import 'package:flutter/material.dart';

import '../models/folder_item.dart';
import '../models/note_item.dart';
import '../services/note_repository.dart';
import '../services/settings_service.dart';
import '../services/todo_repository.dart';
import '../widgets/note_editor.dart';

/// 安卓笔记：文件夹是单独一页简单列表，点进去再是笔记列表；可看、可改、可新建。
/// 不要做成电脑那样的左侧树。
class NotesPageAndroid extends StatefulWidget {
  const NotesPageAndroid({
    super.key,
    required this.notes,
    required this.todos,
    required this.settings,
    this.onScopeChanged,
  });

  final NoteRepository notes;
  final TodoRepository todos;
  final SettingsService settings;
  final VoidCallback? onScopeChanged;

  @override
  State<NotesPageAndroid> createState() => NotesPageAndroidState();
}

class NotesPageAndroidState extends State<NotesPageAndroid> {
  /// null 表示文件夹列表首页；'' 表示未分类；其它为文件夹 id。
  String? _openFolderId;
  bool get isAtRoot => _openFolderId == null;

  String get title {
    if (_openFolderId == null) return '笔记';
    if (_openFolderId == '') return '未分类';
    return widget.notes.findFolder(_openFolderId!)?.name ?? '笔记';
  }

  bool handleBack() {
    if (isAtRoot) return false;
    setState(() => _openFolderId = null);
    widget.onScopeChanged?.call();
    return true;
  }

  Future<void> addNew() async {
    if (isAtRoot) {
      await _newNote(folderId: null);
      return;
    }
    await _newNote(folderId: _openFolderId == '' ? null : _openFolderId);
  }

  void _openFolder(String? folderId) {
    setState(() => _openFolderId = folderId ?? '');
    widget.onScopeChanged?.call();
  }

  Future<void> _openEditor(NoteItem note) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('编辑笔记')),
          body: NoteEditor(
            note: note,
            notes: widget.notes,
            todos: widget.todos,
            clock: widget.settings.clock,
            compact: true,
            onDeleted: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  Future<void> _newNote({String? folderId}) async {
    final note = await widget.notes.addNote(title: '无标题', folderId: folderId);
    if (!mounted) return;
    await _openEditor(note);
  }

  Future<void> _newFolder() async {
    final name = await _prompt(context, title: '新建文件夹', hint: '文件夹名称');
    if (name == null || name.trim().isEmpty) return;
    final folder = await widget.notes.addFolder(name: name.trim());
    _openFolder(folder.id);
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.notes,
      builder: (context, _) {
        return Stack(
          children: [
            isAtRoot ? _folderList(context) : _noteList(context),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isAtRoot)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'new-folder',
                        tooltip: '新建文件夹',
                        onPressed: _newFolder,
                        child: const Icon(Icons.create_new_folder_outlined),
                      ),
                    ),
                  FloatingActionButton(
                    heroTag: 'new-note',
                    tooltip: '新建笔记',
                    onPressed: addNew,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _folderList(BuildContext context) {
    final folders = widget.notes.activeFolders
      ..sort((a, b) => a.name.compareTo(b.name));
    final unfiled = widget.notes.notesInFolder(null);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    if (folders.isEmpty && unfiled.isEmpty) {
      return const Center(child: Text('还没有笔记或文件夹'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      children: [
        _row(
          icon: Icons.inbox_outlined,
          title: '未分类',
          subtitle: unfiled.isEmpty ? '还没有笔记' : '${unfiled.length} 篇',
          onTap: () => _openFolder(''),
        ),
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(
              '文件夹',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
        for (final folder in folders)
          _row(
            icon: Icons.folder_outlined,
            title: folder.name,
            subtitle: '${widget.notes.notesInFolder(folder.id).length} 篇',
            onTap: () => _openFolder(folder.id),
            onLongPress: () => _folderActions(folder),
          ),
      ],
    );
  }

  Widget _noteList(BuildContext context) {
    final folderId = _openFolderId == '' ? null : _openFolderId;
    final notes = widget.notes.notesInFolder(folderId);
    if (notes.isEmpty) {
      return const Center(child: Text('还没有笔记，点右下角添加'));
    }
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          title: Text(note.title.trim().isEmpty ? '无标题' : note.title),
          subtitle: Text(
            [
              if (note.preview.isNotEmpty) note.preview,
              widget.settings.clock.format(note.updatedAt),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted),
          ),
          onTap: () => _openEditor(note),
          onLongPress: () => widget.notes.softDeleteNote(note),
        );
      },
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Future<void> _folderActions(FolderItem folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') await _renameFolder(folder);
    if (action == 'delete') await widget.notes.softDeleteFolder(folder);
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
