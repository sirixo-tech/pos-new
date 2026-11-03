/// Web has no desktop speech command. The caller uses the speech plugin.
Future<bool?> speakWithSystemVoice({
  required String phrase,
  required String language,
  required String speed,
  required double volume,
}) async =>
    null;

Future<void> stopSystemVoice() async {}
