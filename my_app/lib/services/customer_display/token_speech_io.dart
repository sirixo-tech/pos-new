import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

Process? _windowsVoice;
StreamSubscription<List<int>>? _windowsBytes;
final StringBuffer _windowsBuffer = StringBuffer();
final List<Completer<String>> _windowsWaiters = [];
Future<void> _windowsChain = Future<void>.value();

/// Speaks with the operating-system voice on desktop.
///
/// Returns true when the phrase was spoken, false when the command failed,
/// and null when this platform should use the speech plugin instead.
Future<bool?> speakWithSystemVoice({
  required String phrase,
  required String language,
  required String speed,
  required double volume,
}) {
  if (Platform.isAndroid || Platform.isIOS) return Future.value(null);
  final run = _windowsChain.then((_) async {
    if (Platform.isWindows) {
      return _speakWindows(phrase, language, speed, volume);
    }
    if (Platform.isMacOS) return _speakMac(phrase, language, speed);
    if (Platform.isLinux) return _speakLinux(phrase, language, speed, volume);
    return null;
  });
  _windowsChain = run.then((_) {}, onError: (_) {});
  return run;
}

Future<void> stopSystemVoice() async {
  final process = _windowsVoice;
  _windowsVoice = null;
  await _windowsBytes?.cancel();
  _windowsBytes = null;
  _windowsBuffer.clear();
  for (final waiter in _windowsWaiters) {
    if (!waiter.isCompleted) waiter.complete('STOPPED');
  }
  _windowsWaiters.clear();
  if (process == null) return;
  process.kill();
  try {
    await process.exitCode.timeout(const Duration(seconds: 1));
  } catch (_) {}
}

Future<bool> _speakWindows(
  String phrase,
  String language,
  String speed,
  double volume,
) async {
  final process = await _ensureWindows();
  if (process == null) return false;
  final lang = await _command('##LANG ${_culture(language)}');
  final spoken = lang == 'MISS' && language.toLowerCase().startsWith('hi')
      ? _englishFallback(phrase)
      : phrase;
  await _command('##VOL ${(volume * 100).round().clamp(1, 100)}');
  await _command('##RATE ${_windowsRate(speed)}');
  final result = await _command('##SAY ${base64Encode(utf8.encode(spoken))}');
  return result == 'OK';
}

Future<Process?> _ensureWindows() async {
  final current = _windowsVoice;
  if (current != null) return current;
  try {
    final process = await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-STA',
        '-OutputFormat',
        'Text',
        '-Command',
        _windowsSpeakerScript,
      ],
    );
    _windowsVoice = process;
    _windowsBytes = process.stdout.listen((bytes) {
      final text = utf8
          .decode(bytes, allowMalformed: true)
          .replaceAll('\u0000', '')
          .replaceAll('\uFEFF', '');
      _windowsBuffer.write(text);
      final pending = _windowsBuffer.toString();
      final lines = pending.split('\n');
      _windowsBuffer
        ..clear()
        ..write(lines.last);
      for (final raw in lines.take(lines.length - 1)) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty || _windowsWaiters.isEmpty) continue;
        final waiter = _windowsWaiters.removeAt(0);
        if (!waiter.isCompleted) waiter.complete(trimmed);
      }
    });
    unawaited(process.stderr.drain());
    unawaited(process.exitCode.then((_) {
      if (identical(_windowsVoice, process)) _windowsVoice = null;
    }));
    final ready = await _command('##PING').timeout(const Duration(seconds: 12));
    if (ready != 'READY' && ready != 'OK') {
      await stopSystemVoice();
      return null;
    }
    return process;
  } catch (error) {
    debugPrint('[TokenSpeech] Windows voice: $error');
    await stopSystemVoice();
    return null;
  }
}

Future<String> _command(String line) async {
  final process = _windowsVoice;
  if (process == null) return 'GONE';
  final waiter = Completer<String>();
  _windowsWaiters.add(waiter);
  try {
    process.stdin.writeln(line);
    await process.stdin.flush();
  } catch (_) {
    if (!waiter.isCompleted) waiter.complete('GONE');
    return 'GONE';
  }
  try {
    return await waiter.future.timeout(const Duration(seconds: 20));
  } catch (_) {
    return 'TIMEOUT';
  }
}

Future<bool> _speakMac(String phrase, String language, String speed) async {
  final voice = await _macVoice(language);
  final args = <String>[
    '-r',
    _macRate(speed),
    if (voice != null) ...['-v', voice],
    phrase,
  ];
  var result = await Process.run('say', args);
  if (result.exitCode != 0 && voice != null) {
    result = await Process.run('say', ['-r', _macRate(speed), phrase]);
  }
  return result.exitCode == 0;
}

