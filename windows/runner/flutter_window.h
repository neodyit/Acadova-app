#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Proctored mode toggles for Windows
  void EnableProctoringSecurity();
  void DisableProctoringSecurity();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel for security & proctoring
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> security_channel_;

  bool is_proctored_mode_ = false;
  WINDOWPLACEMENT saved_window_placement_ = { sizeof(WINDOWPLACEMENT) };
  DWORD saved_style_ = 0;
  DWORD saved_ex_style_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
