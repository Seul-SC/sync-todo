@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0.."

set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

echo [1/3] flutter build windows --release
call D:\flutter\bin\flutter.bat build windows --release
if errorlevel 1 exit /b 1

set ISCC=
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if exist "tools\InnoSetup\ISCC.exe" set "ISCC=%CD%\tools\InnoSetup\ISCC.exe"

if "%ISCC%"=="" (
  echo 未找到 Inno Setup 6，请先安装后再运行本脚本。
  exit /b 1
)

echo [2/3] 使用 ISCC: %ISCC%
if not exist dist mkdir dist
"%ISCC%" "installer\sync_todo.iss"
if errorlevel 1 exit /b 1

echo [3/3] 完成。安装包在 dist\ 目录。
dir /b dist\*.exe
endlocal
