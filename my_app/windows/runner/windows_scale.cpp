#include "windows_scale.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

namespace {

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  std::string text(size, '\0');
  WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), text.data(),
      size, nullptr, nullptr);
  return text;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  std::wstring text(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), text.data(),
      size);
  return text;
}

std::string WinError(const char* action, DWORD code) {
  wchar_t* message = nullptr;
  FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, code, 0, reinterpret_cast<wchar_t*>(&message), 0, nullptr);
  std::string text = action;
  if (message != nullptr) {
    text += ": ";
    text += WideToUtf8(message);
    while (!text.empty() && (text.back() == '\n' || text.back() == '\r')) {
      text.pop_back();
    }
    LocalFree(message);
  }
  return text;
}

const flutter::EncodableValue* Arg(
    const flutter::EncodableMap* args, const char* key) {
  if (args == nullptr) return nullptr;
  const auto found = args->find(flutter::EncodableValue(key));
  if (found == args->end()) return nullptr;
  return &found->second;
}

int ReadInt(const flutter::EncodableValue* value, int fallback) {
  if (value == nullptr) return fallback;
  if (const auto* number = std::get_if<int32_t>(value)) return *number;
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<int>(*number);
  }
  return fallback;
}

std::vector<std::string> ListComPorts() {
  std::vector<std::string> ports;
  HKEY key = nullptr;
  if (RegOpenKeyExW(
          HKEY_LOCAL_MACHINE, L"HARDWARE\\DEVICEMAP\\SERIALCOMM", 0, KEY_READ,
          &key) != ERROR_SUCCESS) {
    return ports;
  }
  for (DWORD index = 0;; ++index) {
    wchar_t name[256];
    wchar_t data[64];
    DWORD name_size = 256;
    DWORD data_size = sizeof(data);
    DWORD type = 0;
    const LONG status = RegEnumValueW(
        key, index, name, &name_size, nullptr, &type,
        reinterpret_cast<LPBYTE>(data), &data_size);
    if (status == ERROR_NO_MORE_ITEMS) break;
    if (status != ERROR_SUCCESS || type != REG_SZ) continue;
    const auto port = WideToUtf8(data);
    if (!port.empty()) ports.push_back(port);
  }
  RegCloseKey(key);
  std::sort(ports.begin(), ports.end());
  ports.erase(std::unique(ports.begin(), ports.end()), ports.end());
  return ports;
}

BYTE ParityOf(const std::string& parity) {
  if (parity == "even") return EVENPARITY;
  if (parity == "odd") return ODDPARITY;
  return NOPARITY;
}

}  // namespace

WindowsScale::WindowsScale(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "pos_main/scale",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) { Handle(call, std::move(result)); });
}

WindowsScale::~WindowsScale() {
  channel_->SetMethodCallHandler(nullptr);
  ClosePort();
}

void WindowsScale::ClosePort() {
  if (handle_ != INVALID_HANDLE_VALUE) {
    CloseHandle(handle_);
    handle_ = INVALID_HANDLE_VALUE;
  }
}

void WindowsScale::Handle(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (call.method_name() == "listPorts") {
    flutter::EncodableList rows;
    for (const auto& name : ListComPorts()) {
      flutter::EncodableMap row;
      row[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
      row[flutter::EncodableValue("label")] = flutter::EncodableValue(name);
      rows.push_back(flutter::EncodableValue(row));
    }
    result->Success(flutter::EncodableValue(rows));
    return;
  }
  if (call.method_name() == "close") {
    ClosePort();
    result->Success();
    return;
  }
  if (call.method_name() == "open") {
    const auto* name_value = Arg(args, "name");
    const auto* name = name_value == nullptr
        ? nullptr
        : std::get_if<std::string>(name_value);
    if (name == nullptr || name->empty()) {
      result->Error("SCALE_OPEN", "Choose a scale port.");
      return;
    }
    const int baud = ReadInt(Arg(args, "baud"), 9600);
    int data_bits = ReadInt(Arg(args, "dataBits"), 8);
    std::string parity = "none";
    if (const auto* parity_value = Arg(args, "parity")) {
      if (const auto* text = std::get_if<std::string>(parity_value)) {
        parity = *text;
      }
    }
    if (data_bits != 7 && data_bits != 8) data_bits = 8;
    ClosePort();
    const auto path = Utf8ToWide("\\\\.\\" + *name);
    handle_ = CreateFileW(
        path.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
        0, nullptr);
    if (handle_ == INVALID_HANDLE_VALUE) {
      result->Error(
          "SCALE_OPEN",
          WinError("Could not open the scale", GetLastError()));
      return;
    }
    DCB dcb{};
    dcb.DCBlength = sizeof(dcb);
    if (!GetCommState(handle_, &dcb)) {
      const auto message = WinError("Could not read the scale port", GetLastError());
      ClosePort();
      result->Error("SCALE_OPEN", message);
      return;
    }
    dcb.BaudRate = static_cast<DWORD>(baud);
    dcb.ByteSize = static_cast<BYTE>(data_bits);
    dcb.Parity = ParityOf(parity);
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = dcb.Parity == NOPARITY ? FALSE : TRUE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;
    if (!SetCommState(handle_, &dcb)) {
      const auto message = WinError("Could not apply the scale settings", GetLastError());
      ClosePort();
      result->Error("SCALE_OPEN", message);
      return;
    }
    COMMTIMEOUTS timeouts{};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.ReadTotalTimeoutConstant = 0;
    timeouts.WriteTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 200;
    SetCommTimeouts(handle_, &timeouts);
    EscapeCommFunction(handle_, SETDTR);
    EscapeCommFunction(handle_, SETRTS);
    PurgeComm(handle_, PURGE_RXCLEAR | PURGE_TXCLEAR);
    result->Success();
    return;
  }
  if (call.method_name() == "write") {
    if (handle_ == INVALID_HANDLE_VALUE) {
      result->Error("SCALE_WRITE", "The scale is not connected.");
      return;
    }
    const auto* bytes_value = Arg(args, "bytes");
    const auto* bytes = bytes_value == nullptr
        ? nullptr
        : std::get_if<std::vector<uint8_t>>(bytes_value);
    if (bytes == nullptr || bytes->empty()) {
      result->Success();
      return;
    }
    DWORD written = 0;
    if (!WriteFile(
            handle_, bytes->data(), static_cast<DWORD>(bytes->size()), &written,
            nullptr)) {
      result->Error("SCALE_WRITE", WinError("Could not write to the scale", GetLastError()));
      return;
    }
    result->Success();
    return;
  }
  if (call.method_name() == "read") {
    if (handle_ == INVALID_HANDLE_VALUE) {
      result->Success(flutter::EncodableValue(std::vector<uint8_t>{}));
      return;
    }
    DWORD errors = 0;
    COMSTAT status{};
    if (!ClearCommError(handle_, &errors, &status)) {
      result->Error("SCALE_READ", WinError("Could not read the scale", GetLastError()));
      return;
    }
    if (status.cbInQue == 0) {
      result->Success(flutter::EncodableValue(std::vector<uint8_t>{}));
      return;
    }
    const DWORD count = std::min<DWORD>(status.cbInQue, 4096);
    std::vector<uint8_t> buffer(count);
    DWORD read = 0;
    if (!ReadFile(handle_, buffer.data(), count, &read, nullptr)) {
      result->Error("SCALE_READ", WinError("Could not read the scale", GetLastError()));
      return;
    }
    buffer.resize(read);
    result->Success(flutter::EncodableValue(buffer));
    return;
  }
  result->NotImplemented();
}
