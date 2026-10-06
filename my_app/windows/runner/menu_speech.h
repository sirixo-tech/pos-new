#pragma once

#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <sapi.h>
#include <wrl/client.h>
#include <memory>

// Poll SAPI from the platform window thread. No worker thread sends Flutter
// messages or accesses apartment-bound COM speech objects.
class MenuSpeech {
 public:
  MenuSpeech(flutter::BinaryMessenger* messenger, HWND window);
  ~MenuSpeech();
  bool HandleMessage(UINT message, WPARAM wparam);

 private:
  bool Listen(const flutter::EncodableList& words);
  void Stop();
  void Poll();
  static constexpr UINT_PTR kTimer = 0x534D;
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  Microsoft::WRL::ComPtr<ISpRecognizer> recognizer_;
  Microsoft::WRL::ComPtr<ISpRecoContext> context_;
  Microsoft::WRL::ComPtr<ISpRecoGrammar> grammar_;
  Microsoft::WRL::ComPtr<ISpAudio> audio_;
};
