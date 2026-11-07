import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pos_cart_sound.dart';
import 'token_speech.dart';

/// Spoken line when a token becomes ready. English matches the counter call
/// "token number 4 ready". Hindi uses the same number with a Hindi voice.
String tokenReadyPhrase(String token, String languageCode) {
  final spoken = token.trim();
  if (languageCode.toLowerCase().startsWith('hi')) {
    return 'टोकन नंबर $spoken तैयार है';
  }
  return 'Token number $spoken ready';
}

class TokenVoiceLanguage {
  const TokenVoiceLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// Device-local sounds for the open token display.
///
/// A new preparing token plays a short chime. A token that moves to Ready is
/// spoken. Nothing plays unless that screen is the one currently open.
class CustomerVoiceService {
  CustomerVoiceService._();

  static final CustomerVoiceService instance = CustomerVoiceService._();

  static const languages = <TokenVoiceLanguage>[
    TokenVoiceLanguage('en-IN', 'English (India)'),
    TokenVoiceLanguage('en-US', 'English (US)'),
    TokenVoiceLanguage('hi-IN', 'Hindi'),
  ];

  static const _legacyEnabledKey = 'customer_voice_announcements_enabled';
  static const _newEnabledKey = 'token_display_new_sound_enabled';
  static const _newToneKey = 'token_display_new_tone';
  static const _newVolumeKey = 'token_display_new_volume';
  static const _readyEnabledKey = 'token_display_ready_voice_enabled';
  static const _repeatsKey = 'token_display_ready_repeats';
  static const _speedKey = 'token_display_speech_speed';
  static const _pitchKey = 'token_display_speech_pitch';
  static const _readyVolumeKey = 'token_display_ready_volume';
  static const _languageKey = 'token_display_voice_language';

  bool _screenActive = false;
  bool _processing = false;
  bool _pluginReady = false;
  int _generation = 0;
  FlutterTts? _tts;
  final List<_Cue> _queue = [];

  bool newTokenSoundEnabled = false;
  String newTokenTone = 'ticket_ding';
  double newTokenVolume = 1;
  bool readyVoiceEnabled = true;
  int readyRepeats = 1;
  String speechSpeed = 'normal';
  String speechPitch = 'normal';
  double readyVolume = 1;
  String languageCode = 'en-IN';

  bool get isCustomerScreenActive => _screenActive;

