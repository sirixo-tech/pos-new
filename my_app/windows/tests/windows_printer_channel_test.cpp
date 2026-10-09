#include "../runner/windows_printer.h"
#include "../runner/scanner_status.h"
#include <flutter/standard_method_codec.h>
#include <fstream>
#include <iostream>
#include <map>

class Messenger : public flutter::BinaryMessenger {
 public:
  std::map<std::string, flutter::BinaryMessageHandler> handlers;
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply) const override {}
  void SetMessageHandler(const std::string& channel,
                        flutter::BinaryMessageHandler handler) override {
    handlers[channel] = std::move(handler);
  }
};

int main(int argc, char** argv) {
  if (argc != 3) return 2;
  if (IsScannerDescription(L"HID Keyboard Device") ||
      IsScannerDescription(L"USB Input Device") ||
      !IsScannerDescription(L"USB Barcode Scanner") ||
      !IsScannerDescription(L"RETSOL PD-2000+") ||
      !IsScannerDescription(L"RETSOL LS-450") ||
      !IsScannerDescription(L"Honeywell reader") ||
      !IsScannerDescription(L"CipherLab USB reader") ||
      !IsScannerDescription(L"Generic 2D reader") ||
      !IsScannerDescription(L"USB bar-code reader")) return 3;
  const auto scanner_status = ScannerStatus();
  std::cout << "Scanner connected: " << std::get<bool>(scanner_status.at(
      flutter::EncodableValue("connected"))) << std::endl;
  Messenger messenger;
  WindowsPrinter printer(&messenger);
  const auto& codec = flutter::StandardMethodCodec::GetInstance();
  const std::string names[] = {argv[2], "SelfX nonexistent regression test queue"};
  for (int i = 0; i < 3; ++i) {
    flutter::EncodableMap args;
    if (i < 2) args[flutter::EncodableValue("name")] = flutter::EncodableValue(names[i]);
    flutter::MethodCall<flutter::EncodableValue> call("getStatus",
        std::make_unique<flutter::EncodableValue>(args));
    const auto request = codec.EncodeMethodCall(call);
    std::vector<uint8_t> reply;
    messenger.handlers.at("pos_main/windows_printer")(
        request->data(), request->size(),
        [&](const uint8_t* data, size_t size) { reply.assign(data, data + size); });
    const auto path = std::string(argv[1]) + "/reply" + std::to_string(i) + ".bin";
    std::ofstream output(path, std::ios::binary);
    output.write(reinterpret_cast<const char*>(reply.data()), reply.size());
    std::cout << i << ": ";
    for (auto byte : reply) std::cout << std::hex << static_cast<int>(byte) << " ";
    std::cout << std::endl;
  }
  return 0;
}
