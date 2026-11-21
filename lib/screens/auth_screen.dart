import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/saved_credentials.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  String? _message;
  bool _remember = true;
  SavedCredentials? _saved;

  static final _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  @override
  void initState() {
    super.initState();
    _restoreSaved();
  }

  Future<void> _restoreSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = SavedCredentials(prefs);
    _saved = saved;
    setState(() => _remember = saved.remember);
    final login = await saved.load();
    if (!mounted || login == null) return;
    _email.text = login.email;
    _password.text = login.password;
    setState(() {});
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate({required bool register}) {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      return '请填写邮箱和密码';
    }
    if (email.length > 254 || !_emailPattern.hasMatch(email)) {
      return '请输入真实的邮箱地址，例如 name@example.com';
    }
    if (!register) return null;
    if (password.length < 8 || password.length > 72) {
      return '密码需要 8 到 72 位';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    if (!hasLetter || !hasDigit) {
      return '密码需要同时包含字母和数字';
    }
    if (password == email) {
      return '密码不能和邮箱相同';
    }
    if (_confirm.text != password) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!AppConfig.hasValidKey) {
      setState(() {
        _message =
            '尚未配置客户端钥匙。请打开 lib/config.dart，把 supabaseAnonKey 从占位符 REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY 换成服务器 .env 里的 ANON_KEY 或 SUPABASE_PUBLISHABLE_KEY。';
      });
      return;
    }

    final email = _email.text.trim();
    final password = _password.text;
    final error = _validate(register: _registerMode);
    if (error != null) {
      setState(() => _message = error);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      if (_registerMode) {
        await auth.signUp(email: email, password: password);
        // 服务器会自动确认邮箱，注册成功后若未自动登录再尝试登录
        if (auth.currentSession == null) {
          await auth.signInWithPassword(email: email, password: password);
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
      final saved = _saved ?? SavedCredentials(await SharedPreferences.getInstance());
      _saved = saved;
      if (_remember) {
        await saved.save(email: email, password: password);
      } else {
        await saved.clear();
        await saved.setRemember(false);
      }
    } on AuthException catch (e) {
      setState(() => _message = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _message = '无法连接服务器：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return '邮箱或密码不正确';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return '该邮箱已注册，请直接登录';
    }
    if (m.contains('password')) {
      return '密码不符合要求（至少 8 位，需同时包含字母和数字）';
    }
    return '登录失败：${e.message}';
  }

  @override
  Widget build(BuildContext context) {
    return _buildForm(context);
  }

  Widget _rememberTile() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _remember,
      onChanged: _busy
          ? null
          : (v) => setState(() => _remember = v ?? true),
      title: const Text('保存账号和密码'),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final register = _registerMode;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _SoftAuraBackground(registerMode: register, color: theme.colorScheme.primary),
          SafeArea(
            child: Center(
            child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                margin: const EdgeInsets.all(28),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                      color: register
                          ? theme.colorScheme.primary.withValues(alpha: 0.10)
                          : theme.colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: register
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Text(
                            register ? '创建新账号' : '欢迎回来',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            register
                                ? '请使用真实邮箱注册，并设置符合规则的密码。'
                                : '登录已有账号，同步你的待办和笔记。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!AppConfig.hasValidKey) ...[
                            _configWarning(theme),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: '邮箱',
                              hintText: register ? '例如 name@qq.com' : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: _hidePassword,
                            decoration: InputDecoration(
                              labelText: register ? '设置密码' : '密码',
                              helperText: register ? '至少 8 位，需同时包含字母和数字' : null,
                              suffixIcon: IconButton(
                                tooltip: _hidePassword ? '显示密码' : '隐藏密码',
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            onSubmitted: register ? null : (_) => _submit(),
                          ),
                          if (register) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirm,
                              obscureText: _hideConfirm,
                              decoration: InputDecoration(
                                labelText: '确认密码',
                                suffixIcon: IconButton(
                                  tooltip: _hideConfirm ? '显示密码' : '隐藏密码',
                                  onPressed: () => setState(
                                    () => _hideConfirm = !_hideConfirm,
                                  ),
                                  icon: Icon(
                                    _hideConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _rememberTile(),
                          if (_message != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _message!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(register ? '创建账号' : '登录'),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _registerMode = !_registerMode;
                                      _message = null;
                                      _confirm.clear();
                                    }),
                            child: Text(
                              register ? '已有账号？返回登录' : '还没有账号？创建新账号',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _configWarning(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '需要先在 lib/config.dart 替换 supabaseAnonKey（占位符 REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY）。',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

/// 很淡的循环光晕，登录和注册的漂浮方向不同，不抢卡片上的字。
class _SoftAuraBackground extends StatefulWidget {
  const _SoftAuraBackground({
    required this.registerMode,
    required this.color,
  });

  final bool registerMode;
  final Color color;

  @override
  State<_SoftAuraBackground> createState() => _SoftAuraBackgroundState();
}

class _SoftAuraBackgroundState extends State<_SoftAuraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ColoredBox(
          color: base,
          child: CustomPaint(
            painter: _AuraPainter(
              progress: _controller.value,
              color: widget.color,
              registerMode: widget.registerMode,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.progress,
    required this.color,
    required this.registerMode,
  });

  final double progress;
  final Color color;
  final bool registerMode;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final wave = (math.sin(t * math.pi) + 1) / 2;
    final orbs = registerMode
        ? [
            Offset(size.width * (0.82 - 0.08 * t), size.height * (0.18 + 0.06 * wave)),
            Offset(size.width * (0.18 + 0.06 * wave), size.height * (0.78 - 0.05 * t)),
            Offset(size.width * (0.70 + 0.04 * wave), size.height * (0.72 + 0.04 * t)),
          ]
        : [
            Offset(size.width * (0.20 + 0.08 * t), size.height * (0.22 + 0.05 * wave)),
            Offset(size.width * (0.84 - 0.05 * wave), size.height * (0.70 - 0.06 * t)),
            Offset(size.width * (0.48 + 0.04 * wave), size.height * (0.30 + 0.08 * t)),
          ];
    final radii = [
      size.shortestSide * (0.42 + 0.06 * wave),
      size.shortestSide * (0.34 + 0.04 * (1 - wave)),
      size.shortestSide * 0.28,
    ];
    for (var i = 0; i < orbs.length; i++) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: registerMode ? 0.13 : 0.11),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: orbs[i], radius: radii[i]));
      canvas.drawCircle(orbs[i], radii[i], paint);
    }
    final blur = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(Offset.zero & size, blur);
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.registerMode != registerMode ||
        oldDelegate.color != color;
  }
}
