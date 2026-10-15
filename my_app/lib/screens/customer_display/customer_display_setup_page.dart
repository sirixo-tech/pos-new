import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/customer_display/lan/customer_display_lan_service.dart';
import '../../services/customer_display/lan/models/customer_display_device.dart';

// Ultra-premium executive design palette
const _ink = Color(0xFF0F172A); // Deep Slate Navy
const _muted = Color(0xFF64748B); // Slate Muted
const _subtle = Color(0xFF94A3B8); // Slate Light Muted
const _orange = Color(0xFFFF6500); // POS Brand Orange
const _emerald = Color(0xFF10B981); // Emerald Active Green
const _emeraldDark = Color(0xFF059669);
const _emeraldBg = Color(0xFFECFDF5);
const _emeraldBorder = Color(0xFFA7F3D0);
const _amber = Color(0xFFF59E0B);
const _amberBg = Color(0xFFFFFBEB);
const _pageBg = Color(0xFFF8FAFC); // Clean Slate Canvas
const _cardBorder = Color(0xFFE2E8F0); // Subtle 1px Line
const _cardSurface = Colors.white;

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

  Widget _buildScaffold(
    BuildContext context,
    CustomerDisplayLanService service,
  ) {
    final connected = service.devices.isNotEmpty;
    final hasError = service.errorMessage != null;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        centerTitle: false,
        title: const Text(
          'QR Display Pairing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: _ink,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _cardBorder),
        ),
        actions: [
          _PairingStatusPill(
            connected: connected,
            hasError: hasError,
            count: service.devices.length,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          final hPadding = isCompact ? 16.0 : 32.0;
          final maxContentWidth = math.min(
            1200.0,
            constraints.maxWidth - hPadding * 2,
          );

          final qrCard = _ScanCard(
            pairingData: service.pairingData,
            errorMessage: service.errorMessage,
            connected: connected,
            onRefresh: service.refreshPairingCode,
          );

          final connectionCard = _ConnectionStatusCard(
            connected: connected,
            errorMessage: service.errorMessage,
            connections: service.connections,
            connectionOptions: service.connectionOptions,
            selectedAddress: service.selectedAddress,
            onConnectionSelected: service.selectConnection,
          );

          final devicesCard = _ConnectedDevicesCard(
            devices: service.devices,
            onRefresh: service.restart,
            onDisconnect: service.disconnect,
          );

          const securityNote = _NetworkSecurityNote();

          if (isCompact) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPadding, 20, hPadding, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PairingHeader(),
                      const SizedBox(height: 16),
                      qrCard,
                      const SizedBox(height: 16),
                      connectionCard,
                      const SizedBox(height: 16),
                      devicesCard,
                      const SizedBox(height: 16),
                      securityNote,
                    ],
                  ),
                ),
              ),
            );
          }

          // Desktop & Wide Tablet 2-Column Executive Layout
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PairingHeader(),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Prominent QR Card
                        Expanded(
                          flex: 5,
                          child: qrCard,
                        ),
                        const SizedBox(width: 20),
                        // Right Column: Connection Details + Active Displays
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              connectionCard,
                              const SizedBox(height: 16),
                              devicesCard,
                              const SizedBox(height: 16),
                              securityNote,
                            ],
                          ),
                        ),
                      ],
                    ),
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
  const _PairingStatusPill({
    required this.connected,
    required this.hasError,
    required this.count,
  });

  final bool connected;
  final bool hasError;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color dotColor;
    final Color textColor;
    final String label;

    if (hasError) {
      bg = const Color(0xFFFEF2F2);
      dotColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
      label = 'Unavailable';
    } else if (connected) {
      bg = _emeraldBg;
      dotColor = _emerald;
      textColor = _emeraldDark;
      label = count > 1 ? '$count Displays' : 'Connected';
    } else {
      bg = _amberBg;
      dotColor = _amber;
      textColor = const Color(0xFF92400E);
      label = 'Ready to Pair';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dotColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PairingHeader extends StatelessWidget {
  const _PairingHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connect Customer Display',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pair a secondary screen to display payment QR codes and live totals.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 480;
              if (isSmall) {
                return const Column(
                  children: [
                    _StepItem(step: '1', title: 'Connect to Wi-Fi'),
                    SizedBox(height: 8),
                    _StepItem(step: '2', title: 'Open QR Display App'),
                    SizedBox(height: 8),
                    _StepItem(step: '3', title: 'Scan Pairing Code'),
                  ],
                );
              }
              return const Row(
                children: [
                  Expanded(
                    child: _StepItem(step: '1', title: 'Same Wi-Fi'),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: _subtle),
                  Expanded(
                    child: _StepItem(step: '2', title: 'Open Display App'),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: _subtle),
                  Expanded(
                    child: _StepItem(step: '3', title: 'Scan Code'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.step, required this.title});

  final String step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
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
    required this.connected,
    required this.onRefresh,
  });

  final String? pairingData;
  final String? errorMessage;
  final bool connected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pairing Code',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Scan with the customer display app',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh pairing code',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: _muted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: _buildQrContent(context),
          ),
          const SizedBox(height: 16),
          // Compact footer hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: _subtle,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  connected
                      ? 'Display synchronized over secure LAN'
                      : 'Keep this screen open while pairing',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent(BuildContext context) {
    if (errorMessage != null) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (pairingData == null) {
      if (connected) {
        return Container(
          height: 220,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _emeraldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _emeraldBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: _emerald,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Display Paired & Active',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Payment QR codes will show automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _cardBorder),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                label: const Text(
                  'Pair Another Display',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }

      return const SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _orange,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Generating pairing session...',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: pairingData!,
        size: 230,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.connected,
    required this.errorMessage,
    required this.connections,
    required this.connectionOptions,
    required this.selectedAddress,
    required this.onConnectionSelected,
  });

  final bool connected;
  final String? errorMessage;
  final List<CustomerDisplayConnection> connections;
  final List<String> connectionOptions;
  final String? selectedAddress;
  final Future<void> Function(String address) onConnectionSelected;

  @override
  Widget build(BuildContext context) {
    final address = selectedAddress ?? _firstIpAddress(connectionOptions);
    final isReady = errorMessage == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: _emeraldDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connection Status',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isReady ? _emeraldBg : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isReady ? 'Active' : 'Offline',
                  style: TextStyle(
                    color: isReady ? _emeraldDark : const Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Tile Grid - Responsive Layout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                if (isNarrow) {
                  return Column(
                    children: [
                      const _InfoRow(
                        label: 'Network',
                        value: 'Wi-Fi LAN',
                        icon: Icons.wifi_rounded,
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: _cardBorder),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'IP Address',
                        value: address ?? 'Starting...',
                        icon: Icons.lan_outlined,
                        trailing: address != null
                            ? IconButton(
                                tooltip: 'Copy IP',
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 15,
                                  color: _muted,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _copyIp(context, address),
                              )
                            : null,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Expanded(
                      child: _InfoColumn(
                        label: 'Network',
                        value: 'Wi-Fi LAN',
                        icon: Icons.wifi_rounded,
                      ),
                    ),
                    Container(width: 1, height: 32, color: _cardBorder),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _InfoColumn(
                        label: 'IP Address',
                        value: address ?? 'Starting...',
                        icon: Icons.lan_outlined,
                      ),
                    ),
                    if (address != null)
                      IconButton(
                        tooltip: 'Copy IP',
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: _muted,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copyIp(context, address),
                      ),
                  ],
                );
              },
            ),
          ),
          // Multi-interface selector if applicable
          if (connections.length > 1) ...[
            const SizedBox(height: 12),
            const Text(
              'Select Network Interface:',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final item in connections)
                  ChoiceChip(
                    label: Text(
                      '${item.transport.toUpperCase()} • ${item.address}',
                    ),
                    selected: item.address == selectedAddress,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          item.address == selectedAddress ? Colors.white : _ink,
                    ),
                    selectedColor: _ink,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color:
                          item.address == selectedAddress ? _ink : _cardBorder,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        onConnectionSelected(item.address);
                      }
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static void _copyIp(BuildContext context, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('IP address copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _subtle),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _subtle),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ConnectedDevicesCard extends StatelessWidget {
  const _ConnectedDevicesCard({
    required this.devices,
    required this.onRefresh,
    required this.onDisconnect,
  });

  final List<CustomerDisplayDevice> devices;
  final VoidCallback onRefresh;
  final void Function(String id) onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Displays',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${devices.length}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (devices.isEmpty)
            // Clean empty state that NEVER overflows
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(
                      Icons.phonelink_outlined,
                      color: _subtle,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No Displays Connected',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Devices scanning the QR code will appear here automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final device = devices[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _emeraldBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: _emeraldDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${device.address} • Connected at ${_time(device.connectedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Disconnect',
                        onPressed: () => onDisconnect(device.id),
                        icon: const Icon(
                          Icons.link_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NetworkSecurityNote extends StatelessWidget {
  const _NetworkSecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 18,
            color: _muted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Secure peer-to-peer connection. Both devices must remain on the same Wi-Fi network.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardBoxDecoration() {
  return BoxDecoration(
    color: _cardSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _cardBorder),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
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
