; 同步待办 · Inno Setup 安装脚本
#define MyAppName "同步待办"
#define MyAppVersion "1.2.2"
#define MyAppPublisher "Seul_SC_照晨"
#define MyAppExeName "sync_todo.exe"

[Setup]
AppId={{8F3C2A91-6B4E-4D1A-9C77-2E5B8A1D0F33}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SyncTodo
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
DisableDirPage=no
UsePreviousAppDir=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=SyncTodo-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加选项:"
Name: "startupicon"; Description: "开机时自动启动同步待办（只有程序在运行时才能弹出待办提醒）"; GroupDescription: "附加选项:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--minimized"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "立即运行同步待办"; Flags: nowait postinstall skipifsilent
