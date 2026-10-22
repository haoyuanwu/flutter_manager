#include "flutter_window.h"

#include <shellapi.h>
#include <dwmapi.h>

#include <cwchar>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/standard_method_codec.h"
#include "resource.h"
#include "utils.h"

namespace {
constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayCallbackMessage = WM_APP + 1;

void ConfigureAppearanceChannel(flutter::FlutterViewController* controller) {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      controller->engine()->messenger(), "fvm_manager/appearance",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([controller](const auto& call, auto result) {
    if (call.method_name() != "setTheme") {
      result->NotImplemented();
      return;
    }
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (arguments == nullptr) {
      result->Error("invalid_arguments", "Expected appearance settings.");
      return;
    }
    const auto dark = arguments->find(flutter::EncodableValue("dark"));
    const auto mode = arguments->find(flutter::EncodableValue("mode"));
    if (dark == arguments->end() || !std::holds_alternative<bool>(dark->second)) {
      result->Error("invalid_arguments", "Expected dark appearance flag.");
      return;
    }
    HWND window = GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT);
    const BOOL enabled = std::get<bool>(dark->second);
    const bool system = mode != arguments->end() &&
        std::get_if<std::string>(&mode->second) != nullptr &&
        std::get<std::string>(mode->second) == "system";
    if (system) {
      RemovePropW(window, L"FvmManager.DarkAppearance");
    } else {
      SetPropW(window, L"FvmManager.DarkAppearance",
               reinterpret_cast<HANDLE>(static_cast<INT_PTR>(enabled ? 2 : 1)));
    }
    DwmSetWindowAttribute(window, 20, &enabled, sizeof(enabled));
    result->Success();
  });
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  drag_drop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "fvm_manager/drag_drop",
          &flutter::StandardMethodCodec::GetInstance());
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    RegisterPlugins(registry);
    ConfigureAppearanceChannel(flutter_view_controller);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  ConfigureAppearanceChannel(flutter_controller_.get());
  if (GetHandle() != nullptr) {
    DragAcceptFiles(GetHandle(), TRUE);
    SetupTrayIcon();
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  if (GetHandle() != nullptr) {
    DragAcceptFiles(GetHandle(), FALSE);
  }
  drag_drop_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetupTrayIcon() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || tray_icon_added_) {
    return;
  }

  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = hwnd;
  nid.uID = kTrayIconId;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
  nid.uCallbackMessage = kTrayCallbackMessage;
  nid.hIcon = static_cast<HICON>(LoadImageW(
      GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
      LR_SHARED));
  if (nid.hIcon == nullptr) {
    nid.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  }
  lstrcpynW(nid.szTip, L"Flutter Manager", ARRAYSIZE(nid.szTip));

  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
  if (tray_icon_added_) {
    nid.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &nid);
  }
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = kTrayIconId;
  Shell_NotifyIconW(NIM_DELETE, &nid);
  tray_icon_added_ = false;
}

void FlutterWindow::HideToTray() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  SetupTrayIcon();
  if (tray_icon_added_) {
    ShowWindow(hwnd, SW_HIDE);
  }
}

void FlutterWindow::ShowFromTray() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  ShowWindow(hwnd, SW_SHOWNORMAL);
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  SetForegroundWindow(hwnd);
}

void FlutterWindow::ShowTrayContextMenu() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  POINT cursor;
  GetCursorPos(&cursor);

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  AppendMenuW(menu, MF_STRING, IDM_TRAY_SHOW, L"打开主窗口");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, IDM_TRAY_EXIT, L"退出");

  // 必须先 SetForegroundWindow，否则菜单点完不会自动消失。
  SetForegroundWindow(hwnd);
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, cursor.x, cursor.y, 0, hwnd,
      nullptr);
  DestroyMenu(menu);
  PostMessageW(hwnd, WM_NULL, 0, 0);
  if (command == 0) {
    return;
  }

  PostMessageW(hwnd, WM_COMMAND, MAKEWPARAM(command, 0), 0);
}

void FlutterWindow::HandleTrayCommand(UINT command) {
  switch (command) {
    case IDM_TRAY_SHOW:
      ShowFromTray();
      break;
    case IDM_TRAY_EXIT:
      allow_quit_ = true;
      RemoveTrayIcon();
      DestroyWindow(GetHandle());
      break;
    default:
      break;
  }
}

void FlutterWindow::HandleTrayCallback(LPARAM lparam) {
  // Version 4 packs the icon ID in the high word and the event in the low word.
  const UINT event = LOWORD(lparam);
  switch (event) {
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
    case NIN_SELECT:
    case NIN_KEYSELECT:
      ShowFromTray();
      break;
    case WM_RBUTTONUP:
    case WM_CONTEXTMENU:
      ShowTrayContextMenu();
      break;
    default:
      break;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam, LPARAM const lparam) noexcept {
  if (message == kTrayCallbackMessage) {
    HandleTrayCallback(lparam);
    return 0;
  }
  if (message == WM_COMMAND && lparam == 0 &&
      (LOWORD(wparam) == IDM_TRAY_SHOW || LOWORD(wparam) == IDM_TRAY_EXIT)) {
    HandleTrayCommand(LOWORD(wparam));
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                       lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      // 关闭主窗口 = 最小化到托盘；真正退出走托盘菜单。
      if (!allow_quit_) {
        HideToTray();
        return 0;
      }
      break;

    case WM_DROPFILES:
      HandleDropFiles(reinterpret_cast<void*>(wparam));
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::HandleDropFiles(void* drop_handle) noexcept {
  HDROP drop = reinterpret_cast<HDROP>(drop_handle);
  if (!drag_drop_channel_) {
    DragFinish(drop);
    return;
  }

  const UINT file_count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < file_count; ++i) {
    const UINT path_length = DragQueryFileW(drop, i, nullptr, 0);
    if (path_length == 0) {
      continue;
    }

    std::wstring path(path_length + 1, L'\0');
    DragQueryFileW(drop, i, path.data(), path_length + 1);
    path.resize(path_length);

    DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
      continue;
    }

    bool should_send = (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    if (!should_send) {
      const size_t separator = path.find_last_of(L"\\/");
      const std::wstring file_name = separator == std::wstring::npos
          ? path
          : path.substr(separator + 1);
      if (_wcsicmp(file_name.c_str(), L"pubspec.yaml") == 0 &&
          separator != std::wstring::npos) {
        path.resize(separator);
        should_send = true;
      }
    }

    if (!should_send) {
      continue;
    }

    drag_drop_channel_->InvokeMethod(
        "onPathDropped",
        std::make_unique<flutter::EncodableValue>(Utf8FromUtf16(path.c_str())));
  }

  DragFinish(drop);
}
