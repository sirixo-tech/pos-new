#ifndef RUNNER_TOUCH_KEYBOARD_H_
#define RUNNER_TOUCH_KEYBOARD_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Opens the Windows touch keyboard for a text field. Flutter's TextInput.show
// does not start it, and a barcode scanner counts as a keyboard so Windows
// will not open it on its own.
class TouchKeyboard {
 public:
  static constexpr UINT_PTR kTimerId = 0x53584B31;

  TouchKeyboard(flutter::BinaryMessenger* messenger, HWND host);
  ~TouchKeyboard();

  void OnTimer();

 private:
  void Show();
  void Hide();

  HWND host_;
  bool pending_show_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_TOUCH_KEYBOARD_H_
