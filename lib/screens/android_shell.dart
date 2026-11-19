import 'package:flutter/material.dart';

import '../services/note_repository.dart';
import '../services/reminder_controller.dart';
import '../services/settings_service.dart';
import '../services/sync_coordinator.dart';
import '../services/todo_repository.dart';
import '../services/update_service.dart';
import 'notes_page_android.dart';
import 'settings_page.dart';
import 'todo_list_pane.dart';

class AndroidShell extends StatefulWidget {
  const AndroidShell({
    super.key,
    required this.todos,
    required this.notes,
    required this.settings,
    required this.updates,
    required this.sync,
    this.reminder,
    required this.onSignOut,
  });

  final TodoRepository todos;
  final NoteRepository notes;
  final SettingsService settings;
  final UpdateService updates;
  final SyncCoordinator sync;
  final ReminderController? reminder;
  final Future<void> Function() onSignOut;

  @override
  State<AndroidShell> createState() => _AndroidShellState();
}

class _AndroidShellState extends State<AndroidShell> {
  int _index = 0;
  final _todoHost = GlobalKey<TodoListPaneHostState>();
  final _notesHost = GlobalKey<NotesPageAndroidState>();

  bool get _notesCanBack =>
      _index == 1 && _notesHost.currentState?.isAtRoot == false;

  @override
  Widget build(BuildContext context) {
    final notesTitle = _notesHost.currentState?.title ?? '笔记';
    return PopScope(
      canPop: !_notesCanBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _notesHost.currentState?.handleBack();
          setState(() {});
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _notesCanBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _notesHost.currentState?.handleBack();
                    setState(() {});
                  },
                )
              : null,
          title: _index == 0
              ? const SizedBox.shrink()
              : Text(_index == 1 ? notesTitle : '我的'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => widget.sync.refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            TodoListPaneHost(
              key: _todoHost,
              todos: widget.todos,
              notes: widget.notes,
              settings: widget.settings,
              plain: true,
              showDateHeader: true,
              onRefresh: widget.sync.refresh,
            ),
            NotesPageAndroid(
              key: _notesHost,
              notes: widget.notes,
              todos: widget.todos,
              settings: widget.settings,
              onScopeChanged: () => setState(() {}),
            ),
            SettingsPage(
              settings: widget.settings,
              updates: widget.updates,
              todos: widget.todos,
              reminder: widget.reminder,
              onSignOut: widget.onSignOut,
              embedded: true,
            ),
          ],
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                onPressed: () => _todoHost.currentState?.addNew(),
                child: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle),
              label: '待办',
            ),
            NavigationDestination(
              icon: Icon(Icons.notes_outlined),
              selectedIcon: Icon(Icons.notes),
              label: '笔记',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
