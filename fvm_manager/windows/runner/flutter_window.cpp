#include "flutter_window.h"

#include <shellapi.h>

#include <cwchar>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/standard_method_codec.h"
#include "utils.h"

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
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  if (GetHandle() != nullptr) {
    DragAcceptFiles(GetHandle(), TRUE);
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
  if (GetHandle() != nullptr) {
    DragAcceptFiles(GetHandle(), FALSE);
  }
  drag_drop_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
