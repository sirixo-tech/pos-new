import 'package:flutter/material.dart';

import '../services/pos_auto_start.dart';

Future<void> showPosAutoStartPicker(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const PosAutoStartDialog(),
);

class PosAutoStartDialog extends StatefulWidget {
  const PosAutoStartDialog({super.key});

  @override
  State<PosAutoStartDialog> createState() => _PosAutoStartDialogState();
}

class _PosAutoStartDialogState extends State<PosAutoStartDialog>
    with WidgetsBindingObserver {
  bool? _access;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      if (!PosAutoStart.isInitialized) await PosAutoStart.initialize();
      final access = await PosAutoStart.hasBootLaunchAccess();
      if (mounted) {
        setState(() {
          _access = access;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _access = null;
          _error = 'Could not check device access. Try again.';
        });
      }
    }
  }

  Future<void> _save(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PosAutoStart.setEnabled(enabled);
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save auto-start. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings(bool permission) async {
    try {
      final opened = permission
          ? await PosAutoStart.openPermissionSettings()
          : await PosAutoStart.openAppSettings();
      if (!opened && mounted) {
        setState(
          () => _error =
              'This TV does not expose that settings screen. Check the device Settings for special app access or manufacturer auto-start controls.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open device settings. Open Settings on the device manually.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PosAutoStart.isEnabled;
    return AlertDialog(
      title: const Text('Auto-start on boot'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open after device restart'),
                subtitle: const Text(
                  'Restores the saved KDS, token display or POS workspace while signed in.',
                ),
                value: enabled,
                onChanged: _busy ? null : _save,
              ),
              if (PosAutoStart.isAndroid) ...[
                const Divider(),
                Text(
                  !enabled
                      ? 'Auto-start is off.'
                      : _access == true
                      ? 'Boot launch access granted.'
                      : _access == false
                      ? 'Setup needed: allow Display over other apps.'
                      : 'Checking boot launch access...',
                ),
                const SizedBox(height: 12),
                const Text(
                  'On Android TV and Google TV, allow Display over other apps for SELFX POS. Return here to check access, then restart the device to test. If your TV has battery or auto-start controls, allow the app there too.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openSettings(true),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Allow boot launch access'),
                ),
                TextButton(
                  onPressed: () => _openSettings(false),
                  child: const Text('Open app settings'),
                ),
                const Text(
                  'Some TVs restrict this permission. Those devices require manufacturer auto-start support or managed-device setup. Turning a TV off with its remote may only enter standby; boot auto-start runs after a restart or full power-on.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _refresh, child: const Text('Check access')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
