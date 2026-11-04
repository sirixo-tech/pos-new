#include "flutter_window.h"
#include "scanner_status.h"

#include <optional>
#include <vector>
#include <string>
#include <stdexcept>
#include <flutter/standard_method_codec.h>

namespace {

// Windows 10 TabTip and the Windows 11 touch keyboard. A key press activates
// that window, and Flutter then drops the text connection, so typed letters
// never reach the field.
bool IsTouchKeyboardWindow(HWND hwnd) {
  if (hwnd == nullptr) return false;

  wchar_t cls[256];
  if (GetClassName(hwnd, cls, 256) > 0) {
    if (wcsstr(cls, L"IPTip_Main_Window") != nullptr ||
        wcsstr(cls, L"TabTip") != nullptr) {
      return true;
    }
  }

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) return false;
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) return false;

  wchar_t path[MAX_PATH];
  DWORD size = MAX_PATH;
  bool match = false;
  if (QueryFullProcessImageName(process, 0, path, &size)) {
    const wchar_t* file = path;
    for (const wchar_t* p = path; *p != L'\0'; ++p) {
      if (*p == L'\\' || *p == L'/') file = p + 1;
    }
    match = _wcsicmp(file, L"TabTip.exe") == 0 ||
            _wcsicmp(file, L"TextInputHost.exe") == 0;
  }
  CloseHandle(process);
  return match;
}

}  // namespace

#include "flutter/generated_plugin_registrant.h"

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
  windows_printer_ = std::make_unique<WindowsPrinter>(
      flutter_controller_->engine()->messenger());
  touch_keyboard_ = std::make_unique<TouchKeyboard>(
      flutter_controller_->engine()->messenger(), GetHandle());
  scanner_status_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "pos_main/scanner_status",
      &flutter::StandardMethodCodec::GetInstance());
  scanner_status_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "getStatus") {
      result->NotImplemented();
      return;
    }
    try {
      result->Success(flutter::EncodableValue(ScannerStatus()));
    } catch (const std::exception& error) {
      result->Error("SCANNER_STATUS", error.what());
    }
  });
  menu_speech_ = std::make_unique<MenuSpeech>(flutter_controller_->engine()->messenger(), GetHandle());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  windows_printer_.reset();
  touch_keyboard_.reset();
  scanner_status_.reset();
  menu_speech_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (menu_speech_ && menu_speech_->HandleMessage(message, wparam)) return 0;
  if (message == WM_TIMER && wparam == TouchKeyboard::kTimerId &&
      touch_keyboard_) {
    touch_keyboard_->OnTimer();
    return 0;
  }

  // Keep the Flutter view focused while the touch keyboard is up. Swallowing
  // this deactivation stops the engine from closing the text field.
  if (message == WM_ACTIVATE && LOWORD(wparam) == WA_INACTIVE &&
      flutter_controller_) {
    HWND next = reinterpret_cast<HWND>(lparam);
    if (IsTouchKeyboardWindow(next)) {
      auto* view = flutter_controller_->view();
      if (view != nullptr) {
        HWND native = view->GetNativeWindow();
        if (native != nullptr) SetFocus(native);
      }
      return 0;
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