  /// True when either token-display sound is switched on.
  bool get isEnabled => newTokenSoundEnabled || readyVoiceEnabled;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getBool(_legacyEnabledKey);
      newTokenSoundEnabled = prefs.getBool(_newEnabledKey) ?? false;
      readyVoiceEnabled = prefs.getBool(_readyEnabledKey) ?? legacy ?? true;
      final tone = prefs.getString(_newToneKey) ?? 'ticket_ding';
      newTokenTone = PosCartSound.kitchenTones.containsKey(tone)
          ? tone
          : 'ticket_ding';
      newTokenVolume = _volume(prefs.getDouble(_newVolumeKey) ?? 1);
      readyRepeats = _repeats(prefs.getInt(_repeatsKey) ?? 1);
      speechSpeed = _oneOf(prefs.getString(_speedKey), const [
        'slow',
        'normal',
        'fast',
      ], 'normal');
      speechPitch = _oneOf(prefs.getString(_pitchKey), const [
        'low',
        'normal',
        'high',
      ], 'normal');
      readyVolume = _volume(prefs.getDouble(_readyVolumeKey) ?? 1);
      final language = prefs.getString(_languageKey) ?? 'en-IN';
      languageCode = languages.any((item) => item.code == language)
          ? language
          : 'en-IN';
    } catch (_) {}
  }

  Future<void> setNewTokenSoundEnabled(bool value) async {
    newTokenSoundEnabled = value;
    await _save((prefs) => prefs.setBool(_newEnabledKey, value));
    if (!value) _dropChimes();
  }

  Future<void> setNewTokenTone(String tone) async {
    if (!PosCartSound.kitchenTones.containsKey(tone)) return;
    newTokenTone = tone;
    await _save((prefs) => prefs.setString(_newToneKey, tone));
  }

  Future<void> setNewTokenVolume(double value) async {
    newTokenVolume = _volume(value);
    await _save((prefs) => prefs.setDouble(_newVolumeKey, newTokenVolume));
  }

  Future<void> setReadyVoiceEnabled(bool value) async {
    readyVoiceEnabled = value;
    await _save((prefs) => prefs.setBool(_readyEnabledKey, value));
    if (!value) {
      _queue.removeWhere((cue) => cue is _Speak);
      unawaited(_tts?.stop());
    }
  }

  Future<void> setReadyRepeats(int value) async {
    readyRepeats = _repeats(value);
    await _save((prefs) => prefs.setInt(_repeatsKey, readyRepeats));
  }

  Future<void> setSpeechSpeed(String value) async {
    speechSpeed = _oneOf(value, const ['slow', 'normal', 'fast'], 'normal');
    await _save((prefs) => prefs.setString(_speedKey, speechSpeed));
  }

  Future<void> setSpeechPitch(String value) async {
    speechPitch = _oneOf(value, const ['low', 'normal', 'high'], 'normal');
    await _save((prefs) => prefs.setString(_pitchKey, speechPitch));
  }

  Future<void> setReadyVolume(double value) async {
    readyVolume = _volume(value);
    await _save((prefs) => prefs.setDouble(_readyVolumeKey, readyVolume));
  }

  Future<void> setLanguageCode(String value) async {
    if (!languages.any((item) => item.code == value)) return;
    languageCode = value;
    await _save((prefs) => prefs.setString(_languageKey, value));
  }

  void setCustomerScreenActive(bool active) {
    _screenActive = active;
    if (!active) _stopAndClear();
  }

  /// One notification chime for tokens that just appeared under Preparing.
  void playNewTokenChime() {
    if (!_screenActive || !newTokenSoundEnabled) return;
    if (_queue.any((cue) => cue is _Chime)) return;
    _queue.add(const _Chime());
    unawaited(_processNext());
  }

  void announceReadyToken(Object token) {
    final tokenStr = token.toString().trim();
    if (tokenStr.isEmpty || !_screenActive || !readyVoiceEnabled) return;
    if (_queue.any((cue) => cue is _Speak && cue.token == tokenStr)) return;
    _queue.add(_Speak(tokenStr));
    unawaited(_processNext());
  }

  Future<void> previewNewToken() async {
    await PosCartSound.instance.playTone(newTokenTone, volume: newTokenVolume);
  }

  Future<void> previewReadyVoice() async {
    await _speak(
      tokenReadyPhrase('4', languageCode),
      volume: readyVolume,
      speed: speechSpeed,
      pitch: speechPitch,
      language: languageCode,
    );
  }

  Future<void> _processNext() async {
    if (_processing || !_screenActive || _queue.isEmpty) return;
    _processing = true;
    final generation = _generation;
    final cue = _queue.removeAt(0);
    try {
      if (cue is _Chime) {
        if (newTokenSoundEnabled) {
          await PosCartSound.instance.playTone(
            newTokenTone,
            volume: newTokenVolume,
          );
        }
      } else if (cue is _Speak && readyVoiceEnabled) {
        final phrase = tokenReadyPhrase(cue.token, languageCode);
        for (var pass = 0; pass < readyRepeats; pass++) {
          if (!_screenActive ||
              !readyVoiceEnabled ||
              generation != _generation) {
            break;
          }
          final spoke = await _speak(
            phrase,
            volume: readyVolume,
            speed: speechSpeed,
            pitch: speechPitch,
            language: languageCode,
          );
          if (!spoke) {
            await PosCartSound.instance.playTone(
              'expo_bell',
              volume: readyVolume,
            );
            break;
          }
          if (pass + 1 < readyRepeats) {
            await Future<void>.delayed(const Duration(milliseconds: 450));
          }
        }
      }
    } catch (error) {
      debugPrint('[CustomerVoice] $error');
    }
    _processing = false;
    if (_queue.isNotEmpty && _screenActive && generation == _generation) {
      await _processNext();
    }
  }

  Future<bool> _speak(
    String phrase, {
    required double volume,
    required String speed,
    required String pitch,
    required String language,
  }) async {
    bool? system;
    try {
      system = await speakWithSystemVoice(
        phrase: phrase,
        language: language,
        speed: speed,
        volume: volume,
      );
    } catch (error) {
      debugPrint('[CustomerVoice] system voice: $error');
      system = false;
    }
    if (system == true) return true;
    return _speakWithPlugin(
      phrase,
      volume: volume,
      speed: speed,
      pitch: pitch,
      language: language,
    );
  }

  Future<bool> _speakWithPlugin(
    String phrase, {
    required double volume,
    required String speed,
    required String pitch,
    required String language,
  }) async {
    try {
      final tts = _tts ??= FlutterTts();
      await _preparePlugin(tts);
      final spoken = await _phraseForDevice(tts, phrase, language);
      await tts.setSpeechRate(_rate(speed));
      await tts.setVolume(_volume(volume));
      try {
        await tts.setPitch(_pitch(pitch));
      } catch (_) {}
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await tts.setAudioAttributesForNavigation();
        } catch (_) {}
      }
      final finished = Completer<void>();
      tts.setCompletionHandler(() {
        if (!finished.isCompleted) finished.complete();
      });
      tts.setErrorHandler((_) {
        if (!finished.isCompleted) finished.complete();
      });
      var accepted = await _pluginSpeak(tts, spoken);
      if (!accepted) {
        try {
          await tts.stop();
        } catch (_) {}
        accepted = await _pluginSpeak(tts, spoken);
      }
      if (!accepted) return false;
      await finished.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      return true;
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('[CustomerVoice] speak: $error');
      return false;
    }
  }

  Future<void> _preparePlugin(FlutterTts tts) async {
    if (_pluginReady) return;
    _pluginReady = true;
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }
  }

  Future<bool> _pluginSpeak(FlutterTts tts, String phrase) async {
    final result = await tts.speak(phrase, focus: true);
    return result != 0 && result != false && result != '0';
  }

  Future<String> _phraseForDevice(
    FlutterTts tts,
    String phrase,
    String language,
  ) async {
    var installed = const <String>[];
    try {
      final raw = await tts.getLanguages;
      if (raw is List) installed = raw.map((item) => '$item').toList();
    } catch (_) {}
    final hindi = language.toLowerCase().startsWith('hi');
    final hasHindi = installed.any(
      (item) => item.toLowerCase().replaceAll('_', '-').startsWith('hi'),
    );
    final spoken = hindi && installed.isNotEmpty && !hasHindi
        ? _englishOf(phrase)
        : phrase;
    final locale = _bestLocale(installed, language) ??
        _bestLocale(installed, 'en-US') ??
        _bestLocale(installed, 'en');
    try {
      await tts.setLanguage(locale ?? language);
    } catch (_) {
      try {
        await tts.setLanguage('en-US');
      } catch (_) {}
    }
    return spoken;
  }

  void _dropChimes() => _queue.removeWhere((cue) => cue is _Chime);

  void _stopAndClear() {
    _generation++;
    _queue.clear();
    _processing = false;
    unawaited(stopSystemVoice());
    unawaited(_tts?.stop());
  }

  void dispose() => _stopAndClear();

  Future<void> _save(Future<void> Function(SharedPreferences prefs) write) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {}
  }
}

