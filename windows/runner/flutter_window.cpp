#include "flutter_window.h"

#include <optional>
#include <dwmapi.h>

#include "flutter/generated_plugin_registrant.h"

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    // AppTheme primary brand color: #B45309 (BGR format: 0x000953B4)
    COLORREF captionColor = RGB(0xB4, 0x53, 0x09);
    COLORREF textColor = RGB(0xFF, 0xFF, 0xFF);
    BOOL useDarkMode = TRUE;

    ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &useDarkMode, sizeof(useDarkMode));
    ::DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &captionColor, sizeof(captionColor));
    ::DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, &textColor, sizeof(textColor));
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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Register Security & Proctoring MethodChannel
  security_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.neodyit.acadova/security",
      &flutter::StandardMethodCodec::GetInstance());

  security_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "enableSecureScreen") {
          this->EnableProctoringSecurity();
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "disableSecureScreen") {
          this->DisableProctoringSecurity();
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

namespace {
HHOOK g_kiosk_keyboard_hook = nullptr;

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION) {
    KBDLLHOOKSTRUCT* pKbd = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    if (pKbd != nullptr) {
      bool isAltDown = (pKbd->flags & LLKHF_ALTDOWN) != 0;
      bool isWinDown = (GetKeyState(VK_LWIN) & 0x8000) != 0 || (GetKeyState(VK_RWIN) & 0x8000) != 0;
      bool isCtrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;

      // 1. Block Win key press, Win+Tab (Task View), Win+D, Win+R, Win+E, Win+X, etc.
      if (pKbd->vkCode == VK_LWIN || pKbd->vkCode == VK_RWIN || isWinDown) {
        return 1; // Block key completely
      }

      // 2. Block Alt+Tab, Alt+Esc
      if (isAltDown && (pKbd->vkCode == VK_TAB || pKbd->vkCode == VK_ESCAPE)) {
        return 1;
      }

      // 3. Block Ctrl+Tab, Ctrl+Esc, Ctrl+Shift+Esc
      if (isCtrlDown && (pKbd->vkCode == VK_TAB || pKbd->vkCode == VK_ESCAPE)) {
        return 1;
      }
    }
  }
  return CallNextHookEx(g_kiosk_keyboard_hook, nCode, wParam, lParam);
}
}  // namespace

void FlutterWindow::EnableProctoringSecurity() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || is_proctored_mode_) return;

  is_proctored_mode_ = true;

  // Install Low Level Keyboard Hook to block Windows system shortcuts (Win+Tab, Alt+Tab, Win Keys)
  if (g_kiosk_keyboard_hook == nullptr) {
    g_kiosk_keyboard_hook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(nullptr), 0);
  }

  // 1. Save current window styles & placement
  GetWindowPlacement(hwnd, &saved_window_placement_);
  saved_style_ = GetWindowLong(hwnd, GWL_STYLE);
  saved_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);

  // 2. Strip window decorations and system controls
  DWORD new_style = saved_style_ & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
  SetWindowLong(hwnd, GWL_STYLE, new_style);

  // 3. Set HWND_TOPMOST flag and prevent display capture / screen recording
  SetWindowLong(hwnd, GWL_EXSTYLE, (saved_ex_style_ | WS_EX_TOPMOST) & ~WS_EX_APPWINDOW);

  // Prevent display capture / recording (Windows 10 2004+ / Windows 11)
  SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE);

  // 4. Expand window to cover entire primary monitor (Fullscreen Kiosk Mode)
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = { sizeof(MONITORINFO) };
  if (GetMonitorInfo(monitor, &mi)) {
    SetWindowPos(hwnd, HWND_TOPMOST,
                 mi.rcMonitor.left, mi.rcMonitor.top,
                 mi.rcMonitor.right - mi.rcMonitor.left,
                 mi.rcMonitor.bottom - mi.rcMonitor.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  }

  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);
  ::SetFocus(hwnd);
}

void FlutterWindow::DisableProctoringSecurity() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || !is_proctored_mode_) return;

  is_proctored_mode_ = false;

  // Unhook Low Level Keyboard Hook
  if (g_kiosk_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_kiosk_keyboard_hook);
    g_kiosk_keyboard_hook = nullptr;
  }

  // Restore display capture affinity
  SetWindowDisplayAffinity(hwnd, WDA_NONE);

  // Restore window styles & position
  SetWindowLong(hwnd, GWL_STYLE, saved_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, saved_ex_style_);
  SetWindowPlacement(hwnd, &saved_window_placement_);
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
}

void FlutterWindow::OnDestroy() {
  if (is_proctored_mode_) {
    DisableProctoringSecurity();
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (is_proctored_mode_) {
    switch (message) {
      // 1. Prevent close request (Alt+F4 or Taskbar close)
      case WM_CLOSE:
        return 0; // Completely ignore close attempt

      // 2. Prevent minimizing or hiding via WM_WINDOWPOSCHANGING
      case WM_WINDOWPOSCHANGING: {
        WINDOWPOS* pos = reinterpret_cast<WINDOWPOS*>(lparam);
        if (pos) {
          // Force TOPMOST and remove HIDE / MINIMIZE flags
          pos->hwndInsertAfter = HWND_TOPMOST;
          pos->flags &= ~SWP_HIDEWINDOW;
        }
        break;
      }

      // 3. Block shortcut keys like Ctrl+Tab, Alt+Tab, Win keys, Ctrl+Esc
      case WM_KEYDOWN:
      case WM_SYSKEYDOWN: {
        bool isCtrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
        bool isAltDown = (lparam & (1 << 29)) != 0;
        if (wparam == VK_TAB || wparam == VK_ESCAPE || (isCtrlDown && wparam == VK_TAB) || (isAltDown && wparam == VK_TAB) || wparam == VK_LWIN || wparam == VK_RWIN) {
          return 0; // Block key press completely
        }
        break;
      }

      // 4. Prevent minimizing, switching, task switching, or system commands
      case WM_SYSCOMMAND: {
        UINT cmd = wparam & 0xFFF0;
        if (cmd == SC_MINIMIZE || cmd == SC_CLOSE || cmd == SC_SCREENSAVE ||
            cmd == SC_MONITORPOWER || cmd == SC_RESTORE || cmd == SC_TASKLIST ||
            cmd == SC_NEXTWINDOW || cmd == SC_PREVWINDOW) {
          return 0; // Block action
        }
        break;
      }

      // 4. Force focus back immediately if focus is lost (Alt+Tab, Win+Tab, Start key, floating overlay)
      case WM_KILLFOCUS:
      case WM_ACTIVATE:
      case WM_ACTIVATEAPP: {
        if (LOWORD(wparam) == WA_INACTIVE || wparam == FALSE) {
          ::SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
          ::BringWindowToTop(hwnd);
          ::SetForegroundWindow(hwnd);
          ::SetFocus(hwnd);
        }
        break;
      }
    }
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
