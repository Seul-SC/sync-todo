/// 自建 Supabase 连接配置。
///
/// 使用前请复制本文件为 `config.dart`，把 [supabaseUrl] 换成你的服务器地址，
/// 把 [supabaseAnonKey] 换成服务器 `.env` 里的
/// `ANON_KEY` 或 `SUPABASE_PUBLISHABLE_KEY`。
/// 不要写入 SERVICE_ROLE_KEY / SUPABASE_SECRET_KEY。
/// 填好密钥的 `config.dart` 只留在本机，不要提交到 Git。
class AppConfig {
  static const String supabaseUrl = 'http://YOUR_SUPABASE_HOST:8000';

  /// 占位符：启动后替换成真实的 anon / publishable key。
  static const String supabaseAnonKey = 'REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY';

  static bool get hasValidKey =>
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY';
}
