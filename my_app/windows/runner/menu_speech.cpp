#include "menu_speech.h"
#include <flutter/standard_method_codec.h>
#include <string>

namespace {
std::wstring Wide(const std::string& text) {
  const int length = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                        static_cast<int>(text.size()), nullptr, 0);
  std::wstring converted(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      converted.data(), length);
  return converted;
}
std::string Utf8(const wchar_t* text) {
  const int length = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  std::string converted(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, converted.data(), length, nullptr, nullptr);
  if (!converted.empty()) converted.pop_back();
  return converted;
}
}

MenuSpeech::MenuSpeech(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window), channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "selfx/menu_speech", &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "stop") {
      Stop();
      result->Success();
    } else if (call.method_name() == "listen") {
      const auto* args = call.arguments()
          ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
      if (!args) { result->Error("MENU_SPEECH", "Menu vocabulary is required."); return; }
      const auto found = args->find(flutter::EncodableValue("words"));
      const auto* words = found == args->end() ? nullptr
          : std::get_if<flutter::EncodableList>(&found->second);
      if (!words || !Listen(*words)) {
        Stop();
        result->Error("MENU_SPEECH", "Could not activate menu speech recognition.");
        return;
      }
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });
}

MenuSpeech::~MenuSpeech() { Stop(); }

bool MenuSpeech::Listen(const flutter::EncodableList& words) {
  Stop();
  if (words.empty()) return false;
  if (FAILED(CoCreateInstance(CLSID_SpInprocRecognizer, nullptr, CLSCTX_INPROC_SERVER,
      IID_ISpRecognizer, reinterpret_cast<void**>(recognizer_.GetAddressOf())))) return false;
  if (FAILED(CoCreateInstance(CLSID_SpMMAudioIn, nullptr, CLSCTX_INPROC_SERVER,
      IID_ISpAudio, reinterpret_cast<void**>(audio_.GetAddressOf())))) return false;
  if (FAILED(recognizer_->SetInput(audio_.Get(), TRUE))) return false;
  if (FAILED(recognizer_->CreateRecoContext(context_.GetAddressOf()))) return false;
  const ULONGLONG events = SPFEI(SPEI_RECOGNITION) | SPFEI(SPEI_HYPOTHESIS);
  if (FAILED(context_->SetInterest(events, events))) return false;
  if (FAILED(context_->CreateGrammar(1, grammar_.GetAddressOf()))) return false;
  SPRECOGNIZERSTATUS status{};
  if (FAILED(recognizer_->GetStatus(&status)) || status.cLangIDs == 0 ||
      FAILED(grammar_->ResetGrammar(status.aLangID[0]))) return false;
  SPSTATEHANDLE rule = nullptr;
  if (FAILED(grammar_->GetRule(L"menu", 0, SPRAF_TopLevel | SPRAF_Dynamic, TRUE, &rule))) return false;
  int added = 0;
  for (const auto& value : words) {
    const auto* word = std::get_if<std::string>(&value);
    if (!word || word->empty()) continue;
    const auto phrase = Wide(*word);
    if (SUCCEEDED(grammar_->AddWordTransition(rule, nullptr, phrase.c_str(), L" ",
                                          SPWT_LEXICAL, 1.0f, nullptr))) ++added;
  }
  if (added == 0) return false;
  // Use menu rules exclusively; unrestricted English dictation is never loaded.
  if (FAILED(grammar_->Commit(0))) return false;
  if (FAILED(grammar_->SetRuleState(L"menu", nullptr, SPRS_ACTIVE))) return false;
  if (FAILED(recognizer_->SetRecoState(SPRST_ACTIVE_ALWAYS))) return false;
  return SetTimer(window_, kTimer, 50, nullptr) != 0;
}

void MenuSpeech::Stop() {
  KillTimer(window_, kTimer);
  if (grammar_) grammar_->SetRuleState(nullptr, nullptr, SPRS_INACTIVE);
  if (recognizer_) recognizer_->SetRecoState(SPRST_INACTIVE_WITH_PURGE);
  grammar_.Reset();
  context_.Reset();
  recognizer_.Reset();
  audio_.Reset();
}

bool MenuSpeech::HandleMessage(UINT message, WPARAM wparam) {
  if (message != WM_TIMER || wparam != kTimer) return false;
  Poll();
  return true;
}

void MenuSpeech::Poll() {
  if (!context_) return;
  SPEVENT event{};
  ULONG fetched = 0;
  // Bound work per frame so speech cannot starve the POS UI.
  for (int count = 0; count < 16 && SUCCEEDED(context_->GetEvents(1, &event, &fetched)) && fetched; ++count) {
    if (event.eEventId == SPEI_RECOGNITION || event.eEventId == SPEI_HYPOTHESIS) {
      auto* recognized = reinterpret_cast<ISpRecoResult*>(event.lParam);
      SPPHRASE* phrase = nullptr;
      wchar_t* text = nullptr;
      const bool final = event.eEventId == SPEI_RECOGNITION;
      const bool confident = recognized && SUCCEEDED(recognized->GetPhrase(&phrase)) &&
          phrase && phrase->Rule.Confidence > SP_LOW_CONFIDENCE;
      if (confident && SUCCEEDED(recognized->GetText(0, static_cast<ULONG>(SP_GETWHOLEPHRASE), TRUE, &text, nullptr)) && text) {
        channel_->InvokeMethod("result", std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
          {flutter::EncodableValue("words"), flutter::EncodableValue(Utf8(text))},
          {flutter::EncodableValue("final"), flutter::EncodableValue(final)},
        }));
      }
      CoTaskMemFree(phrase);
      CoTaskMemFree(text);
    }
    if (event.elParamType == SPET_LPARAM_IS_OBJECT && event.lParam) {
      reinterpret_cast<IUnknown*>(event.lParam)->Release();
    }
    event = {};
    fetched = 0;
  }
}
