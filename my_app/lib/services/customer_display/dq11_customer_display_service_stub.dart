import 'dart:typed_data';

typedef Dq11DisplayStatus = ({bool connected, String? port, String message});

Future<Uint8List> renderCustomerDisplayPaymentJpeg({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? restaurantName,
  String? restaurantLogoUrl,
  DateTime? expiresAt,
}) => Future.error(UnsupportedError('Customer display rendering unavailable.'));

Future<Uint8List> renderCustomerDisplayReadyJpeg({
  String? restaurantName,
  String? restaurantLogoUrl,
}) => Future.error(UnsupportedError('Customer display rendering unavailable.'));

Future<Uint8List> renderCustomerDisplayExpiredJpeg({
  String? restaurantName,
  String? restaurantLogoUrl,
  int graceSeconds = 0,
}) => Future.error(UnsupportedError('Customer display rendering unavailable.'));

Future<Uint8List> renderCustomerDisplayCancelledJpeg({
  String? orderNumber,
  String? restaurantName,
}) => Future.error(UnsupportedError('Customer display rendering unavailable.'));

Future<Uint8List> renderCustomerDisplaySuccessJpeg({
  required double amount,
  required DateTime paidAt,
  String? orderNumber,
  String? transactionId,
  String? restaurantName,
}) => Future.error(UnsupportedError('Customer display rendering unavailable.'));

Future<Dq11DisplayStatus> getDq11DisplayStatus() async {
  return (
    connected: false,
    port: null,
    message: 'DQ11 QR display is not supported on this platform.',
  );
}

Future<void> showDq11HomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<bool> showDq11PaymentQr({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? upiId,
  String? restaurantName,
  String? restaurantLogoUrl,
  int? timeoutSeconds,
}) async {
  return false;
}

Future<void> clearDq11CustomerDisplay() async {}

Future<void> showDq11PaymentCancelled({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showDq11PaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}