sealed class _Cue {
  const _Cue();
}

class _Chime extends _Cue {
  const _Chime();
}

class _Speak extends _Cue {
  const _Speak(this.token);

  final String token;
}

double _volume(double value) => value.clamp(0.2, 1.0).toDouble();

int _repeats(int value) => value.clamp(1, 3);

String _oneOf(String? value, List<String> allowed, String fallback) {
  return value != null && allowed.contains(value) ? value : fallback;
}

double _rate(String speed) {
  return switch (speed) {
    'slow' => 0.4,
    'fast' => 0.62,
    _ => 0.5,
  };
}

double _pitch(String pitch) {
  return switch (pitch) {
    'low' => 0.85,
    'high' => 1.15,
    _ => 1,
  };
}

String? _bestLocale(List<String> installed, String wanted) {
  if (installed.isEmpty) return null;
  final needle = wanted.toLowerCase().replaceAll('_', '-');
  for (final locale in installed) {
    if (locale.toLowerCase().replaceAll('_', '-') == needle) return locale;
  }
  final prefix = needle.split('-').first;
  for (final locale in installed) {
    if (locale.toLowerCase().replaceAll('_', '-').startsWith(prefix)) {
      return locale;
    }
  }
  return null;
}

String _englishOf(String phrase) {
  final number = RegExp(r'\d+').firstMatch(phrase)?.group(0);
  if (number == null) return 'Token number ready';
  return 'Token number $number ready';
}