String? _macVoiceName;
String? _macVoiceLanguage;

Future<String?> _macVoice(String language) async {
  if (_macVoiceLanguage == language) return _macVoiceName;
  _macVoiceLanguage = language;
  if (!language.toLowerCase().startsWith('hi')) {
    _macVoiceName = null;
    return null;
  }
  try {
    final listed = await Process.run('say', const ['-v', '?']);
    final text = '${listed.stdout}';
    final match = RegExp(r'^(\S+)\s+hi_', multiLine: true).firstMatch(text);
    _macVoiceName = match?.group(1);
  } catch (_) {
    _macVoiceName = null;
  }
  return _macVoiceName;
}

Future<bool> _speakLinux(
  String phrase,
  String language,
  String speed,
  double volume,
) async {
  final wpm = _linuxRate(speed);
  final amp = (volume * 200).round().clamp(20, 200).toString();
  final voice = language.toLowerCase().startsWith('hi') ? 'hi' : 'en';
  final attempts = <List<String>>[
    ['spd-say', '-w', '-l', voice, '-r', _spdRate(speed), phrase],
    ['espeak-ng', '-v', voice, '-s', wpm, '-a', amp, phrase],
    ['espeak', '-v', voice, '-s', wpm, '-a', amp, phrase],
  ];
  for (final command in attempts) {
    try {
      final result = await Process.run(command.first, command.sublist(1));
      if (result.exitCode == 0) return true;
    } catch (_) {}
  }
  return false;
}

String _culture(String language) {
  final code = language.trim();
  if (code.isEmpty) return 'en-US';
  return code;
}

String _englishFallback(String phrase) {
  final number = RegExp(r'\d+').firstMatch(phrase)?.group(0);
  if (number == null) return 'Token number ready';
  return 'Token number $number ready';
}

String _windowsRate(String speed) {
  return switch (speed) {
    'slow' => '-2',
    'fast' => '2',
    _ => '0',
  };
}

String _macRate(String speed) {
  return switch (speed) {
    'slow' => '140',
    'fast' => '210',
    _ => '175',
  };
}

String _linuxRate(String speed) {
  return switch (speed) {
    'slow' => '120',
    'fast' => '190',
    _ => '150',
  };
}

String _spdRate(String speed) {
  return switch (speed) {
    'slow' => '-20',
    'fast' => '20',
    _ => '0',
  };
}

const _windowsSpeakerScript = r'''
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$OutputEncoding = [Console]::OutputEncoding = [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Volume = 100
$synth.Rate = 0
function Write-Reply([string]$text) {
  [Console]::Out.WriteLine($text)
  [Console]::Out.Flush()
}
while ($true) {
  $line = [Console]::In.ReadLine()
  if ([string]::IsNullOrEmpty($line)) { continue }
  if ($line -eq '##EXIT') { break }
  if ($line -eq '##PING') { Write-Reply 'READY'; continue }
  if ($line.StartsWith('##VOL ')) {
    $synth.Volume = [Math]::Max(1, [Math]::Min(100, [int]$line.Substring(6)))
    Write-Reply 'OK'
    continue
  }
  if ($line.StartsWith('##RATE ')) {
    $synth.Rate = [Math]::Max(-10, [Math]::Min(10, [int]$line.Substring(7)))
    Write-Reply 'OK'
    continue
  }
  if ($line.StartsWith('##LANG ')) {
    $code = $line.Substring(7).Trim()
    $prefix = $code.Split('-')[0]
    $matched = $false
    foreach ($installed in $synth.GetInstalledVoices()) {
      if (-not $installed.Enabled) { continue }
      $name = $installed.VoiceInfo.Culture.Name
      if ($name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $matched = $true
        break
      }
    }
    if ($matched) {
      try {
        $culture = [System.Globalization.CultureInfo]::new($code)
        $synth.SelectVoiceByHints(
          [System.Speech.Synthesis.VoiceGender]::NotSet,
          [System.Speech.Synthesis.VoiceAge]::NotSet,
          0,
          $culture)
      } catch {}
      Write-Reply 'OK'
    } else {
      Write-Reply 'MISS'
    }
    continue
  }
  if ($line.StartsWith('##SAY ')) {
    try {
      $bytes = [Convert]::FromBase64String($line.Substring(6).Trim())
      $text = [System.Text.Encoding]::UTF8.GetString($bytes)
      $synth.Speak($text)
      Write-Reply 'OK'
    } catch {
      Write-Reply 'ERR'
    }
    continue
  }
  Write-Reply 'ERR'
}
''';
