import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/pos_l10n.dart';
import '../models/pos_models.dart';
import '../payments/payment_session.dart';
import '../payments/payment_session_manager.dart';
import '../services/customer_display/customer_display_broker.dart';
import '../services/pos_api.dart';
import '../services/printing/pos_receipt_printer.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../widgets/pos_ui.dart';

/// How the cashier left the UPI QR dialog.
class PosPaymentQrClose {
  const PosPaymentQrClose.paid(this.order) : held = false;
  const PosPaymentQrClose.held()
      : order = null,
        held = true;
  const PosPaymentQrClose.cancelled()
      : order = null,
        held = false;

  final PlacedPosOrder? order;
  final bool held;
}

class PosPaymentQrSheet extends StatefulWidget {
  const PosPaymentQrSheet({
    super.key,
    required this.order,
    required this.session,
    required this.serverUrl,
    required this.currency,
    this.initialPayment,
    this.timeoutSeconds = 300,
  });

  final PlacedPosOrder order;
  final PosSession session;
  final String serverUrl;
  final String currency;
  final PosOrderPaymentInfo? initialPayment;
  final int timeoutSeconds;

  static Future<PosPaymentQrClose?> show(
    BuildContext context, {
    required PlacedPosOrder order,
    required PosSession session,
    required String serverUrl,
    required String currency,
    PosOrderPaymentInfo? initialPayment,
    int timeoutSeconds = 300,
  }) {
    return showDialog<PosPaymentQrClose>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => PosPaymentQrSheet(
        order: order,
        session: session,
        serverUrl: serverUrl,
        currency: currency,
        initialPayment: initialPayment,
        timeoutSeconds: timeoutSeconds,
      ),
    );
  }

  @override
  State<PosPaymentQrSheet> createState() => _PosPaymentQrSheetState();
}

class _PosPaymentQrSheetState extends State<PosPaymentQrSheet> {
  final _api = PosApi();
  Timer? _pollTimer;
  Timer? _countdownTimer;
  PosOrderPaymentInfo? _payment;
  bool _loadingQr = false;
  bool _printing = false;
  bool _checking = false;
  String? _qrError;
  int _secondsRemaining = 300;
  int _timeoutTotal = 300;
  bool _displayReleased = false;
  String? _paymentSessionId;
  Future<void>? _persistFuture;

  String get _gateway {
    return (_payment?.gateway ?? widget.initialPayment?.gateway ?? '')
        .trim()
        .toLowerCase();
  }

  String get _gatewayName {
    switch (_gateway) {
      case 'phonepe':
      case 'paytm':
        return 'UPI QR';
      default:
        return context.l10n.payUpi;
    }
  }

  Color get _gatewayAccent => const Color(0xFF059669);

  String? get _gatewayLogoUrl {
    final base = widget.serverUrl.replaceAll(RegExp(r'/+$'), '');
    switch (_gateway) {
      case 'phonepe':
        return '$base/images/upi-apps/phonepe.png';
      case 'paytm':
        return '$base/images/upi-apps/paytm.png';
      default:
        return null;
    }
  }

