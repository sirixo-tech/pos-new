#pragma once

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <memory>

class WindowsPrinter {
 public:
  explicit WindowsPrinter(flutter::BinaryMessenger* messenger);
 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
