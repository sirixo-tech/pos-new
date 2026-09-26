import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';
import '../services/pos_cart_sound.dart';
import '../theme/pos_theme.dart';
import 'pos_ui.dart';

Future<void> showPosSoundSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _PosSoundSettingsDialog(),
  );
}

class _PosSoundSettingsDialog extends StatefulWidget {
  const _PosSoundSettingsDialog();

  @override
  State<_PosSoundSettingsDialog> createState() =>
      _PosSoundSettingsDialogState();
}

class _PosSoundSettingsDialogState extends State<_PosSoundSettingsDialog> {
  int _tab = 0;
  String? _playing;

  @override
  void initState() {
    super.initState();
    PosCartSound.instance.loadSettings().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _preview(String tone) async {
    setState(() => _playing = tone);
    await PosCartSound.instance.playPreview(tone);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sound = PosCartSound.instance;
    final accent = Theme.of(context).colorScheme.primary;

    return PosDialogShell(
      title: 'Sound settings',
      subtitle: 'Tones for new orders and cart taps on this register.',
      icon: Icons.volume_up_rounded,
      maxWidth: 460,
      onClose: () => Navigator.pop(context),
      body: SizedBox(
        height: 420,
        child: Column(
          children: [
            _SoundTabBar(
              accent: accent,
              index: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _tab == 0
                  ? _TonePane(
                      enabled: sound.orderAlertEnabled,
                      selected: sound.orderTone,
                      playing: _playing,
                      tones: PosCartSound.orderTones,
                      enableLabel: 'Play new-order chime',
                      onEnabled: (value) async {
                        await sound.setOrderAlertEnabled(value);
                        if (mounted) setState(() {});
                      },
                      onSelect: (tone) async {
                        await sound.setOrderTone(tone);
                        if (mounted) setState(() {});
                        await _preview(tone);
                      },
                    )
                  : _TonePane(
                      enabled: sound.clickEnabled,
                      selected: sound.clickTone,
                      playing: _playing,
                      tones: PosCartSound.clickTones,
                      enableLabel: 'Play tap / cart sound',
                      onEnabled: (value) async {
                        await sound.setClickEnabled(value);
                        if (mounted) setState(() {});
                      },
                      onSelect: (tone) async {
                        await sound.setClickTone(tone);
                        if (mounted) setState(() {});
                        await _preview(tone);
                      },
                    ),
            ),
          ],
        ),
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
}

class _SoundTabBar extends StatelessWidget {
  const _SoundTabBar({
    required this.accent,
    required this.index,
    required this.onChanged,
  });

  final Color accent;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SoundTabChip(
              selected: index == 0,
              icon: Icons.notifications_active_outlined,
              label: 'New order',
              accent: accent,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SoundTabChip(
              selected: index == 1,
              icon: Icons.touch_app_outlined,
              label: 'Tap / cart',
              accent: accent,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundTabChip extends StatelessWidget {
  const _SoundTabChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? PosTheme.cardShadow() : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? accent : PosTheme.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? PosTheme.ink : PosTheme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TonePane extends StatelessWidget {
  const _TonePane({
    required this.enabled,
    required this.selected,
    required this.playing,
    required this.tones,
    required this.enableLabel,
    required this.onEnabled,
    required this.onSelect,
  });

  final bool enabled;
  final String selected;
  final String? playing;
  final Map<String, String> tones;
  final String enableLabel;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);

    return Column(
      children: [
        Material(
          color: enabled ? soft.bg : PosTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              enableLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: enabled ? soft.fg : PosTheme.ink,
              ),
            ),
            value: enabled,
            onChanged: onEnabled,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              for (final entry in tones.entries)
                _ToneTile(
                  title: entry.value,
                  selected: selected == entry.key,
                  playing: playing == entry.key,
                  enabled: enabled,
                  onTap: () => onSelect(entry.key),
                ),
            ],
          ),
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
    final soft = posAccentSoft(accent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? soft.fg : PosTheme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected ? soft.fg : PosTheme.ink,
                    ),
                  ),
                ),
                if (playing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: soft.fg,
                    ),
                  )
                else
                  Icon(
                    Icons.play_arrow_rounded,
                    color: enabled ? soft.fg : PosTheme.inkFaint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showKitchenSoundSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _KitchenSoundSettingsDialog(),
  );
}

class _KitchenSoundSettingsDialog extends StatefulWidget {
  const _KitchenSoundSettingsDialog();

  @override
  State<_KitchenSoundSettingsDialog> createState() =>
      _KitchenSoundSettingsDialogState();
}

class _KitchenSoundSettingsDialogState
    extends State<_KitchenSoundSettingsDialog> {
  String? _playing;

  @override
  void initState() {
    super.initState();
    PosCartSound.instance.loadSettings().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sound = PosCartSound.instance;
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);

    return PosDialogShell(
      title: 'Kitchen sound',
      subtitle: 'Chime when a new ticket lands on this board.',
      icon: Icons.soup_kitchen_outlined,
      maxWidth: 440,
      onClose: () => Navigator.pop(context),
      body: SizedBox(
        height: 400,
        child: Column(
          children: [
            Material(
              color: sound.kitchenAlertEnabled ? soft.bg : PosTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  'New ticket chime',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: sound.kitchenAlertEnabled ? soft.fg : PosTheme.ink,
                  ),
                ),
                value: sound.kitchenAlertEnabled,
                onChanged: (value) async {
                  await sound.setKitchenAlertEnabled(value);
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in PosCartSound.orderTones.entries)
                    _ToneTile(
                      title: entry.value,
                      selected: sound.kitchenTone == entry.key,
                      playing: _playing == entry.key,
                      enabled: sound.kitchenAlertEnabled,
                      onTap: () async {
                        await sound.setKitchenTone(entry.key);
                        setState(() => _playing = entry.key);
                        await sound.playPreview(entry.key);
                        if (mounted) setState(() => _playing = null);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
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
}