  String get _timerLabel {
    final m = _secondsRemaining ~/ 60;
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _timerProgress {
    if (_timeoutTotal <= 0) return 0;
    return (_secondsRemaining / _timeoutTotal).clamp(0.0, 1.0);
  }

  bool get _timerUrgent => _secondsRemaining <= 60;

  @override
  void initState() {
    super.initState();
    _payment = widget.initialPayment;
    final held = _paymentFromActiveSession();
    if (!_qrIsShowable(_payment?.qr) && held != null) {
      _payment = held;
    }
    _timeoutTotal = _payment?.timeoutSeconds ?? widget.timeoutSeconds;
    _secondsRemaining = _timeoutTotal;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 0) {
        _closeWithFailure();
        return;
      }
      setState(() => _secondsRemaining--);
    });
    if (!_qrIsShowable(_payment?.qr)) {
      _loadQr();
    } else {
      _pushHardwareQr(_payment!);
      _persistFuture = _persistPaymentSession(_payment!);
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (!_displayReleased) {
      CustomerDisplayBroker.instance.paymentCancelled(
        orderNumber: widget.order.orderNumber,
      );
    }
    super.dispose();
  }

  bool _qrIsShowable(PaymentQrData? qr) {
    if (qr == null) return false;
    if (qr.upiUrl.trim().isNotEmpty) return true;
    final image = qr.qrUrl.trim().toLowerCase();
    return image.startsWith('http://') || image.startsWith('https://');
  }

  /// The QR already running for this order. A second generate call is what
  /// returns "Could not generate QR" while that code is still live.
  PosOrderPaymentInfo? _paymentFromActiveSession() {
    final existing =
        PaymentSessionManager.instance.sessionForOrder(widget.order.id);
    if (existing == null ||
        existing.status.isTerminal ||
        !DateTime.now().isBefore(existing.expiresAt) ||
        existing.qrData.trim().isEmpty) {
      return null;
    }
    final requested = widget.order.chargeAmount;
    if (requested > 0 && (existing.amount - requested).abs() >= 0.005) {
      return null;
    }
    final remaining =
        existing.expiresAt.difference(DateTime.now()).inSeconds.clamp(1, 900);
    return PosOrderPaymentInfo(
      type: 'dynamic_qr',
      gateway: widget.initialPayment?.gateway ?? 'upi',
      timeoutSeconds: remaining,
      amount: existing.amount,
      qr: PaymentQrData(
        upiUrl: existing.qrData.trim(),
        qrUrl: '',
        displayUpiId: '',
        payeeName: '',
      ),
    );
  }

  void _showPayment(PosOrderPaymentInfo loaded) {
    setState(() {
      _payment = loaded;
      _loadingQr = false;
      _qrError = null;
      _timeoutTotal = loaded.timeoutSeconds;
      _secondsRemaining = loaded.timeoutSeconds;
    });
    _pushHardwareQr(loaded);
    _persistFuture = _persistPaymentSession(loaded);
    _startPolling();
  }

  Future<void> _loadQr() async {
    final held = _paymentFromActiveSession();
    if (held != null) {
      if (!mounted) return;
      _showPayment(held);
      return;
    }
    setState(() {
      _loadingQr = true;
      _qrError = null;
    });
    try {
      final loaded = await _api.fetchPaymentQr(
        widget.session,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      if (!_qrIsShowable(loaded.qr)) {
        final fallback = _paymentFromActiveSession();
        if (fallback != null) {
          _showPayment(fallback);
          return;
        }
        setState(() {
          _loadingQr = false;
          _qrError = context.l10n.qrGenerateFailed;
        });
        return;
      }
      _showPayment(loaded);
    } catch (_) {
      if (!mounted) return;
      final fallback = _paymentFromActiveSession();
      if (fallback != null) {
        _showPayment(fallback);
        return;
      }
      setState(() {
        _loadingQr = false;
        _qrError = context.l10n.qrGenerateFailed;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      final data = await _api.fetchPaymentStatus(
        widget.session,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      if (data['paid'] == true) {
        final orderJson = data['order'];
        if (orderJson is Map<String, dynamic>) {
          await _markSessionPaid(printed: true);
          if (!mounted) return;
          _releaseHardwareDisplay(success: true);
          Navigator.of(context, rootNavigator: true).pop(
            PosPaymentQrClose.paid(PlacedPosOrder.fromJson(orderJson)),
          );
          return;
        }
      }
      if (data['failed'] == true || data['timed_out'] == true) {
        _closeWithFailure();
        return;
      }
      setState(() => _checking = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  void _closeWithFailure() {
    if (!mounted) return;
    unawaited(_markSessionStatus(PaymentSessionStatus.expired));
    _releaseHardwareDisplay(expired: true);
    Navigator.of(context, rootNavigator: true)
        .pop(const PosPaymentQrClose.cancelled());
    showPosSnackBar(context, context.l10n.qrTimedOut, error: true);
  }

  Future<void> _cancelPayment() async {
    final l10n = context.l10n;
    final ok = await showPosConfirmDialog(
      context,
      title: l10n.qrCancelTitle,
      message: l10n.qrCancelMessage(_gatewayName),
      confirmLabel: l10n.qrCancelConfirm,
      cancelLabel: l10n.qrKeepWaiting,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _markSessionStatus(PaymentSessionStatus.cancelled);
    if (!mounted) return;
    _releaseHardwareDisplay(cancelled: true);
    Navigator.of(context, rootNavigator: true)
        .pop(const PosPaymentQrClose.cancelled());
  }

  /// Close the dialog and clear the customer QR so the next sale can use the
  /// display. The payment keeps running and can be reopened from the search bar.
  Future<void> _holdAndNewOrder() async {
    if (!mounted) return;
    _displayReleased = true;
    CustomerDisplayBroker.instance.parkHeldPayment();
    try {
      await _persistFuture;
    } catch (_) {}
    final id = _paymentSessionId ??
        PaymentSessionManager.instance
            .sessionForOrder(widget.order.id)
            ?.paymentSessionId;
    if (id != null) {
      try {
        await PaymentSessionManager.instance.markHeldForNewOrder(id);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pop(const PosPaymentQrClose.held());
  }

  Future<void> _persistPaymentSession(PosOrderPaymentInfo payment) async {
    final qr = payment.qr?.upiUrl.trim() ?? '';
    if (qr.isEmpty || widget.order.id <= 0) return;
    final amount = payment.amount ?? widget.order.chargeAmount;
    final existing =
        PaymentSessionManager.instance.sessionForOrder(widget.order.id);
    if (existing != null && existing.canReuseQrFor(widget.order.id, amount)) {
      _paymentSessionId = existing.paymentSessionId;
      if (existing.status == PaymentSessionStatus.waitingForDisplay) {
        await PaymentSessionManager.instance.transition(
          existing.paymentSessionId,
          PaymentSessionStatus.displayingQr,
        );
        await PaymentSessionManager.instance.transition(
          existing.paymentSessionId,
          PaymentSessionStatus.waitingPayment,
        );
      } else if (existing.status == PaymentSessionStatus.displayingQr) {
        await PaymentSessionManager.instance.transition(
          existing.paymentSessionId,
          PaymentSessionStatus.waitingPayment,
        );
      }
      PaymentSessionManager.instance.monitor(existing.paymentSessionId);
      return;
    }
    try {
      final session = await PaymentSessionManager.instance.createPersisted(
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        transactionId: null,
        amount: amount,
        qrData: qr,
        timeoutSeconds: payment.timeoutSeconds,
        orderSnapshot: {
          'id': widget.order.id,
          'order_number': widget.order.orderNumber,
        },
      );
      _paymentSessionId = session.paymentSessionId;
      await PaymentSessionManager.instance.transition(
        session.paymentSessionId,
        PaymentSessionStatus.displayingQr,
      );
      await PaymentSessionManager.instance.transition(
        session.paymentSessionId,
        PaymentSessionStatus.waitingPayment,
      );
      PaymentSessionManager.instance.monitor(session.paymentSessionId);
    } catch (_) {}
  }

  Future<void> _markSessionPaid({required bool printed}) async {
    final id = _paymentSessionId;
    if (id == null) return;
    if (printed) {
      await PaymentSessionManager.instance.markReceiptPrinted(id);
    }
    await PaymentSessionManager.instance.transition(
      id,
      PaymentSessionStatus.paid,
    );
  }

  Future<void> _markSessionStatus(PaymentSessionStatus status) async {
    final id = _paymentSessionId;
    if (id == null) return;
    await PaymentSessionManager.instance.transition(id, status);
  }

  void _pushHardwareQr(PosOrderPaymentInfo payment) {
    final qr = payment.qr;
    final upiUrl = qr?.upiUrl.trim() ?? '';
    if (upiUrl.isEmpty) return;
    CustomerDisplayBroker.instance.showPaymentQr(
      qr: upiUrl,
      orderNumber: widget.order.orderNumber,
      amount: payment.amount ?? widget.order.chargeAmount,
      payeeName: qr?.payeeName,
      upiId: qr?.displayUpiId,
      timeoutSeconds: payment.timeoutSeconds,
    );
  }

  void _releaseHardwareDisplay({
    bool success = false,
    bool expired = false,
    bool cancelled = false,
  }) {
    if (_displayReleased) return;
    _displayReleased = true;
    final broker = CustomerDisplayBroker.instance;
    final orderNumber = widget.order.orderNumber;
    if (success) {
      broker.paymentSuccess(
        amount: _payment?.amount ?? widget.order.chargeAmount,
        orderNumber: orderNumber,
        paidAt: DateTime.now(),
      );
    } else if (expired) {
      broker.paymentExpired(orderNumber: orderNumber);
    } else if (cancelled) {
      broker.paymentCancelled(orderNumber: orderNumber);
    } else {
      broker.paymentFailed(orderNumber: orderNumber);
    }
  }

  Future<void> _printQrSlip() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await PosReceiptPrinter.printPaymentQrSlip(
        session: widget.session,
        serverUrl: widget.serverUrl,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.qrSlipPrinted);
    } catch (e) {
      if (!mounted) return;
      showPosSnackBar(context, context.l10n.qrSlipPrintFailed, error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = _gatewayAccent;
    final qr = _payment?.qr;
    final total = _payment?.amount ??
        widget.initialPayment?.amount ??
        widget.order.chargeAmount;
    final media = MediaQuery.sizeOf(context);
    final compact = media.height < 720 || media.width < 420;
    final qrSize = compact ? 180.0 : 228.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: compact ? 16 : 28,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: media.height * 0.9,
        ),
        child: Material(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GatewayHeader(
                brand: brand,
                gatewayName: _gatewayName,
                logoUrl: _gatewayLogoUrl,
                timerLabel: _timerLabel,
                timerProgress: _timerProgress,
                urgent: _timerUrgent,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 16 : 20, 20, 8),
                  child: Column(
                    children: [
                      Text(
                        formatMoney(total, widget.currency),
                        style: TextStyle(
                          fontSize: compact ? 30 : 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: PosTheme.ink,
                          height: 1.05,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PosTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: PosTheme.border),
                        ),
                        child: Text(
                          l10n.qrOrderLabel(widget.order.orderNumber),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: PosTheme.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_loadingQr)
                        _LoadingBlock(brand: brand)
                      else if (_qrError != null || !_qrIsShowable(qr))
                        _ErrorBlock(
                          brand: brand,
                          message: _qrError ?? l10n.qrUnavailable,
                          onRetry: _loadQr,
                        )
                      else ...[
                        _QrCard(
                          brand: brand,
                          qrUrl: qr!.qrUrl,
                          upiUrl: qr.upiUrl,
                          size: qrSize,
                        ),
                        const SizedBox(height: 12),
                        _StatusRow(
                          brand: brand,
                          checking: _checking,
                          text: l10n.qrWaiting,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _FooterActions(
                brand: brand,
                showPrint: _qrIsShowable(qr) && PosReceiptPrinter.isSupported,
                showHold: _qrIsShowable(qr) && _qrError == null,
                printing: _printing,
                onPrint: _printQrSlip,
                onHold: _holdAndNewOrder,
                onCancel: _cancelPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayHeader extends StatelessWidget {
  const _GatewayHeader({
    required this.brand,
    required this.gatewayName,
    required this.logoUrl,
    required this.timerLabel,
    required this.timerProgress,
    required this.urgent,
  });

  final Color brand;
  final String gatewayName;
  final String? logoUrl;
  final String timerLabel;
  final double timerProgress;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timerColor = urgent ? const Color(0xFFDC2626) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: PosTheme.modalHeaderGradient(seed: brand),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: logoUrl != null
                ? CachedNetworkImage(
                    imageUrl: logoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Icon(
                      Icons.qr_code_2_rounded,
                      color: brand,
                    ),
                  )
                : Icon(Icons.qr_code_2_rounded, color: brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qrScanToPay,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gatewayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: urgent ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: timerProgress,
                        strokeWidth: 3,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.18),
                        color: timerColor,
                      ),
                      Text(
                        timerLabel,
                        style: TextStyle(
                          color: timerColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  urgent ? l10n.qrHurry : l10n.qrTimeLeft,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.brand,
    required this.qrUrl,
    required this.upiUrl,
    required this.size,
  });

  final Color brand;
  final String qrUrl;
  final String upiUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PosTheme.border),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: PosTheme.canvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PosTheme.border.withValues(alpha: 0.85),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _QrPicture(
              brand: brand,
              qrUrl: qrUrl,
              upiUrl: upiUrl,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.qrAskCustomer,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: PosTheme.inkMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPicture extends StatelessWidget {
  const _QrPicture({
    required this.brand,
    required this.qrUrl,
    required this.upiUrl,
  });

  final Color brand;
  final String qrUrl;
  final String upiUrl;

  @override
  Widget build(BuildContext context) {
    final image = qrUrl.trim();
    final payload = upiUrl.trim();
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.contain,
        placeholder: (_, _) => Center(
          child: CircularProgressIndicator(strokeWidth: 2.5, color: brand),
        ),
        errorWidget: (_, _, _) => payload.isEmpty
            ? Icon(Icons.broken_image_outlined, color: PosTheme.inkFaint, size: 36)
            : QrImageView(
                data: payload,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
              ),
      );
    }
    if (payload.isNotEmpty) {
      return QrImageView(
        data: payload,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(8),
      );
    }
    return Icon(Icons.broken_image_outlined, color: PosTheme.inkFaint, size: 36);
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.brand,
    required this.checking,
    required this.text,
  });

  final Color brand;
  final bool checking;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.border.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: checking
                ? CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: brand,
                  )
                : Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brand.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PosTheme.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.brand});

  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: brand),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.qrGenerating,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: PosTheme.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.brand,
    required this.message,
    required this.onRetry,
  });

  final Color brand;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = posStatusColors('pending');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: tone.fg,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tone.fg,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.commonTryAgain),
            style: OutlinedButton.styleFrom(
              foregroundColor: brand,
              side: BorderSide(color: brand.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.brand,
    required this.showPrint,
    required this.showHold,
    required this.printing,
    required this.onPrint,
    required this.onHold,
    required this.onCancel,
  });

  final Color brand;
  final bool showPrint;
  final bool showHold;
  final bool printing;
  final VoidCallback onPrint;
  final VoidCallback onHold;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: PosTheme.canvas,
        border: Border(
          top: BorderSide(color: PosTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: Column(
        children: [
          if (showHold) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onHold,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B1A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: Text(
                  context.posText('qrHoldNewOrder', 'Hold & New Order'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (showPrint)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: printing ? null : onPrint,
                    icon: printing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: brand,
                            ),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(printing ? l10n.qrPrinting : l10n.qrPrintSlip),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosTheme.ink,
                      minimumSize: const Size(0, 46),
                      side: BorderSide(color: PosTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (showPrint) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    minimumSize: const Size(0, 46),
                    side: BorderSide(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.commonCancel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
