#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <memory>

#include "flutter_window.h"
#include "utils.h"
#include "resource.h"

namespace {
bool ActivateRunningWindow() {
  const HWND window = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Flutter Manager");
  if (window == nullptr) return false;
  DWORD process_id = 0;
  GetWindowThreadProcessId(window, &process_id);
  AllowSetForegroundWindow(process_id);
  // 使用现有托盘命令，兼容旧版本，并恢复隐藏或最小化的窗口。
  PostMessageW(window, WM_COMMAND, IDM_TRAY_SHOW, 0);
  return true;
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 在初始化 Flutter 和读写设置前占用互斥锁，避免双击时并发启动。
  const HANDLE handle = CreateMutexW(nullptr, FALSE,
                                    L"Local\\FlutterManager.SingleInstance");
  const DWORD mutex_error = GetLastError();
  std::unique_ptr<void, decltype(&CloseHandle)> instance_mutex(handle, CloseHandle);
  if (handle == nullptr) {
    MessageBoxW(nullptr, L"无法检查 Flutter Manager 是否正在运行。",
                L"Flutter Manager", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  // 同时兼容尚未使用互斥锁的已安装旧版本。
  if (ActivateRunningWindow()) return EXIT_SUCCESS;
  if (mutex_error == ERROR_ALREADY_EXISTS) {
    // 首个进程可能仍在创建窗口；第二个进程只等待并激活，不初始化应用。
    for (int attempt = 0; attempt < 200; ++attempt) {
      Sleep(50);
      if (ActivateRunningWindow()) return EXIT_SUCCESS;
    }
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
  if (!window.Create(L"Flutter Manager", origin, size)) {
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
