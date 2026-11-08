import 'package:flutter/material.dart';

import '../../l10n/pos_l10n.dart';
import '../../services/customer_display/customer_voice_service.dart';
import '../../services/pos_auto_start.dart';
import '../../services/pos_cart_sound.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';

Future<void> showTokenDisplaySoundDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _TokenDisplaySoundDialog(),
  );
}

class _TokenDisplaySoundDialog extends StatefulWidget {
  const _TokenDisplaySoundDialog();

  @override
  State<_TokenDisplaySoundDialog> createState() =>
      _TokenDisplaySoundDialogState();
}

class _TokenDisplaySoundDialogState extends State<_TokenDisplaySoundDialog> {
  String? _playing;
  bool _ready = false;

  CustomerVoiceService get _voice => CustomerVoiceService.instance;

  @override
  void initState() {
    super.initState();
    _voice.loadSettings().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final voice = _voice;

    return PosDialogShell(
      title: 'Token display settings',
      subtitle: 'Audio announcements and device startup options.',
      icon: Icons.tune_rounded,
      maxWidth: 480,
      onClose: () => Navigator.pop(context),
      body: SizedBox(
        height: 560,
        child: _ready
            ? ListView(
                children: [
                  _sectionTitle('New token'),
                  const SizedBox(height: 4),
                  Text(
                    'A short chime when a token first appears under Preparing.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _switchTile(
                    soft: soft,
                    title: 'New token chime',
                    value: voice.newTokenSoundEnabled,
                    onChanged: (value) async {
                      await voice.setNewTokenSoundEnabled(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _volume(
                    label: 'Chime volume',
                    value: voice.newTokenVolume,
                    enabled: voice.newTokenSoundEnabled,
                    onChanged: (value) =>
                        setState(() => voice.newTokenVolume = value),
                    onChangeEnd: (value) async {
                      await voice.setNewTokenVolume(value);
                      await _previewChime();
                    },
                  ),
                  const SizedBox(height: 8),
                  for (final entry in PosCartSound.kitchenTones.entries)
                    _ToneTile(
                      title: entry.value,
                      selected: voice.newTokenTone == entry.key,
                      playing: _playing == entry.key,
                      enabled: voice.newTokenSoundEnabled,
                      onTap: () async {
                        await voice.setNewTokenTone(entry.key);
                        if (mounted) setState(() => _playing = entry.key);
                        await voice.previewNewToken();
                        if (mounted) setState(() => _playing = null);
                      },
                    ),
                  const SizedBox(height: 16),
                  _sectionTitle('Ready to collect'),
                  const SizedBox(height: 4),
                  Text(
                    'Speaks the token when it moves to Ready. Token 4 is announced as “Token number 4 ready”.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _switchTile(
                    soft: soft,
                    title: 'Ready announcement',
                    value: voice.readyVoiceEnabled,
                    onChanged: (value) async {
                      await voice.setReadyVoiceEnabled(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _choice(
                    label: 'Repeat',
                    enabled: voice.readyVoiceEnabled,
                    value: '${voice.readyRepeats}',
                    options: const {'1': 'Once', '2': 'Twice', '3': 'Three times'},
                    onChanged: (value) async {
                      await voice.setReadyRepeats(int.parse(value));
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _choice(
                    label: 'Speed',
                    enabled: voice.readyVoiceEnabled,
                    value: voice.speechSpeed,
                    options: const {
                      'slow': 'Slow',
                      'normal': 'Normal',
                      'fast': 'Fast',
                    },
                    onChanged: (value) async {
                      await voice.setSpeechSpeed(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _choice(
                    label: 'Pitch',
                    enabled: voice.readyVoiceEnabled,
                    value: voice.speechPitch,
                    options: const {
                      'low': 'Low',
                      'normal': 'Normal',
                      'high': 'High',
                    },
                    onChanged: (value) async {
                      await voice.setSpeechPitch(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  _choice(
                    label: 'Voice',
                    enabled: voice.readyVoiceEnabled,
                    value: voice.languageCode,
                    options: {
                      for (final language in CustomerVoiceService.languages)
                        language.code: language.label,
                    },
                    onChanged: (value) async {
                      await voice.setLanguageCode(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _volume(
                    label: 'Voice volume',
                    value: voice.readyVolume,
                    enabled: voice.readyVoiceEnabled,
                    onChanged: (value) =>
                        setState(() => voice.readyVolume = value),
                    onChangeEnd: voice.setReadyVolume,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: voice.readyVoiceEnabled
                          ? () => voice.previewReadyVoice()
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Preview “Token number 4 ready”'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('Device startup'),
                  const SizedBox(height: 4),
                  Text(
                    'Automatically open the app when the TV or display device is powered on or restarted.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _switchTile(
                    soft: soft,
                    title: 'Auto-start on boot',
                    value: PosAutoStart.isEnabled,
                    onChanged: (value) async {
                      await PosAutoStart.setEnabled(value);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      footer: posDialogActionFooter(
        context: context,
        onCancel: () => Navigator.pop(context),
        onConfirm: () => Navigator.pop(context),
        cancelLabel: l10n.commonClose,
        confirmLabel: l10n.commonDone,
      ),
    );
  }

  Future<void> _previewChime() async {
    setState(() => _playing = _voice.newTokenTone);
    await _voice.previewNewToken();
    if (mounted) setState(() => _playing = null);
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: PosTheme.ink,
      ),
    );
  }

  Widget _switchTile({
    required ({Color bg, Color fg}) soft,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: value ? soft.bg : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: value ? soft.fg : PosTheme.ink,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _volume({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: enabled ? PosTheme.ink : PosTheme.inkFaint,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0.2,
            max: 1,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
      ],
    );
  }

  Widget _choice({
    required String label,
    required bool enabled,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: enabled ? PosTheme.ink : PosTheme.inkFaint,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: value == entry.key,
                onSelected: !enabled
                    ? null
                    : (selected) {
                        if (selected) onChanged(entry.key);
                      },
              ),
          ],
        ),
      ],
    );
  }
}

class _ToneTile extends StatelessWidget {
  const _ToneTile({
    required this.title,
    required this.selected,
    required this.playing,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool playing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      dense: true,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? accent : PosTheme.inkFaint,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 13.5,
          color: enabled ? PosTheme.ink : PosTheme.inkFaint,
        ),
      ),
      trailing: playing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          : Icon(Icons.play_arrow_rounded, color: enabled ? accent : PosTheme.inkFaint),
      onTap: enabled ? onTap : null,
    );
  }
}
