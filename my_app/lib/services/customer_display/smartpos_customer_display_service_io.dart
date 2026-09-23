import 'dart:async';
import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dq11_customer_display_service.dart';
import 'dqr222_customer_display_service.dart';

const _smartPosDisplayChannel = MethodChannel('pos_dual_screen');

typedef WindowsCustomerDisplayStatus = ({
  bool connected,
  String? port,
  String message,
  String? device,
});

final Set<String> _activeWindowsUsbDisplays = <String>{};

bool isDedicatedSmartPosDisplayMode(String? mode) {
  return mode == 'lcd' ||
      mode == 'secondary_display' ||
      mode == 'imin_lcd' ||
      mode == 'dq11' ||
      mode == 'dqr222' ||
      mode == 'dq11+dqr222';
}

Future<String?> showSmartPosUpiQr({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? upiId,
  int? timeoutSeconds,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    // USB serial displays (DQ11, DQR-222) take several seconds to complete a
    // write. Awaiting both serially blocks the cashier and triggers the 700 ms
    // acknowledgement timeout in the POS shell before the QR even appears on
    // the device.
    //
    // Strategy:
    //   1. Check instantly (no I/O) whether each display was last seen connected.
    //   2. Fire serial writes in the background — the QR arrives on the device
    //      in ~1-2 s without the POS dialog being delayed.
    //   3. Return the display mode immediately so the POS can proceed.
    //
    // The _activeWindowsUsbDisplays set is updated once the background writes
    // complete so that clear/cancel/success calls are routed correctly.
    final dqr222Known = dqr222LastKnownPort != null;
    final dq11Known = false; // dq11 exposes no synchronous fast check yet

    // Build a best-guess active set right now so the caller gets a mode string.
    // Any device that was never seen stays out of the set.
    _activeWindowsUsbDisplays.clear();

    // Fire both writes concurrently in the background.
    final writeFuture = Future.wait<bool>([
      showDq11PaymentQr(
        qr: qr,
        orderNumber: orderNumber,
        amount: amount,
        payeeName: payeeName,
        upiId: upiId,
        restaurantName: restaurantName,
        restaurantLogoUrl: restaurantLogoUrl,
        timeoutSeconds: timeoutSeconds,
      ).catchError((_) => false),
      showDqr222PaymentQr(
        qr: qr,
        orderNumber: orderNumber,
        amount: amount,
        payeeName: payeeName,
        upiId: upiId,
        restaurantName: restaurantName,
        restaurantLogoUrl: restaurantLogoUrl,
        timeoutSeconds: timeoutSeconds,
      ).catchError((_) => false),
    ]);

    if (dqr222Known || dq11Known) {
      // At least one USB display is expected to show the QR. Return the mode
      // immediately and let the write settle in the background.
      if (dqr222Known) _activeWindowsUsbDisplays.add('dqr222');
      // Update the active set once the writes confirm which devices responded.
      unawaited(writeFuture.then((results) {
        _activeWindowsUsbDisplays
          ..clear()
          ..addAll([if (results[0]) 'dq11', if (results[1]) 'dqr222']);
        debugPrint(
          '[UPI_QR][DISPLAY] USB background write done: $_activeWindowsUsbDisplays',
        );
      }));
      final usbMode = _displayMode(_activeWindowsUsbDisplays);
      debugPrint(
        '[UPI_QR][DISPLAY] USB fast-path mode=$usbMode '
        'dqr222Known=$dqr222Known dq11Known=$dq11Known',
      );
      if (Platform.isWindows) return usbMode;
    } else {
      // No display was previously seen — await the full write so we can detect
      // a newly connected device that appeared after the last status poll.
      final results = await writeFuture;
      _activeWindowsUsbDisplays
        ..clear()
        ..addAll([if (results[0]) 'dq11', if (results[1]) 'dqr222']);
      final usbMode = _displayMode(_activeWindowsUsbDisplays);
      if (Platform.isWindows) return usbMode;
    }
  }
  if (!Platform.isAndroid) {
    debugPrint('[UPI_QR][DISPLAY] skip: unsupported platform');
    return null;
  }
  debugPrint(
    '[UPI_QR][DISPLAY] invoke showUpiQr '
    'qrLen=${qr.length} upi=${qr.startsWith('upi://')} '
    'order=$orderNumber amount=$amount timeout=$timeoutSeconds',
  );
  final result = await _smartPosDisplayChannel
      .invokeMethod<String>('showUpiQr', <String, Object?>{
        'qrData': qr,
        'orderNumber': orderNumber,
        'amount': amount,
        'payeeName': payeeName,
        'upiId': upiId,
        'timeoutSeconds': timeoutSeconds,
        'restaurantName': restaurantName,
        'restaurantLogoUrl': restaurantLogoUrl,
      });
  debugPrint('[UPI_QR][DISPLAY] showUpiQr result=$result');
  return result;
}


