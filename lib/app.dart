import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'platform/app_os.dart';
import 'screens/android_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/settings_page.dart';
import 'screens/windows_shell.dart';
import 'services/desktop_shell.dart';
import 'services/local_store.dart';
import 'services/note_repository.dart';
import 'services/reminder_controller.dart';
import 'services/settings_service.dart';
import 'services/sync_coordinator.dart';
import 'services/todo_repository.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'widgets/reminder_overlay.dart';

class SyncTodoApp extends StatefulWidget {
  const SyncTodoApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<SyncTodoApp> createState() => _SyncTodoAppState();
}

class _SyncTodoAppState extends State<SyncTodoApp> with WidgetsBindingObserver {
  late final LocalStore _store;
  late final TodoRepository _todos;
  late final NoteRepository _notes;
  late final UpdateService _updates;
  late final SyncCoordinator _sync;
  ReminderController? _reminder;
  DesktopShell? _desktop;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  bool _ready = false;
  String? _boundUserId;
  bool _guideScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    _store = LocalStore();
    _todos = TodoRepository(
      store: _store,
      client: client,
      clock: () => widget.settings.clock,
    );
    _notes = NoteRepository(store: _store, client: client);
    _updates = UpdateService(widget.settings);
    _sync = SyncCoordinator(
      todos: _todos,
      notes: _notes,
      settings: widget.settings,
      store: _store,
      client: client,
    );
    _reminder = ReminderController(
      repository: _todos,
      onNeedOverlay: () {
        if (mounted) setState(() {});
      },
    );
    if (isWindowsDesktop) {
      _desktop = createDesktopShell(
        settings: widget.settings,
        onShowWindow: () {},
        onQuit: () {},
        isReminderShowing: () => _reminder?.isShowing == true,
      );
      _desktop?.init();
    }
    _bootstrap();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _onAuth(data.session);
    });
    _updates.loadCurrent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _boundUserId != null) {
      _sync.pullAll(silent: true);
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _onAuth(Supabase.instance.client.auth.currentSession);
    } catch (e) {
      // 本地缓存或登录态恢复失败时也要结束加载，不能永远停在转圈页。
      debugPrint('bootstrap failed: $e');
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _onAuth(Session? session) async {
    final uid = session?.user.id;
    if (uid == null) {
      _reminder?.stop();
      await _sync.unbind();
      _boundUserId = null;
      if (mounted) setState(() {});
      return;
    }
    if (_boundUserId == uid) return;
    _boundUserId = uid;
    await _sync.bindUser(uid);
    _reminder?.start();
    if (mounted) setState(() {});
    _maybeShowGuide();
  }

  void _maybeShowGuide() {
    if (_guideScheduled || !isAndroidDevice) return;
    _guideScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _navKey.currentContext;
      if (ctx == null) return;
      await showAndroidPermissionGuide(
        context: ctx,
        settings: widget.settings,
      );
    });
  }

  Future<void> _signOut() async {
    _reminder?.stop();
    await _sync.unbind();
    _boundUserId = null;
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminder?.dispose();
    _desktop?.dispose();
    _sync.dispose();
    _todos.dispose();
    _notes.dispose();
    _updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        return MaterialApp(
          title: '同步待办',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppThemes.of(widget.settings.themeMode),
          navigatorKey: _navKey,
          home: !_ready
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : _buildHome(),
          builder: (context, child) {
            final reminder = _reminder;
            if (reminder == null) {
              return child ?? const SizedBox.shrink();
            }
            return AnimatedBuilder(
              animation: reminder,
              builder: (context, _) {
                final showing = reminder.isShowing && reminder.active.isNotEmpty;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    if (showing)
                      ReminderOverlayStack(
                        items: reminder.active,
                        clock: widget.settings.clock,
                        onComplete: reminder.completeItem,
                        onSnooze: reminder.snoozeItem,
                        onDismiss: reminder.dismissItem,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHome() {
    if (!AppConfig.hasValidKey &&
        Supabase.instance.client.auth.currentSession == null) {
      return const AuthScreen();
    }
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    if (isWindowsDesktop) {
      return WindowsShell(
        todos: _todos,
        notes: _notes,
        settings: widget.settings,
        updates: _updates,
        sync: _sync,
        desktop: _desktop,
        reminder: _reminder,
        onSignOut: _signOut,
      );
    }
    return AndroidShell(
      todos: _todos,
      notes: _notes,
      settings: widget.settings,
      updates: _updates,
      sync: _sync,
      reminder: _reminder,
      onSignOut: _signOut,
    );
  }
}
