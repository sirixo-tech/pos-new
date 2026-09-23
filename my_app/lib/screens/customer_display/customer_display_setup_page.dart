import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/customer_display/lan/customer_display_lan_service.dart';
import '../../services/customer_display/lan/models/customer_display_device.dart';

const _ink = Color(0xFF081735);
const _muted = Color(0xFF526078);
const _orange = Color(0xFFFF6500);
const _green = Color(0xFF079B35);
const _page = Color(0xFFF5F8FC);
const _line = Color(0xFFDCE4EF);

class CustomerDisplaySetupPage extends StatefulWidget {
  const CustomerDisplaySetupPage({super.key});

  static const routePath = '/customer-display/setup';

  @override
  State<CustomerDisplaySetupPage> createState() =>
      _CustomerDisplaySetupPageState();
}

class _CustomerDisplaySetupPageState extends State<CustomerDisplaySetupPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => CustomerDisplayLanService.instance.start());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CustomerDisplayLanService.instance,
      builder: (context, _) {
        final service = CustomerDisplayLanService.instance;
        return _buildScaffold(context, service);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, CustomerDisplayLanService service) {
    final connected = service.devices.isNotEmpty;
    final showStatusPill = MediaQuery.sizeOf(context).width >= 620;

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        toolbarHeight: 76,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        title: const Text(
          'QR Display Pairing',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
        actions: [
          if (showStatusPill) ...[
            _PairingStatusPill(connected: connected),
            const SizedBox(width: 12),
          ],
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Width alone is not enough for desktop responsiveness. Many POS
          // laptops are wide but only 600-700 logical pixels tall after the
          // Windows taskbar and title bar. The old Expanded layout compressed
          // the pairing QR to its 64px fallback and pushed the lower actions
          // outside the visible area on those screens.
          final compact = constraints.maxWidth < 980;
          final shortDesktop = !compact && constraints.maxHeight < 780;
          final horizontalPadding = compact ? 16.0 : 32.0;
          final contentWidth = math
              .min(
                1320.0,
                math.max(0.0, constraints.maxWidth - horizontalPadding * 2),
              )
              .toDouble();
          final columnWidth = compact ? contentWidth : (contentWidth - 18) / 2;
          final qrSize = math
              .min(compact ? 280.0 : 270.0, math.max(140.0, columnWidth - 92))
              .toDouble();

          final qrCard = _ScanCard(
            pairingData: service.pairingData,
            errorMessage: service.errorMessage,
            qrSize: qrSize,
            dense: !compact,
            connected: connected,
            onRefresh: service.refreshPairingCode,
          );
          final statusCard = _ConnectionCard(
            connected: connected,
            errorMessage: service.errorMessage,
            connectionOptions: service.connectionOptions,
            connections: service.connections,
            selectedAddress: service.selectedAddress,
            onConnectionSelected: service.selectConnection,
            dense: !compact,
          );
          final connectedDevicesCard = _ConnectedDevicesCard(
            devices: service.devices,
            onRefresh: service.restart,
            onDisconnect: service.disconnect,
            dense: !compact,
          );

          if (compact) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                22,
                horizontalPadding,
                30,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PairingIntroduction(),
                      const SizedBox(height: 20),
                      qrCard,
                      const SizedBox(height: 16),
                      statusCard,
                      const SizedBox(height: 18),
                      connectedDevicesCard,
                      const SizedBox(height: 16),
                      const _PairingReminder(),
                    ],
                  ),
                ),
              ),
            );
          }

          if (shortDesktop) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PairingIntroduction(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 430,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: qrCard),
                            const SizedBox(width: 18),
                            Expanded(child: statusCard),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      connectedDevicesCard,
                      const SizedBox(height: 12),
                      const _PairingReminder(dense: true),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              18,
            ),
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PairingIntroduction(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: qrCard),
                          const SizedBox(width: 18),
                          Expanded(child: statusCard),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    connectedDevicesCard,
                    const SizedBox(height: 12),
                    const _PairingReminder(dense: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PairingStatusPill extends StatelessWidget {
  const _PairingStatusPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFEAF8EF) : const Color(0xFFFFF2E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: connected ? _green : _orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            connected ? 'Connected' : 'Waiting for device',
            style: TextStyle(
              color: connected ? _green : const Color(0xFF9A3E00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingIntroduction extends StatelessWidget {
  const _PairingIntroduction();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEFE5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_android_rounded, color: _ink, size: 47),
        ),
        const SizedBox(width: 22),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect QR Display',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connect both devices to the same Wi-Fi, then open QR Display and scan the code below.\n'
                'Once paired, payment QR codes will appear automatically on the phone.',
                style: TextStyle(color: _muted, fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.pairingData,
    required this.errorMessage,
    required this.qrSize,
    required this.dense,
    required this.connected,
    required this.onRefresh,
  });

  final String? pairingData;
  final String? errorMessage;
  final double qrSize;
  final bool dense;
  final bool connected;
  final Future<void> Function() onRefresh;

  Widget _qrContent(double size) {
    if (errorMessage != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    if (pairingData == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: connected
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: _green,
                      size: 58,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Secure display paired',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Pair another display'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(dense ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: QrImageView(
        data: pairingData!,
        size: size,
        backgroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const heading = _SectionHeading(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Scan to Pair',
      subtitle:
          'Open the QR Display app on your Android phone and scan this code.',
      color: _orange,
    );
    const footer = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_rounded, color: _orange, size: 20),
        SizedBox(width: 9),
        Flexible(
          child: Text(
            'Keep the app open while pairing.',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    if (dense) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final framePadding =
                      errorMessage == null && pairingData != null ? 16.0 : 0.0;
                  final available = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final resolvedSize = math.max(
                    64.0,
                    math.min(qrSize, available - framePadding),
                  );
                  return Center(child: _qrContent(resolvedSize));
                },
              ),
            ),
            const SizedBox(height: 8),
            footer,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 18),
          Center(child: _qrContent(qrSize)),
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connected,
    required this.errorMessage,
    required this.connectionOptions,
    required this.connections,
    required this.selectedAddress,
    required this.onConnectionSelected,
    required this.dense,
  });

  final bool connected;
  final String? errorMessage;
  final List<String> connectionOptions;
  final List<CustomerDisplayConnection> connections;
  final String? selectedAddress;
  final Future<void> Function(String address) onConnectionSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final address = selectedAddress ?? _firstIpAddress(connectionOptions);
    final ready = errorMessage == null;

    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          icon: Icons.wifi_rounded,
          title: 'Connection Status',
          color: _green,
        ),
        SizedBox(height: dense ? 12 : 18),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 12 : 16),
          decoration: BoxDecoration(
            color: ready ? const Color(0xFFEDF9F1) : const Color(0xFFFFEEEE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: ready ? _green : Colors.red,
                child: Icon(
                  ready ? Icons.check_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? 'QR Display Connected'
                          : ready
                          ? 'Ready to Pair'
                          : 'Pairing unavailable',
                      style: TextStyle(
                        color: ready ? _green : Colors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected
                          ? 'Payment QR codes will appear automatically.'
                          : errorMessage ??
                                'Waiting for Android device to connect...',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dense ? 10 : 12),
        Container(
          padding: EdgeInsets.all(dense ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFC),
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE9EDF3),
                child: Icon(Icons.wifi_rounded, color: _muted),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: _ConnectionValue(label: 'Network', value: 'Wi-Fi'),
              ),
              Container(width: 1, height: 42, color: _line),
              const SizedBox(width: 18),
              Expanded(
                child: _ConnectionValue(
                  label: 'IP Address',
                  value: address ?? 'Starting...',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dense ? 14 : 20),
        if (connections.length > 1) ...[
          const Text(
            'Customer display network',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final connection in connections)
                ChoiceChip(
                  selected: connection.address == selectedAddress,
                  label: Text(
                    '${connection.transport.toUpperCase()} ${connection.address}',
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      onConnectionSelected(connection.address);
                    }
                  },
                ),
            ],
          ),
          SizedBox(height: dense ? 10 : 14),
        ],
        const Text(
          'How to Connect',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: dense ? 6 : 14),
        if (dense)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CompactInstruction(
                  number: 1,
                  text: 'Open the QR Display app.',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _CompactInstruction(
                  number: 2,
                  text: 'Scan the QR code.',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _CompactInstruction(
                  number: 3,
                  text: 'Wait for Connected.',
                ),
              ),
            ],
          )
        else ...[
          const _InstructionStep(
            number: 1,
            text: 'Open QR Display app on your Android phone.',
          ),
          const _InstructionStep(
            number: 2,
            text: 'Scan the QR code shown on the left.',
          ),
          const _InstructionStep(
            number: 3,
            text: 'Wait for the Connected status.',
            showLine: false,
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 16 : 24,
        vertical: dense ? 10 : 24,
      ),
      decoration: _panelDecoration(),
      child: dense
          ? LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: constraints.maxWidth, child: contents),
                );
              },
            )
          : contents,
    );
  }
}

