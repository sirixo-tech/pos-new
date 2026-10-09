#include "windows_printer.h"

#include <windows.h>
#include <winspool.h>
#include <setupapi.h>
#include <devpropdef.h>
#include <flutter/standard_method_codec.h>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using flutter::EncodableValue;
using flutter::EncodableMap;

std::wstring Wide(const std::string& text) {
  const int size = MultiByteToWideChar(CP_UTF8, 0, text.data(),
      static_cast<int>(text.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
      result.data(), size);
  return result;
}

class PrinterHandle {
 public:
  HANDLE value = nullptr;
  ~PrinterHandle() { if (value) ClosePrinter(value); }
};

std::string Failure(const char* operation, DWORD error) {
  return std::string(operation) + " failed (Windows error " +
      std::to_string(error) + ").";
}

DWORD Status(HANDLE printer) {
  DWORD needed = 0;
  GetPrinterW(printer, 6, nullptr, 0, &needed);
  if (needed < sizeof(PRINTER_INFO_6)) {
    throw std::runtime_error(Failure("Printer status check", GetLastError()));
  }
  std::vector<uint8_t> buffer(needed);
  if (!GetPrinterW(printer, 6, buffer.data(), needed, &needed)) {
    throw std::runtime_error(Failure("Printer status check", GetLastError()));
  }
  return reinterpret_cast<const PRINTER_INFO_6*>(buffer.data())->dwStatus;
}

constexpr DWORD kOffline = PRINTER_STATUS_OFFLINE | PRINTER_STATUS_NOT_AVAILABLE;

bool UsbPortPresent(HANDLE printer) {
  DWORD needed = 0;
  GetPrinterW(printer, 2, nullptr, 0, &needed);
  if (needed < sizeof(PRINTER_INFO_2W)) {
    throw std::runtime_error(Failure("Printer port check", GetLastError()));
  }
  std::vector<uint8_t> info(needed);
  if (!GetPrinterW(printer, 2, info.data(), needed, &needed)) {
    throw std::runtime_error(Failure("Printer port check", GetLastError()));
  }
  const auto* port = reinterpret_cast<const PRINTER_INFO_2W*>(info.data())->pPortName;
  if (!port || _wcsnicmp(port, L"USB", 3) != 0) return true;
  wchar_t saved_device_path[2048]{};
  DWORD path_bytes = sizeof(saved_device_path);
  const auto monitor_key = std::wstring(
      L"SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\USB Monitor\\Ports\\") + port;
  // The USB monitor stores the exact device interface assigned to this port.
  // A stale registry mapping is useful only when that interface is present.
  RegGetValueW(HKEY_LOCAL_MACHINE, monitor_key.c_str(), L"Device Path",
      RRF_RT_REG_SZ, nullptr, saved_device_path, &path_bytes);

  // Match the queue's USB port to an active USB printer interface. An installed
  // spooler queue and its cached status survive physical unplugging.
  const GUID usbprint = {0x28d78fad, 0x5a12, 0x11d1,
      {0xae, 0x5b, 0x00, 0x00, 0xf8, 0x03, 0xa8, 0xc2}};
  const DEVPROPKEY port_property = {{0xeec7b761, 0x6f94, 0x41b1,
      {0x94, 0x9f, 0xc7, 0x29, 0x72, 0x0d, 0xd1, 0x3c}}, 12};
  const auto devices = SetupDiGetClassDevsW(&usbprint, nullptr, nullptr,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
  if (devices == INVALID_HANDLE_VALUE) {
    throw std::runtime_error("Unable to check physical USB printer connection.");
  }
  bool matched = false;
  SP_DEVICE_INTERFACE_DATA device{};
  device.cbSize = sizeof(device);
  for (DWORD index = 0; SetupDiEnumDeviceInterfaces(devices, nullptr, &usbprint,
      index, &device); ++index) {
    DWORD detail_bytes = 0;
    SetupDiGetDeviceInterfaceDetailW(devices, &device, nullptr, 0, &detail_bytes, nullptr);
    if (detail_bytes >= sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W)) {
      std::vector<uint8_t> detail_buffer(detail_bytes);
      auto* detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(detail_buffer.data());
      detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
      if (SetupDiGetDeviceInterfaceDetailW(devices, &device, detail, detail_bytes,
          nullptr, nullptr) && saved_device_path[0] &&
          _wcsicmp(detail->DevicePath, saved_device_path) == 0) {
        matched = true;
      }
    }
    wchar_t device_port[256]{};
    DEVPROPTYPE type = 0;
    if (SetupDiGetDeviceInterfacePropertyW(devices, &device, &port_property,
        &type, reinterpret_cast<PBYTE>(device_port), sizeof(device_port),
        nullptr, 0) && type == DEVPROP_TYPE_STRING &&
        _wcsicmp(port, device_port) == 0) {
      matched = true;
    }
    // USB monitor versions also expose the port in the interface registry key.
    const HKEY key = SetupDiOpenDeviceInterfaceRegKey(devices, &device, 0, KEY_READ);
    if (key != INVALID_HANDLE_VALUE) {
      DWORD bytes = sizeof(device_port);
      DWORD registry_type = 0;
      if (RegQueryValueExW(key, L"PortName", nullptr, &registry_type,
          reinterpret_cast<PBYTE>(device_port), &bytes) == ERROR_SUCCESS &&
          registry_type == REG_SZ && _wcsicmp(port, device_port) == 0) {
        matched = true;
      }
      RegCloseKey(key);
    }
  }
  const DWORD error = GetLastError();
  SetupDiDestroyDeviceInfoList(devices);
  if (error != ERROR_NO_MORE_ITEMS) {
    throw std::runtime_error("Unable to complete USB printer connection check.");
  }
  return matched;
}
}  // namespace

