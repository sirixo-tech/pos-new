typedef WindowsCustomerDisplayStatus = ({
  bool connected,
  String? port,
  String message,
  String? device,
});

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
  return null;
}

Future<void> clearSmartPosCustomerDisplay() async {}

Future<void> cancelSmartPosCustomerDisplay({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showSmartPosPaymentExpired({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showSmartPosIdleCustomerDisplay({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showSmartPosPaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<WindowsCustomerDisplayStatus> getWindowsCustomerDisplayStatus() async =>
    (
      connected: false,
      port: null,
      message: 'USB customer displays are supported on Windows.',
      device: null,
    );

Future<void> showWindowsCustomerDisplayHomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> initializeWindowsCustomerDisplays({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}
