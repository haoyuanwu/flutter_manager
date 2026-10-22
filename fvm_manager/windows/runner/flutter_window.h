#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <shellapi.h>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void HandleDropFiles(void* drop) noexcept;

  // System tray: closing the main window minimizes to tray instead of quitting.
  void SetupTrayIcon();
  void RemoveTrayIcon();
  void HideToTray();
  void ShowFromTray();
  void ShowTrayContextMenu();
  void HandleTrayCommand(UINT command);
  void HandleTrayCallback(LPARAM lparam);

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      drag_drop_channel_;

  bool tray_icon_added_ = false;
  bool allow_quit_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