WindowsPrinter::WindowsPrinter(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "pos_main/windows_printer",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    const bool printing = call.method_name() == "printRaw";
    if (!printing && call.method_name() != "getStatus") {
      result->NotImplemented();
      return;
    }
    const auto* args = call.arguments()
        ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    const auto entry = args ? args->find(EncodableValue("name"))
        : EncodableMap::const_iterator{};
    const auto* name = args && entry != args->end()
        ? std::get_if<std::string>(&entry->second) : nullptr;
    if (!name || name->empty()) {
      result->Error("PRINTER_CONNECT", "Select a Windows printer queue.");
      return;
    }
    const std::vector<uint8_t>* bytes = nullptr;
    if (printing) {
      const auto data = args->find(EncodableValue("bytes"));
      if (data != args->end()) bytes = std::get_if<std::vector<uint8_t>>(&data->second);
      if (!bytes || bytes->empty() || bytes->size() > MAXDWORD) {
        result->Error("PRINTER_CONNECT", "Invalid printer payload.");
        return;
      }
    }
    PrinterHandle printer;
    auto wide_name = Wide(*name);
    if (!OpenPrinterW(wide_name.data(), &printer.value, nullptr)) {
      const DWORD error = GetLastError();
      if (!printing && error == ERROR_INVALID_PRINTER_NAME) {
        result->Success(EncodableValue(EncodableMap{
            {EncodableValue("present"), EncodableValue(false)},
            {EncodableValue("offline"), EncodableValue(true)},
            {EncodableValue("paperOut"), EncodableValue(false)},
        }));
      } else {
        result->Error(printing ? "PRINTER_CONNECT" : "PRINTER_STATUS",
            Failure("Open printer queue", error));
      }
      return;
    }
    DWORD status;
    try {
      status = Status(printer.value);
      if (!UsbPortPresent(printer.value)) status |= PRINTER_STATUS_OFFLINE;
    } catch (const std::exception& error) {
      result->Error(printing ? "PRINTER_CONNECT" : "PRINTER_STATUS", error.what());
      return;
    }
    if (!printing) {
      result->Success(EncodableValue(EncodableMap{
          {EncodableValue("present"), EncodableValue(true)},
          {EncodableValue("physicalUsbChecked"), EncodableValue(true)},
          {EncodableValue("offline"), EncodableValue((status & kOffline) != 0)},
          {EncodableValue("paperOut"), EncodableValue((status & PRINTER_STATUS_PAPER_OUT) != 0)},
      }));
      return;
    }
    if ((status & (kOffline | PRINTER_STATUS_PAPER_OUT)) != 0) {
      result->Error("PRINTER_CONNECT", (status & PRINTER_STATUS_PAPER_OUT)
          ? "Printer paper out. Replace the roll."
          : "Windows reports the printer offline. Check the USB connection.");
      return;
    }
    DOC_INFO_1W document{};
    wchar_t title[] = L"SelfX POS receipt";
    wchar_t datatype[] = L"RAW";
    document.pDocName = title;
    document.pDatatype = datatype;
    const DWORD job = StartDocPrinterW(printer.value, 1,
        reinterpret_cast<LPBYTE>(&document));
    if (!job) {
      result->Error("PRINTER_CONNECT", Failure("Start print job", GetLastError()));
      return;
    }
    // Once a spooler job exists, never automatically resend on a failure.
    DWORD written = 0;
    std::string error;
    if (!StartPagePrinter(printer.value)) {
      error = Failure("Start print page", GetLastError());
    } else if (!WritePrinter(printer.value, const_cast<uint8_t*>(bytes->data()),
        static_cast<DWORD>(bytes->size()), &written)) {
      error = Failure("Write printer", GetLastError());
    } else if (written != bytes->size()) {
      error = "Printer accepted only part of the receipt.";
    } else if (!EndPagePrinter(printer.value)) {
      error = Failure("End print page", GetLastError());
    } else if (!EndDocPrinter(printer.value)) {
      error = Failure("Finish print job", GetLastError());
    }
    if (!error.empty()) {
      AbortPrinter(printer.value);
      result->Error("PRINTER_WRITE", error);
      return;
    }
    result->Success(EncodableValue(static_cast<int64_t>(job)));
  });
}
