#include "scanner_status.h"
#include <windows.h>
#include <setupapi.h>
#include <devpropdef.h>
#include <algorithm>
#include <cwctype>
#include <stdexcept>
#include <vector>

bool IsScannerDescription(const std::wstring& description) {
  auto lower = description;
  std::transform(lower.begin(), lower.end(), lower.begin(),
      [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  const wchar_t* terms[] = {L"scanner", L"barcode", L"bar code", L"honeywell",
      L"datalogic", L"newland", L"symbol", L"zebra", L"retsol",
      L"opticon", L"optipos", L"socket mobile", L"cipherlab",
      L"unitech", L"sunmi scanner", L"code reader", L"bar-code",
      L"2d reader", L"1d reader"};
  for (const auto* term : terms) {
    if (lower.find(term) != std::wstring::npos) return true;
  }
  return false;
}

flutter::EncodableMap ScannerStatus() {
  // Keyboard-wedge scanners and ordinary keyboards share the HID keyboard
  // interface. Only scanner descriptions or barcode usages prove presence.
  int scanners = 0;
  const auto devices = SetupDiGetClassDevsW(nullptr, nullptr, nullptr,
      DIGCF_PRESENT | DIGCF_ALLCLASSES);
  if (devices == INVALID_HANDLE_VALUE) {
    throw std::runtime_error("Unable to enumerate scanner devices.");
  }
  // DEVPKEY_Device_BusReportedDeviceDesc from the Windows SDK devpkey.h.
  const DEVPROPKEY bus_description = {
      {0x540b947e, 0x8b40, 0x45bc, {0xa8, 0xa2, 0x6a, 0x0b, 0x89, 0x4c, 0xbd, 0xa2}}, 4};
  SP_DEVINFO_DATA device{};
  device.cbSize = sizeof(device);
  for (DWORD index = 0; SetupDiEnumDeviceInfo(devices, index, &device); ++index) {
    std::wstring description;
    wchar_t buffer[1024]{};
    for (DWORD property : {SPDRP_FRIENDLYNAME, SPDRP_DEVICEDESC}) {
      if (SetupDiGetDeviceRegistryPropertyW(devices, &device, property, nullptr,
          reinterpret_cast<PBYTE>(buffer), sizeof(buffer), nullptr)) {
        description += buffer;
        description += L" ";
      }
    }
    DEVPROPTYPE type = 0;
    if (SetupDiGetDevicePropertyW(devices, &device, &bus_description, &type,
        reinterpret_cast<PBYTE>(buffer), sizeof(buffer), nullptr, 0) &&
        type == DEVPROP_TYPE_STRING) {
      description += buffer;
    }
    if (IsScannerDescription(description)) ++scanners;
  }
  const auto enumeration_error = GetLastError();
  SetupDiDestroyDeviceInfoList(devices);
  if (enumeration_error != ERROR_NO_MORE_ITEMS) {
    throw std::runtime_error("Unable to complete scanner enumeration.");
  }
  UINT count = 0;
  bool keyboard = false;
  if (GetRawInputDeviceList(nullptr, &count, sizeof(RAWINPUTDEVICELIST)) ==
      static_cast<UINT>(-1)) {
    throw std::runtime_error("Unable to enumerate input devices.");
  }
  std::vector<RAWINPUTDEVICELIST> inputs(count);
  if (count > 0 && GetRawInputDeviceList(inputs.data(), &count,
      sizeof(RAWINPUTDEVICELIST)) == static_cast<UINT>(-1)) {
    throw std::runtime_error("Unable to enumerate input devices.");
  }
  int barcode_inputs = 0;
  for (UINT i = 0; i < count; ++i) {
    if (inputs[i].dwType == RIM_TYPEKEYBOARD) keyboard = true;
    if (inputs[i].dwType != RIM_TYPEHID) continue;
    RID_DEVICE_INFO info{};
    info.cbSize = sizeof(info);
    UINT size = sizeof(info);
    if (GetRawInputDeviceInfoW(inputs[i].hDevice, RIDI_DEVICEINFO, &info,
        &size) != static_cast<UINT>(-1) && info.hid.usUsagePage == 0x8c) {
      ++barcode_inputs;
    }
  }
  const int detected = scanners > 0 ? scanners : barcode_inputs;
  return {
    {flutter::EncodableValue("connected"), flutter::EncodableValue(detected > 0)},
    {flutter::EncodableValue("deviceCount"), flutter::EncodableValue(detected)},
    {flutter::EncodableValue("hasHardwareKeyboard"), flutter::EncodableValue(keyboard)},
  };
}
