import 'package:flutter/foundation.dart';

import 'models/customer_display_device.dart';

typedef CustomerDisplayConnection = ({
  String name,
  String address,
  String transport,
});

class CustomerDisplayLanService extends ChangeNotifier {
  CustomerDisplayLanService._();

  static final instance = CustomerDisplayLanService._();

  bool get isRunning => false;
  int get port => 8081;
  String? get pairingData => null;
  String? get errorMessage => null;
  String? get activePaymentSessionId => null;
  String? get selectedAddress => null;
  List<CustomerDisplayConnection> get connections => const [];
  List<CustomerDisplayDevice> get devices => const [];
  List<String> get connectionOptions => const [];

  Future<void> start() async {}
  Future<void> restart() async {}
  Future<void> refreshPairingCode() async {}
  Future<void> selectConnection(String address) async {}
  Future<void> disconnect(String id) async {}
  void showQr({
    required String paymentSessionId,
    required String qrData,
    required String orderNumber,
    required double amount,
    String? merchant,
    int? timeoutSeconds,
    String? restaurantName,
    String? restaurantLogoUrl,
  }) {}
  void paymentSuccess(String orderNumber, {required String paymentSessionId}) {}
  void paymentFailed(String orderNumber, {required String paymentSessionId}) {}
  void paymentExpired(String orderNumber, {required String paymentSessionId}) {}
  void releaseExpired(String paymentSessionId) {}
  void clear({String? paymentSessionId, String reason = 'cleared'}) {}
}
