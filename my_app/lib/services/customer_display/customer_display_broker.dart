import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dqr222_customer_display_service.dart';
import 'lan/customer_display_lan_service.dart';
import 'smartpos_customer_display_service.dart';

/// Fans cart and UPI QR updates out to USB poles, SmartPOS LCDs, and LAN
/// customer phones. Cloud [PosDisplaySync] stays separate.
class CustomerDisplayBroker {
  CustomerDisplayBroker._();

  static final CustomerDisplayBroker instance = CustomerDisplayBroker._();

  String? restaurantName;
  String? restaurantLogoUrl;
  bool _paymentActive = false;
  bool _initialized = false;
  String? _displayOrderNumber;

  /// True when this order's QR is the one currently on the customer display.
  bool displaysOrder(String? orderNumber) {
    final shown = _displayOrderNumber?.trim() ?? '';
    final requested = orderNumber?.trim() ?? '';
    return shown.isNotEmpty && shown == requested;
  }

  String _lanSessionId(String? orderNumber) {
    final value = orderNumber?.trim() ?? '';
    return value.isEmpty ? 'pos-qr' : value;
  }

  void updateBranding({String? name, String? logoUrl}) {
    final trimmedName = name?.trim();
    final trimmedLogo = logoUrl?.trim();
    restaurantName = trimmedName?.isNotEmpty == true ? trimmedName : null;
    restaurantLogoUrl = trimmedLogo?.isNotEmpty == true ? trimmedLogo : null;
  }

  Future<void> initialize() async {
    unawaited(_safe(() => CustomerDisplayLanService.instance.start()));
    if (_initialized) {
      unawaited(_safe(() => showSmartPosIdleCustomerDisplay(
            restaurantName: restaurantName,
            restaurantLogoUrl: restaurantLogoUrl,
          )));
      return;
    }
    _initialized = true;
    unawaited(_safe(() => initializeWindowsCustomerDisplays(
      restaurantName: restaurantName,
      restaurantLogoUrl: restaurantLogoUrl,
    )));
  }

  /// Cart updates must not replace an on-screen payment QR.
  void showCart(Map<String, dynamic> cart) {
    // The device retains QR/result ownership, but must remember cart clears
    // and edits so it cannot restore a stale bill after payment.
    final payload = <String, dynamic>{
      ...cart,
      if (restaurantName != null && restaurantName!.isNotEmpty)
        'restaurant_name': restaurantName,
    };
    unawaited(_safe(() => showDqr222Cart(payload)));
  }

  void showIdleHome() {
    unawaited(_safe(() => showDqr222Cart(<String, dynamic>{'items': <dynamic>[]})));
    if (_paymentActive) return;
    CustomerDisplayLanService.instance.clear(reason: 'idle');
    // Cart updates talk to the DQR directly. Idle must use that same path,
    // otherwise a display that just showed a bill is left on the last cart.
    unawaited(_safe(showDqr222HomeIfIdle));
    unawaited(_safe(() => showSmartPosIdleCustomerDisplay(
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        )));
  }

  void showPaymentQr({
    required String qr,
    String? orderNumber,
    double? amount,
    String? payeeName,
    String? upiId,
    int? timeoutSeconds,
  }) {
    _paymentActive = true;
    _displayOrderNumber = orderNumber?.trim();
    final sessionId = _lanSessionId(orderNumber);
    try {
      CustomerDisplayLanService.instance.showQr(
        paymentSessionId: sessionId,
        qrData: qr,
        orderNumber: orderNumber ?? '',
        amount: amount ?? 0,
        merchant: payeeName,
        timeoutSeconds: timeoutSeconds,
        restaurantName: restaurantName,
        restaurantLogoUrl: restaurantLogoUrl,
      );
    } catch (error) {
      debugPrint('[CustomerDisplay] LAN QR skipped: $error');
    }
    unawaited(_safe(() async {
      try {
        await showSmartPosUpiQr(
          qr: qr,
          orderNumber: orderNumber,
          amount: amount,
          payeeName: payeeName,
          upiId: upiId,
          timeoutSeconds: timeoutSeconds,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        );
      } on ArgumentError catch (error) {
        debugPrint('[CustomerDisplay] payment QR skipped: $error');
      }
    }));
  }

  /// Hold & New Order: take the QR off the built-in screen and DQR so the
  /// cashier can serve the next guest. The payment itself keeps running.
  void parkHeldPayment() {
    final orderNumber = _displayOrderNumber;
    _paymentActive = false;
    _displayOrderNumber = null;
    CustomerDisplayLanService.instance.clear(
      paymentSessionId: _lanSessionId(orderNumber),
      reason: 'held',
    );
    unawaited(_safe(clearSmartPosCustomerDisplay));
  }

  /// Cash never opens the UPI QR, so the success screen has to be requested
  /// on its own. The following cart clear must not replace that screen.
  void showCashPaymentSuccess({
    required double amount,
    String? orderNumber,
  }) {
    _paymentActive = true;
    final number = orderNumber?.trim();
    _displayOrderNumber = (number == null || number.isEmpty) ? null : number;
    unawaited(_safe(() async {
      try {
        await showSmartPosPaymentSuccess(
          amount: amount,
          orderNumber: number,
          paidAt: DateTime.now(),
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        );
      } finally {
        _paymentActive = false;
        _displayOrderNumber = null;
      }
    }));
  }

  void paymentSuccess({
    required double amount,
    String? orderNumber,
    String? transactionId,
    DateTime? paidAt,
  }) {
    if (!displaysOrder(orderNumber)) return;
    _paymentActive = false;
    _displayOrderNumber = null;
    CustomerDisplayLanService.instance.paymentSuccess(
      orderNumber ?? '',
      paymentSessionId: _lanSessionId(orderNumber),
    );
    unawaited(_safe(() => showSmartPosPaymentSuccess(
          amount: amount,
          orderNumber: orderNumber,
          transactionId: transactionId,
          paidAt: paidAt,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        )));
  }

  void paymentFailed({required String orderNumber}) {
    if (!displaysOrder(orderNumber)) return;
    _paymentActive = false;
    _displayOrderNumber = null;
    CustomerDisplayLanService.instance.paymentFailed(
      orderNumber,
      paymentSessionId: _lanSessionId(orderNumber),
    );
    unawaited(_safe(() => showDqr222PaymentFailed(orderNumber: orderNumber)));
  }

  void paymentExpired({String? orderNumber}) {
    if (!displaysOrder(orderNumber)) return;
    _paymentActive = false;
    _displayOrderNumber = null;
    CustomerDisplayLanService.instance.paymentExpired(
      orderNumber ?? '',
      paymentSessionId: _lanSessionId(orderNumber),
    );
    unawaited(_safe(() => showSmartPosPaymentExpired(
          orderNumber: orderNumber,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        )));
  }

  void paymentCancelled({String? orderNumber}) {
    if (!displaysOrder(orderNumber)) return;
    _paymentActive = false;
    _displayOrderNumber = null;
    CustomerDisplayLanService.instance.clear(
      paymentSessionId: _lanSessionId(orderNumber),
      reason: 'cancelled',
    );
    unawaited(_safe(() => cancelSmartPosCustomerDisplay(
          orderNumber: orderNumber,
          restaurantName: restaurantName,
          restaurantLogoUrl: restaurantLogoUrl,
        )));
  }

  Future<WindowsCustomerDisplayStatus> hardwareStatus() {
    return getWindowsCustomerDisplayStatus();
  }

  Future<void> _safe(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stack) {
      debugPrint('[CustomerDisplay] $error\n$stack');
    }
  }
}