class _CompactInstruction extends StatelessWidget {
  const _CompactInstruction({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFFFE4D4),
          child: Text(
            '$number',
            style: const TextStyle(
              color: _orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(color: _ink, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: color.withValues(alpha: 0.11),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(color: _muted, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionValue extends StatelessWidget {
  const _ConnectionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.text,
    this.showLine = true,
  });

  final int number;
  final String text;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFFFE4D4),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (showLine)
                  Expanded(child: Container(width: 1, color: _line)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 18),
              child: Text(text, style: const TextStyle(color: _ink)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedDevicesCard extends StatelessWidget {
  const _ConnectedDevicesCard({
    required this.devices,
    required this.onRefresh,
    required this.onDisconnect,
    required this.dense,
  });

  final List<CustomerDisplayDevice> devices;
  final VoidCallback onRefresh;
  final void Function(String id) onDisconnect;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(dense ? 12 : 20),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFEEE4),
                child: Icon(Icons.phone_android_rounded, color: _orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connected Devices (${devices.length})',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: Color(0xFFFFB88C)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 8 : 14),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: dense ? 78 : 112),
            padding: EdgeInsets.all(dense ? 10 : 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFCFE),
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: devices.isEmpty
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_android_outlined,
                        size: 54,
                        color: Color(0xFFB3BDCD),
                      ),
                      SizedBox(width: 24),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No device connected',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Scan the pairing QR from the Android phone.',
                              style: TextStyle(color: _muted),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.wifi, size: 16, color: _muted),
                                SizedBox(width: 6),
                                Text(
                                  'Waiting for connection...',
                                  style: TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      for (var index = 0; index < devices.length; index++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.phone_android_outlined),
                          ),
                          title: Text(devices[index].name),
                          subtitle: Text(
                            '${devices[index].address} - connected ${_time(devices[index].connectedAt)}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Disconnect',
                            onPressed: () => onDisconnect(devices[index].id),
                            icon: const Icon(Icons.link_off),
                          ),
                        ),
                        if (index != devices.length - 1) const Divider(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PairingReminder extends StatelessWidget {
  const _PairingReminder({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: dense ? 10 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        border: Border.all(color: const Color(0xFFCEE0FA)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Icon(Icons.shield_outlined, color: _ink),
          Text(
            'Keep the POS app open while pairing.',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          Text(
            'On Windows, allow private-network access if Firewall asks.',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _line),
    borderRadius: BorderRadius.circular(12),
    boxShadow: const [
      BoxShadow(color: Color(0x0E21314F), blurRadius: 22, offset: Offset(0, 7)),
    ],
  );
}

String? _firstIpAddress(List<String> options) {
  final pattern = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  for (final option in options) {
    final match = pattern.firstMatch(option);
    if (match != null) return match.group(0);
  }
  return null;
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
