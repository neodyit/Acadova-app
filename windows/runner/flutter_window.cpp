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
HHOOK g_kiosk_mouse_hook = nullptr;
bool g_proctored_active = false;
HWND g_proctored_hwnd = nullptr;

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION && g_proctored_active) {
    KBDLLHOOKSTRUCT* pKbd = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    if (pKbd != nullptr) {
      bool isAltDown = (pKbd->flags & LLKHF_ALTDOWN) != 0;
      bool isWinDown = (GetKeyState(VK_LWIN) & 0x8000) != 0 || (GetKeyState(VK_RWIN) & 0x8000) != 0;
      bool isCtrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;

      // 1. Block ALL Win key combinations & Task View (Win+Tab, Win+D, Win+A, Win+K, Win+C, Win+S, Win+X, etc.)
      if (pKbd->vkCode == VK_LWIN || pKbd->vkCode == VK_RWIN || isWinDown) {
        if (g_proctored_hwnd != nullptr) {
          ::SetWindowPos(g_proctored_hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
          ::BringWindowToTop(g_proctored_hwnd);
          ::SetForegroundWindow(g_proctored_hwnd);
        }
        return 1; // Block key completely
      }

      // 2. Block Alt+Tab, Alt+Esc, Alt+F4, Alt+Space
      if (isAltDown && (pKbd->vkCode == VK_TAB || pKbd->vkCode == VK_ESCAPE || pKbd->vkCode == VK_F4 || pKbd->vkCode == VK_SPACE)) {
        return 1;
      }

      // 3. Block Ctrl+Tab, Ctrl+Esc, Ctrl+Shift+Esc
      if (isCtrlDown && (pKbd->vkCode == VK_TAB || pKbd->vkCode == VK_ESCAPE)) {
        return 1;
      }

      // 4. Block F11, F12, PrintScreen
      if (pKbd->vkCode == VK_SNAPSHOT || pKbd->vkCode == VK_F11 || pKbd->vkCode == VK_F12) {
        return 1;
      }
    }
  }
  return CallNextHookEx(g_kiosk_keyboard_hook, nCode, wParam, lParam);
}

LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode == HC_ACTION && g_proctored_active) {
    // Catch mouse/touchpad gesture actions when window is proctored
    if (g_proctored_hwnd != nullptr) {
      HWND foregroundHwnd = ::GetForegroundWindow();
      if (foregroundHwnd != g_proctored_hwnd) {
        ::SetWindowPos(g_proctored_hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
        ::BringWindowToTop(g_proctored_hwnd);
        ::SetForegroundWindow(g_proctored_hwnd);
        ::SetFocus(g_proctored_hwnd);
      }
    }
  }
  return CallNextHookEx(g_kiosk_mouse_hook, nCode, wParam, lParam);
}
}  // namespace

void FlutterWindow::EnableProctoringSecurity() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr || is_proctored_mode_) return;

  is_proctored_mode_ = true;
  g_proctored_active = true;
  g_proctored_hwnd = hwnd;

  // Install Low Level Keyboard & Mouse/Touchpad Hooks
  if (g_kiosk_keyboard_hook == nullptr) {
    g_kiosk_keyboard_hook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(nullptr), 0);
  }
  if (g_kiosk_mouse_hook == nullptr) {
    g_kiosk_mouse_hook = SetWindowsHookEx(WH_MOUSE_LL, LowLevelMouseProc, GetModuleHandle(nullptr), 0);
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

  // 5. Start ultra-high frequency 15ms focus enforcement timer (forces focus back instantly if touchpad gesture tries to lift window)
  focus_timer_id_ = ::SetTimer(hwnd, 999, 15, nullptr);
}

void FlutterWindow::DisableProctoringSecurity() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) return;

  is_proctored_mode_ = false;
  g_proctored_active = false;
  g_proctored_hwnd = nullptr;

  // Kill focus enforcement timer
  if (focus_timer_id_ != 0) {
    ::KillTimer(hwnd, focus_timer_id_);
    focus_timer_id_ = 0;
  }

  // Unhook Low Level Hooks
  if (g_kiosk_keyboard_hook != nullptr) {
    UnhookWindowsHookEx(g_kiosk_keyboard_hook);
    g_kiosk_keyboard_hook = nullptr;
  }
  if (g_kiosk_mouse_hook != nullptr) {
    UnhookWindowsHookEx(g_kiosk_mouse_hook);
    g_kiosk_mouse_hook = nullptr;
  }

  // Restore display capture affinity
  SetWindowDisplayAffinity(hwnd, WDA_NONE);

  // Strip HWND_TOPMOST style completely
  saved_ex_style_ &= ~WS_EX_TOPMOST;
  SetWindowLong(hwnd, GWL_STYLE, saved_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, saved_ex_style_);
  SetWindowPlacement(hwnd, &saved_window_placement_);

  // Force HWND_NOTOPMOST & trigger window frame change
  SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

  // Redraw window and ensure normal OS z-order behavior
  ::RedrawWindow(hwnd, nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW | RDW_FRAME);
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
      // 1. High-frequency focus enforcement timer pulse (Blocks 3-finger touchpad swipe task switcher overlay)
      case WM_TIMER: {
        if (wparam == 999) {
          HWND foregroundHwnd = ::GetForegroundWindow();
          if (foregroundHwnd != hwnd) {
            ::SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
            ::BringWindowToTop(hwnd);
            ::SetForegroundWindow(hwnd);
            ::SetFocus(hwnd);
          }
        }
        break;
      }

      // 2. Prevent close request (Alt+F4 or Taskbar close)
      case WM_CLOSE:
        return 0; // Completely ignore close attempt

      // 3. Prevent minimizing, hiding or losing TOPMOST status (3-finger gesture / task view preview)
      case WM_WINDOWPOSCHANGING: {
        WINDOWPOS* pos = reinterpret_cast<WINDOWPOS*>(lparam);
        if (pos) {
          pos->hwndInsertAfter = HWND_TOPMOST;
          pos->flags &= ~(SWP_HIDEWINDOW | SWP_NOZORDER | SWP_NOACTIVATE);
        }
        break;
      }

      // 4. Block shortcut keys like Ctrl+Tab, Alt+Tab, Win keys, Ctrl+Esc
      case WM_KEYDOWN:
      case WM_SYSKEYDOWN: {
        bool isCtrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
        bool isAltDown = (lparam & (1 << 29)) != 0;
        if (wparam == VK_TAB || wparam == VK_ESCAPE || (isCtrlDown && wparam == VK_TAB) || (isAltDown && wparam == VK_TAB) || wparam == VK_LWIN || wparam == VK_RWIN) {
          return 0; // Block key press completely
        }
        break;
      }

      // 5. Prevent minimizing, switching, task switching, or system commands
      case WM_SYSCOMMAND: {
        UINT cmd = wparam & 0xFFF0;
        if (cmd == SC_MINIMIZE || cmd == SC_CLOSE || cmd == SC_SCREENSAVE ||
            cmd == SC_MONITORPOWER || cmd == SC_RESTORE || cmd == SC_TASKLIST ||
            cmd == SC_NEXTWINDOW || cmd == SC_PREVWINDOW) {
          return 0; // Block action
        }
        break;
      }

      // 6. Force focus back IMMEDIATELY if touchpad gesture or task-switcher tries to deactivate window
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
