# 同步待办

Windows 和安卓两端同步的待办、笔记和提醒应用。当前版本 **1.2.1**。

## 这是什么

用邮箱和密码登录后，待办和笔记会在电脑和手机之间同步。电脑端左侧是常驻栏，用来切换待办或笔记文件夹，右边显示内容。手机端是更简单的列表，也能查看、修改和新建笔记。

主要能力：

- 待办：一行标题（必填）加可多行内容；支持每天重复，或每周多选星期
- 笔记：电脑端完整文件夹树，手机端简单列表；笔记可以和待办联动
- 提醒：到点弹出提醒；同一时刻有多条时，每条各弹一个窗口。按钮只有「完成」和「稍后提醒」（固定推迟 10 分钟）
- 五套主题：默认纯白、浅绿、同行、涟漪、深色
- 设置里可选择时区；到点仍未完成的待办会进入「过去」
- 软删除，待办和笔记共用回收站
- 应用内检查更新（需要你自己配置更新清单）

## 如何配置并运行

### 需要的开发环境

- [Flutter](https://flutter.dev) 3.50 或更高（Dart 3.14+）
- 打 Windows 桌面版：Visual Studio 2022，勾选「使用 C++ 的桌面开发」，以及 Windows 10 SDK
- 打 Windows 安装包：Inno Setup 6
- 打安卓安装包：Android SDK，以及 JDK 17（只在打包时使用即可）

国内如果拉取依赖较慢，可以设置：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Windows PowerShell 里可以用：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

### 配置后端

本项目使用自建 [Supabase](https://supabase.com)（官方 Docker 亦可）。

1. 复制 `lib/config.example.dart` 为 `lib/config.dart`
2. 把 `supabaseUrl` 改成你的服务地址，例如 `http://你的服务器:8000`
3. 把 `supabaseAnonKey` 改成服务器 `.env` 里的 `ANON_KEY` 或 `SUPABASE_PUBLISHABLE_KEY`
4. 不要写入 `SERVICE_ROLE_KEY` 或 `SUPABASE_SECRET_KEY`，也不要把已经填好密钥的 `config.dart` 提交到 Git

数据库结构在 `supabase/schema.sql`，从上一版升级可用 `supabase/migration_v2.sql`。

### 运行和打包

在项目目录执行：

```bash
flutter pub get
flutter run -d windows
flutter build windows --release
flutter build apk --release
```

Windows 安装包脚本在 `installer/sync_todo.iss`，用 Inno Setup 编译后，安装包会输出到 `dist` 目录。安卓打包完成后，可把 APK 拷到 `dist`。`dist` 目录不会进入本仓库。

## 怎么用

安装并打开应用后，用邮箱和密码登录。这一版可以注册新账号，暂不支持找回密码。

- Windows：关闭主窗口会进入托盘，可在设置里打开开机自启。如果电脑里已经装着更早的版本，再运行新的安装包并装到原来的位置，就会更新到这一版。
- 安卓：安装 APK 时需要允许「未知来源」。请按系统提示授予通知权限；如果应用被系统清理，会用系统通知兜底，建议把应用加入自启动或电池白名单。
- 待办到点时，点「完成」会同步到其他设备；点「稍后提醒」会把这次提醒推迟 10 分钟并同步。只关掉窗口、没有点完成的话，只影响本机。
- 重复待办勾选完成后，会在「已完成」里留下一条记录，原来的待办会推到下一次。

## 项目结构

```
lib/                     应用源码
  config.example.dart    后端地址配置示例（复制为 config.dart 再填写）
  screens/               页面：登录、待办、笔记、设置、回收站
  services/              同步、提醒、本地存储、更新检查
  widgets/               待办编辑、提醒弹窗等组件
  theme/                 五套主题
  platform/              Windows / 安卓平台相关代码
android/                 安卓工程
windows/                 Windows 工程
installer/               Windows 安装包脚本
supabase/                数据库结构与更新清单示例
assets/                  托盘图标等资源
test/                    测试
```

## 这一版没有包含的

- 仓库里不附带现成的安装包，需要自行构建
- 没有域名和 HTTPS。如果服务器是 HTTP，安卓端已允许明文访问
- 没有上应用商店，也没有找回密码
- 应用内更新需要你在自己的 Supabase Storage 中建立公共桶 `app-updates`，并上传 `version.json` 和安装包。示例见 `supabase/version.json.example`

## 许可证

[MIT License](LICENSE)
