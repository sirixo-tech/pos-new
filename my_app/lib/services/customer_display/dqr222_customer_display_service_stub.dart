import 'dqr222_media_protocol.dart';
import 'dart:typed_data';

typedef Dqr222DisplayStatus = ({bool connected, String? port, String message});

/// Always null: DQR-222 is not supported on this platform.
String? get dqr222LastKnownPort => null;

Future<Dqr222DisplayStatus> getDqr222DisplayStatus() async => (
  connected: false,
  port: null,
  message: 'DQR-222 customer display is not supported on this platform.',
);

Future<void> initializeDqr222CustomerDisplay() async {}

Future<void> showDqr222Cart(Map<String, dynamic> cart) async {}

Future<void> showDqr222HomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<bool> showDqr222PaymentQr({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? upiId,
  String? restaurantName,
  String? restaurantLogoUrl,
  int? timeoutSeconds,
}) async => false;

Future<void> clearDqr222CustomerDisplay() async {}

Future<void> showDqr222PaymentFailed({required String orderNumber}) async {}

Future<void> showDqr222PaymentExpired({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showDqr222PaymentCancelled({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<void> showDqr222PaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {}

Future<List<Dqr222AdvertisementImage>> getDqr222AdvertisementImages({
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) async => const [];

Future<Dqr222AdvertisementUploadResult> uploadDqr222AdvertisementImage({
  required String filePath,
  required String fileName,
  Uint8List? fileBytes,
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) => Future.error(
  UnsupportedError(
    'DQR-222 advertisement management is not supported on this platform.',
  ),
);

Future<void> startDqr222AdvertisementRotation() async {}

Future<void> playDqr222Audio(String fileName) =>
    Future.error(UnsupportedError('USB display unavailable.'));

Future<List<Dqr222AdvertisementImage>> deleteDqr222AdvertisementImage(
  String fileName, {
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) => Future.error(UnsupportedError('USB display unavailable.'));
