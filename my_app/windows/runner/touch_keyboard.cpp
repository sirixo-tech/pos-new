#include "touch_keyboard.h"

#include <shellapi.h>

namespace {
using flutter::EncodableValue;

// Undocumented but stable touch-keyboard toggle used by Win32 desktop apps.
// {4ce576fa-83dc-4f88-951c-9d0782b4e376}
const CLSID kUiHostNoLaunch = {
    0x4CE576FA, 0x83DC, 0x4F88, {0x95, 0x1C, 0x9D, 0x07, 0x82, 0xB4, 0xE3, 0x76}};
// {37c994e7-432b-4834-a2f7-dce1f13b834b}
const IID kTipInvocation = {
    0x37C994E7, 0x432B, 0x4834, {0xA2, 0xF7, 0xDC, 0xE1, 0xF1, 0x3B, 0x83, 0x4B}};

struct ITipInvocation : public IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Toggle(HWND window) = 0;
};

constexpr wchar_t kTabTip[] =
    L"C:\\Program Files\\Common Files\\microsoft shared\\ink\\TabTip.exe";

bool KeyboardWindowOpen() {
  const HWND tip = FindWindowW(L"IPTip_Main_Window", nullptr);
  if (tip == nullptr || !IsWindowVisible(tip)) return false;
  RECT rect{};
  if (!GetWindowRect(tip, &rect)) return false;
  return rect.right - rect.left > 80 && rect.bottom - rect.top > 40;
}

void ToggleKeyboard(HWND host) {
  ITipInvocation* tip = nullptr;
  const HRESULT created = CoCreateInstance(
      kUiHostNoLaunch, nullptr, CLSCTX_INPROC_HANDLER | CLSCTX_LOCAL_SERVER,
      kTipInvocation, reinterpret_cast<void**>(&tip));
  if (FAILED(created) || tip == nullptr) return;
  tip->Toggle(host != nullptr ? host : GetDesktopWindow());
  tip->Release();
}

void StartTabTip() {
  if (FindWindowW(L"IPTip_Main_Window", nullptr) != nullptr) return;
  ShellExecuteW(nullptr, L"open", kTabTip, nullptr, nullptr, SW_SHOWNA);
}
}  // namespace

TouchKeyboard::TouchKeyboard(flutter::BinaryMessenger* messenger, HWND host)
    : host_(host),
      channel_(std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "pos_main/touch_keyboard",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "show") {
      Show();
      result->Success();
      return;
    }
    if (call.method_name() == "hide") {
      Hide();
      result->Success();
      return;
    }
    result->NotImplemented();
  });
}

TouchKeyboard::~TouchKeyboard() {
  if (host_ != nullptr) KillTimer(host_, kTimerId);
}

void TouchKeyboard::Show() {
  pending_show_ = true;
  if (KeyboardWindowOpen()) return;
  StartTabTip();
  if (host_ == nullptr) {
    if (!KeyboardWindowOpen()) ToggleKeyboard(nullptr);
    return;
  }
  SetTimer(host_, kTimerId, 200, nullptr);
}

void TouchKeyboard::Hide() {
  pending_show_ = false;
  if (host_ != nullptr) KillTimer(host_, kTimerId);
  if (KeyboardWindowOpen()) ToggleKeyboard(host_);
}

void TouchKeyboard::OnTimer() {
  if (host_ != nullptr) KillTimer(host_, kTimerId);
  if (!pending_show_ || KeyboardWindowOpen()) return;
  ToggleKeyboard(host_);
}
