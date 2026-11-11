#pragma once

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <windows.h>

#include <memory>

class WindowsScale {
 public:
  explicit WindowsScale(flutter::BinaryMessenger* messenger);
  ~WindowsScale();

 private:
  void Handle(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ClosePort();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HANDLE handle_ = INVALID_HANDLE_VALUE;
};
