#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr const wchar_t kMutexName[] =
    L"Local\\SyncTodo.SingleInstance.8F3C2A91";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"同步待办";

BOOL CALLBACK FindExistingWindow(HWND hwnd, LPARAM lparam) {
  wchar_t class_name[256];
  if (GetClassNameW(hwnd, class_name, 256) <= 0) {
    return TRUE;
  }
  if (wcscmp(class_name, kWindowClassName) != 0) {
    return TRUE;
  }
  wchar_t title[256];
  GetWindowTextW(hwnd, title, 256);
  if (wcscmp(title, kWindowTitle) != 0) {
    return TRUE;
  }
  *reinterpret_cast<HWND*>(lparam) = hwnd;
  return FALSE;
}

bool ActivateExistingInstance() {
  HWND hwnd = nullptr;
  EnumWindows(FindExistingWindow, reinterpret_cast<LPARAM>(&hwnd));
  if (!hwnd) {
    hwnd = FindWindowW(kWindowClassName, kWindowTitle);
  }
  if (!hwnd) {
    return false;
  }
  const UINT msg = RegisterWindowMessageW(L"SyncTodo_Activate");
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid) {
    AllowSetForegroundWindow(pid);
  }
  PostMessageW(hwnd, msg, 0, 0);
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  ShowWindow(hwnd, SW_SHOW);
  SetForegroundWindow(hwnd);
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE mutex = CreateMutexW(nullptr, TRUE, kMutexName);
  if (mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingInstance();
    CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"同步待办", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