Future<void> clearSmartPosCustomerDisplay() async {
  if (Platform.isWindows || Platform.isAndroid) {
    final displays = await _resolveWindowsUsbDisplays();
    if (displays.isNotEmpty) {
      await _forEachWindowsDisplay(
        displays,
        dq11: clearDq11CustomerDisplay,
        dqr222: clearDqr222CustomerDisplay,
      );
      _activeWindowsUsbDisplays.clear();
      if (Platform.isWindows) return;
    }
    if (Platform.isWindows) return;
  }
  if (!Platform.isAndroid) {
    debugPrint('[UPI_QR][DISPLAY] clear skipped: platform is not Android');
    return;
  }
  debugPrint('[UPI_QR][DISPLAY] clearSubDisplay invoke');
  await _smartPosDisplayChannel.invokeMethod<void>('clearSubDisplay');
  debugPrint('[UPI_QR][DISPLAY] clearSubDisplay done');
}

Future<void> cancelSmartPosCustomerDisplay({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    final displays = await _resolveWindowsUsbDisplays();
    if (displays.isNotEmpty) {
      await _forEachWindowsDisplay(
        displays,
        dq11: () => showDq11PaymentCancelled(
          orderNumber: orderNumber,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
        dqr222: () => showDqr222PaymentCancelled(
          orderNumber: orderNumber,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
      );
      if (Platform.isWindows) return;
    }
    if (Platform.isWindows) return;
  }
  if (!Platform.isAndroid) return;
  final shownOnImin = await _smartPosDisplayChannel
      .invokeMethod<bool>('showPaymentCancelled', <String, Object?>{
        'orderNumber': orderNumber,
        'restaurantName': restaurantName,
        'restaurantLogoUrl': restaurantLogoUrl,
      });
  if (shownOnImin != true) {
    // Preserve the existing TVS/SmartPOS cancellation behavior.
    await clearSmartPosCustomerDisplay();
  }
}

Future<void> showSmartPosPaymentExpired({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    final displays = await _resolveWindowsUsbDisplays();
    if (displays.isNotEmpty) {
      await _forEachWindowsDisplay(
        displays,
        dq11: () async {
          // DQ11 owns its own expiry timer.
        },
        dqr222: () => showDqr222PaymentExpired(
          orderNumber: orderNumber,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
      );
      if (Platform.isWindows) return;
    }
    if (Platform.isWindows) return;
  }
  if (!Platform.isAndroid) return;
  await _smartPosDisplayChannel
      .invokeMethod<bool>('showPaymentExpired', <String, Object?>{
        'orderNumber': orderNumber,
        'restaurantName': restaurantName,
        'restaurantLogoUrl': restaurantLogoUrl,
      });
}

Future<void> showSmartPosIdleCustomerDisplay({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    final displays = await _connectedWindowsUsbDisplays();
    if (displays.isNotEmpty) {
      await _forEachWindowsDisplay(
        displays,
        dq11: () => showDq11HomeIfIdle(
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
        dqr222: () => showDqr222HomeIfIdle(
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
      );
      if (Platform.isWindows) return;
    }
    if (Platform.isWindows) return;
  }
  if (!Platform.isAndroid) return;
  await _smartPosDisplayChannel.invokeMethod<bool>(
    'showIdleCustomerDisplay',
    <String, Object?>{
      'restaurantName': restaurantName,
      'restaurantLogoUrl': restaurantLogoUrl,
    },
  );
}

Future<void> showSmartPosPaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (Platform.isWindows || Platform.isAndroid) {
    final displays = await _resolveWindowsUsbDisplays();
    if (displays.isNotEmpty) {
      await _forEachWindowsDisplay(
        displays,
        dq11: () => showDq11PaymentSuccess(
          amount: amount,
          orderNumber: orderNumber,
          transactionId: transactionId,
          paidAt: paidAt,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
        dqr222: () => showDqr222PaymentSuccess(
          amount: amount,
          orderNumber: orderNumber,
          transactionId: transactionId,
          paidAt: paidAt,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        ),
      );
      if (Platform.isWindows) return;
    }
    if (Platform.isWindows) return;
  }
  if (!Platform.isAndroid) return;
  // Non-iMin Android terminals return false without changing their existing
  // TVS/LAN customer-display flow.
  await _smartPosDisplayChannel
      .invokeMethod<bool>('showPaymentSuccess', <String, Object?>{
        'amount': amount,
        'orderNumber': orderNumber,
        'transactionId': transactionId,
        'paidAt': paidAt?.toIso8601String(),
        'restaurantName': restaurantName,
        'restaurantLogoUrl': restaurantLogoUrl,
      });
}

Future<WindowsCustomerDisplayStatus> getWindowsCustomerDisplayStatus() async {
  if (!Platform.isWindows && !Platform.isAndroid) {
    return (
      connected: false,
      port: null,
      message: 'USB customer displays are not supported on this platform.',
      device: null,
    );
  }
  final statuses = await Future.wait([
    getDq11DisplayStatus(),
    getDqr222DisplayStatus(),
  ]);
  final dq11 = statuses[0];
  final dqr222 = statuses[1];
  if (dq11.connected && dqr222.connected) {
    return (
      connected: true,
      port: [dq11.port, dqr222.port].whereType<String>().join(', '),
      message:
          'DQ11${dq11.port == null ? '' : ' (${dq11.port})'} and DQR-222${dqr222.port == null ? '' : ' (${dqr222.port})'} customer displays connected.',
      device: 'dq11+dqr222',
    );
  }
  if (dq11.connected) {
    return (
      connected: true,
      port: dq11.port,
      message: dq11.message,
      device: 'dq11',
    );
  }
  if (dqr222.connected) {
    return (
      connected: true,
      port: dqr222.port,
      message: dqr222.message,
      device: 'dqr222',
    );
  }
  if (Platform.isAndroid) {
    try {
      final mode = await _smartPosDisplayChannel
          .invokeMethod<String>('getCustomerDisplayStatus');
      if (mode != null && mode != 'none') {
        return (
          connected: true,
          port: null,
          message: 'Built-in customer display connected.',
          device: mode,
        );
      }
    } catch (error) {
      debugPrint('[UPI_QR][DISPLAY] status probe failed: $error');
    }
  }
  return (
    connected: false,
    port: null,
    message: Platform.isAndroid
        ? 'No built-in or USB customer display is connected.'
        : 'No DQR-222 or DQ11 customer display is connected.',
    device: null,
  );
}

Future<void> showWindowsCustomerDisplayHomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) => showSmartPosIdleCustomerDisplay(
  restaurantName: restaurantName,
  restaurantLogoUrl: restaurantLogoUrl,
);

/// Initializes every supported USB customer display and retries while the
/// host publishes serial devices or Android grants USB permission.
Future<void> initializeWindowsCustomerDisplays() async {
  if (!Platform.isWindows && !Platform.isAndroid) return;
  for (var attempt = 0; attempt < 4; attempt++) {
    await showSmartPosIdleCustomerDisplay();
    if (attempt < 3) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}

Future<Set<String>> _connectedWindowsUsbDisplays() async {
  final statuses = await Future.wait([
    getDq11DisplayStatus(),
    getDqr222DisplayStatus(),
  ]);
  return <String>{
    if (statuses[0].connected) 'dq11',
    if (statuses[1].connected) 'dqr222',
  };
}

Future<Set<String>> _resolveWindowsUsbDisplays() async {
  if (_activeWindowsUsbDisplays.isNotEmpty) {
    return Set<String>.of(_activeWindowsUsbDisplays);
  }
  return _connectedWindowsUsbDisplays();
}

Future<void> _forEachWindowsDisplay(
  Set<String> displays, {
  required Future<void> Function() dq11,
  required Future<void> Function() dqr222,
}) async {
  final operations = <Future<void>>[];
  if (displays.contains('dq11')) {
    operations.add(
      dq11().catchError((Object error) {
        debugPrint('[DQ11][DISPLAY] update failed: $error');
      }),
    );
  }
  if (displays.contains('dqr222')) {
    operations.add(
      dqr222().catchError((Object error) {
        debugPrint('[DQR222][DISPLAY] update failed: $error');
      }),
    );
  }
  await Future.wait(operations);
}

String? _displayMode(Set<String> displays) {
  if (displays.contains('dq11') && displays.contains('dqr222')) {
    return 'dq11+dqr222';
  }
  if (displays.contains('dq11')) return 'dq11';
  if (displays.contains('dqr222')) return 'dqr222';
  return null;
}
