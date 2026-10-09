#pragma once
#include <flutter/encodable_value.h>
#include <string>

bool IsScannerDescription(const std::wstring& description);
flutter::EncodableMap ScannerStatus();
