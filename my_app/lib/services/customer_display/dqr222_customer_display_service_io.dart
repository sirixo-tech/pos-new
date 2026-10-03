import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_codec;

import 'android_usb_customer_display_transport.dart';
import 'customer_voice_service.dart';
import 'dqr222_customer_display_protocol.dart';
import 'dqr222_cart_renderer.dart';
import 'dqr222_media_protocol.dart';
import 'windows_dqr222_connection.dart';

const _dqr222BaudRate = 230400;
const _dqr222Volume = 18;
const _dqr222ResultDuration = Duration(seconds: 1);
const _dqr222StartupRetryDelay = Duration(seconds: 2);
const _dqr222StartupAttempts = 4;

Future<void>? _dqr222WriteQueue;
final _windowsConnection = WindowsDqr222Connection();
Timer? _expiryTimer;
bool _paymentScreenActive = false;
bool _homeWriteInProgress = false;
bool _mediaRestoreSuppressed = false;
String? _readyScreenKey;
String? _cartCommand;
String? _cancelledCartCommand;
bool _cartWriteInFlight = false;
int _cartWrittenGeneration = -1;
bool _useCartImage = false;
String? _lastDetectedPort;
String? _welcomedPort;
String? _activePaymentOrderNumber;
int _displayGeneration = 0;
({int generation, String key, Future<bool> result})? _paymentRequest;

typedef Dqr222DisplayStatus = ({bool connected, String? port, String message});

bool get _dqr222PlatformSupported =>
    dqr222TestTransport != null || Platform.isWindows || Platform.isAndroid;

/// Last port confirmed connected by a status poll or successful write.
/// Null means no device has been seen yet or it was explicitly disconnected.
/// This is a synchronous, zero-cost read — never runs PowerShell.
String? get dqr222LastKnownPort => _lastDetectedPort;

// Tests replace hardware only; production keeps the existing USB detection and
// text writer. This allows payment/idle races to be checked without a device.
@visibleForTesting
({
  Future<String?> Function() findPort,
  Future<void> Function(List<String>) writeCommands,
  Future<String> Function() readFileInfo,
})?
dqr222TestTransport;

@visibleForTesting
void resetDqr222ForTest() {
  _cancelTimers();
  _dqr222WriteQueue = null;
  _displayGeneration++;
  _paymentScreenActive = false;
  _homeWriteInProgress = false;
  _mediaRestoreSuppressed = false;
  _readyScreenKey = null;
  _cartCommand = null;
  _cancelledCartCommand = null;
  _useCartImage = false;
  _lastDetectedPort = null;
  _welcomedPort = null;
  _activePaymentOrderNumber = null;
  _paymentRequest = null;
  dqr222TestTransport = null;
}

Future<List<Dqr222AdvertisementImage>> getDqr222AdvertisementImages({
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) async {
  if (!_dqr222PlatformSupported) {
    throw UnsupportedError(
      'DQR-222 advertisement management is not supported on this platform.',
    );
  }
  final port = dqr222TestTransport == null && Platform.isWindows
      ? _lastDetectedPort ?? await _findDqr222Port()
      : await _findDqr222Port();
  if (port == null) {
    throw StateError('DQR-222 customer display is disconnected.');
  }
  return _queueDqr222Operation(() async {
    if (_paymentScreenActive) {
      throw StateError(
        'Wait for the current payment to finish before refreshing display files.',
      );
    }
    final response = dqr222TestTransport != null
        ? await dqr222TestTransport!.readFileInfo()
        : Platform.isAndroid
        ? await readAndroidDqr222FileInfo(audio: kind == Dqr222MediaKind.audio)
        : await _readWindowsDqr222FileInfo(port, kind: kind);
    final images = parseDqr222AdvertisementFileInfo(response, kind: kind);
    _mediaRestoreSuppressed = false;
    if (!_paymentScreenActive) {
      final generation = _displayGeneration;
      // Return the list as soon as it is read. Idle restoration stays in the
      // serial queue and a newer payment invalidates it before it can run.
      unawaited(_queueCommandWrite(
        port,
        dqr222StartAdvertisementCommands,
        generation: generation,
      ).then<void>((_) {
        if (generation == _displayGeneration) _readyScreenKey = _readyKey(port);
      }).catchError((Object error) {
        _readyScreenKey = null;
        developer.log('File refresh idle restore failed: $error', name: 'SELFX.DQR222');
      }));
    }
    return images;
  });
}

Future<Dqr222AdvertisementUploadResult> uploadDqr222AdvertisementImage({
  required String filePath,
  required String fileName,
  Uint8List? fileBytes,
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) async {
  if (!_dqr222PlatformSupported) {
    throw UnsupportedError(
      'DQR-222 advertisement management is not supported on this platform.',
    );
  }
  final normalizedName = normalizeDqr222MediaFileName(fileName, kind);
  final source = File(filePath);
  if (fileBytes == null && !await source.exists()) {
    throw ArgumentError.value(
      filePath,
      'filePath',
      'Selected file is missing.',
    );
  }
  final fileSize = fileBytes?.length ?? await source.length();
  validateDqr222MediaSize(fileSize, kind);
  if (fileSize > 1966080) {
    throw const FormatException(
      'File exceeds the display storage capacity (1,966,080 bytes).',
    );
  }
  final bytes = Uint8List.fromList(fileBytes ?? await source.readAsBytes());
  validateDqr222MediaSize(bytes.length, kind);
  if (kind == Dqr222MediaKind.advertisement) {
    final jpeg = image_codec.JpegDecoder().startDecode(bytes);
    if (jpeg == null || jpeg.width != 320 || jpeg.height != 480) {
      throw const FormatException('Select a 320 x 480 portrait JPEG.');
    }
  } else if (bytes.length < 3 ||
      !((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0))) {
    throw const FormatException('Select an MP3 audio file.');
  }
  final command = buildDqr222AdvertisementUploadCommand(
    fileName: normalizedName,
    fileSize: fileSize,
    kind: kind,
  );
  final port = await _findDqr222Port();
  if (port == null) {
    throw StateError('DQR-222 customer display is disconnected.');
  }
  return _queueDqr222Operation(() async {
    if (_paymentScreenActive) {
      throw StateError(
        'Wait for the current payment to finish before uploading display media.',
      );
    }
    developer.log(
      'Media upload command=$command expectedBytes=$fileSize',
      name: 'SELFX.DQR222.MEDIA',
    );
    _readyScreenKey = null;
    // After an interrupted binary transfer, polling must not automatically
    // send more commands. A successful file refresh/reconnection recovers idle.
    _mediaRestoreSuppressed = true;
    Directory? snapshotDirectory;
    late Dqr222AdvertisementUploadResult result;
    try {
      if (Platform.isAndroid) {
        result = await _uploadAndroidDqr222Advertisement(
          bytes,
          fileName: normalizedName,
          fileSize: fileSize,
          kind: kind,
        );
      } else {
        snapshotDirectory = await Directory.systemTemp.createTemp(
          'selfx_dqr_media_',
        );
        final snapshot = File('${snapshotDirectory.path}/upload.bin');
        await snapshot.writeAsBytes(bytes, flush: true);
        result = await _uploadWindowsDqr222Advertisement(
          port,
          snapshot,
          fileName: normalizedName,
          fileSize: fileSize,
          kind: kind,
        );
      }
    } finally {
      if (snapshotDirectory != null) {
        await snapshotDirectory.delete(recursive: true);
      }
    }
    _mediaRestoreSuppressed = false;
    if (!_paymentScreenActive) {
      await _writeCommands(port, dqr222StartAdvertisementCommands);
      _readyScreenKey = _readyKey(port);
    }
    return result;
  });
}

Future<void> startDqr222AdvertisementRotation() async {
  if (!_dqr222PlatformSupported) return;
  final port = await _findDqr222Port();
  if (port == null) {
    throw StateError('DQR-222 customer display is disconnected.');
  }
  await _queueDqr222Operation(() async {
    if (_paymentScreenActive) {
      throw StateError('Advertisements cannot start during an active payment.');
    }
    await _writeCommands(port, dqr222StartAdvertisementCommands);
    _readyScreenKey = _readyKey(port);
  });
}

Future<List<Dqr222AdvertisementImage>> deleteDqr222AdvertisementImage(
  String fileName, {
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) async {
  final name = kind == Dqr222MediaKind.audio
      ? fileName.trim()
      : normalizeDqr222AdvertisementFileName(fileName);
  final command = kind == Dqr222MediaKind.audio
      ? 'delete**audio**$name'
      : buildDqr222AdvertisementDeleteCommand(fileName);
  if (!_dqr222PlatformSupported) {
    throw UnsupportedError('USB display unavailable.');
  }
  final port = dqr222TestTransport == null && Platform.isWindows
      ? _lastDetectedPort ?? await _findDqr222Port()
      : await _findDqr222Port();
  if (port == null) throw StateError('Customer display is disconnected.');
  return _queueDqr222Operation(() async {
    void ensureIdle() {
      if (_paymentScreenActive) {
        throw StateError(
          'Wait for the current payment to finish before deleting files.',
        );
      }
    }

    Future<List<Dqr222AdvertisementImage>> readFiles() async {
      final response = dqr222TestTransport != null
          ? await dqr222TestTransport!.readFileInfo()
          : Platform.isAndroid
          ? await readAndroidDqr222FileInfo(audio: kind == Dqr222MediaKind.audio)
          : await _readWindowsDqr222FileInfo(port, kind: kind);
      return parseDqr222AdvertisementFileInfo(response, kind: kind);
    }

    ensureIdle();
    final before = await readFiles();
    ensureIdle();
    if (!before.any((file) => file.fileName == name)) {
      throw StateError(
        '$name is no longer listed. Refresh files before deleting.',
      );
    }
    _readyScreenKey = null;
    _mediaRestoreSuppressed = true;
    developer.log(
      'Deleting $name command=$command',
      name: 'SELFX.DQR222.MEDIA',
    );
    var after = before;
    Object? commandError;
    for (var attempt = 0; attempt < 2; attempt++) {
      ensureIdle();
      try {
        await _writeCommands(port, ['stoprotation', command]);
      } on Object catch (error) {
        // Firmware text is not proof of filesystem state. Read back even
        // after a rejected/partial acknowledgement; never delete another file.
        commandError = error;
      }
      after = await readFiles();
      if (!after.any((file) => file.fileName == name)) break;
      // Confirm all unrelated files survived before retrying this exact name.
      verifyDqr222AdvertisementDeletion(
        fileName: name,
        before: before,
        after: after.where((file) => file.fileName != name).toList(),
      );
    }
    try {
      verifyDqr222AdvertisementDeletion(fileName: name, before: before, after: after);
    } on Object catch (error) {
      throw StateError('$error${commandError == null ? '' : ' Device response: $commandError'}');
    }
    developer.log(
      'Deletion verified: $name absent; other files unchanged',
      name: 'SELFX.DQR222.MEDIA',
    );
    _mediaRestoreSuppressed = false;
    if (!_paymentScreenActive &&
        kind == Dqr222MediaKind.advertisement &&
        after.any((file) => file.fileName.toLowerCase().endsWith('.jpeg'))) {
      final generation = _displayGeneration;
      // A later idle-screen error must not hide a verified deletion from the
      // file list or report that deleting the file failed.
      unawaited(_queueCommandWrite(
        port,
        dqr222StartAdvertisementCommands,
        generation: generation,
      ).then<void>((_) {
        if (generation == _displayGeneration) _readyScreenKey = _readyKey(port);
      }).catchError((Object error) {
        _readyScreenKey = null;
        developer.log('Delete idle restore failed: $error', name: 'SELFX.DQR222');
      }));
    }
    return after;
  });
}

Future<void> playDqr222Audio(String fileName) async {
  normalizeDqr222MediaFileName(fileName, Dqr222MediaKind.audio);
  if (!_dqr222PlatformSupported) {
    throw UnsupportedError('USB display unavailable.');
  }
  final port = await _findDqr222Port();
  if (port == null) throw StateError('DQR-222 is disconnected.');
  await _queueDqr222Operation(() async {
    if (_paymentScreenActive) {
      throw StateError('Wait for the current payment to finish.');
    }
    await _writeCommands(port, [
      'audioon',
      'setvolume**$_dqr222Volume',
      'play**$fileName',
    ]);
  });
}

/// Detects a DQR-222 during application startup and puts it on its home page.
///
/// Windows may publish the USB serial port shortly after Flutter starts, so a
/// single lookup can miss a correctly connected device. Retrying here also
/// means the welcome screen does not depend on staff login or POS navigation.
Future<void> initializeDqr222CustomerDisplay() async {
  if (!_dqr222PlatformSupported) return;
  for (var attempt = 0; attempt < _dqr222StartupAttempts; attempt++) {
    await showDqr222HomeIfIdle();
    if (_readyScreenKey != null) return;
    if (attempt < _dqr222StartupAttempts - 1) {
      await Future<void>.delayed(_dqr222StartupRetryDelay);
    }
  }
  developer.log(
    'DQR-222 was not ready after the startup attempts.',
    name: 'SELFX.DQR222',
  );
}

Future<Dqr222DisplayStatus> getDqr222DisplayStatus() async {
  if (!_dqr222PlatformSupported) {
    return (
      connected: false,
      port: null,
      message: 'DQR-222 customer display is not supported on this platform.',
    );
  }
  final port = await _findDqr222Port(forceDiscovery: true);
  final ownedPort = _windowsConnection.connectedPort;
  if (ownedPort != null && ownedPort != port) {
    await _queueDqr222Operation(() async {
      if (_windowsConnection.connectedPort == ownedPort) {
        await _windowsConnection.close();
      }
    });
  }
  if (port == null) {
    _paymentRequest = null;
    _lastDetectedPort = null;
    _welcomedPort = null;
    _readyScreenKey = null;
    _mediaRestoreSuppressed = false;
    return (
      connected: false,
      port: null,
      message: 'DQR-222 customer display is disconnected.',
    );
  }
  final shouldRestoreHome =
      !_paymentScreenActive &&
      (_lastDetectedPort != port || _readyScreenKey != _readyKey(port));
  _lastDetectedPort = port;
  if (shouldRestoreHome) {
    // USB serial devices can appear after the startup retry window and may
    // receive a different COM number when moved to another physical socket.
    // Status polling therefore doubles as a reconnect trigger so the POS
    // home image is restored without restarting the application.
    unawaited(showDqr222HomeIfIdle());
  }
  return (
    connected: true,
    port: port,
    message: 'DQR-222 customer display connected on $port.',
  );
}

Future<void> showDqr222HomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dqr222PlatformSupported ||
      _mediaRestoreSuppressed ||
      _paymentScreenActive ||
      _homeWriteInProgress) {
    return;
  }
  // Claim the home update before the asynchronous port lookup. Startup,
  // connection polling and POS navigation can all request the home screen at
  // the same time; claiming it later allowed several welcome/audio writes to
  // enter the serial queue ahead of a payment QR.
  _homeWriteInProgress = true;
  String? port;
  try {
    _rememberRestaurant(restaurantName, restaurantLogoUrl);
    final generation = _displayGeneration;
    port = await _findDqr222Port();
    if (port == null ||
        _paymentScreenActive ||
        generation != _displayGeneration) {
      return;
    }
    final key = _readyKey(port);
    // A bill on screen uses the same ready key as the home screen. Treating
    // that as "already home" left the last cart up after a line was removed
    // or the cart was cleared.
    final cartOnScreen = _cartCommand != null;
    if (!cartOnScreen && _readyScreenKey == key) return;
    // Background idle/status refreshes never own an active cart. Only an
    // explicit empty-cart update may remove the current bill.
    if (cartOnScreen) return;
    final homeGeneration = _displayGeneration;
    await _writeReady(port, homeGeneration);
    if (homeGeneration == _displayGeneration) {
      developer.log('Home screen displayed on $port', name: 'SELFX.DQR222');
    }
  } on Object catch (error) {
    _readyScreenKey = null;
    developer.log('Home screen failed on $port: $error', name: 'SELFX.DQR222');
  } finally {
    _homeWriteInProgress = false;
  }
}

Future<void> showDqr222Cart(Map<String, dynamic> cart) async {
  if (!_dqr222PlatformSupported) return;
  final command = (cart['items'] as List? ?? const []).isEmpty
      ? null
      : buildDqr222BillCommand(cart);
  if (command != null && command == _cancelledCartCommand) return;
  if (command == null) _cancelledCartCommand = null;
  if (command == _cartCommand && _readyScreenKey != null) return;
  _cartCommand = command;
  _readyScreenKey = null;
  // Remember edits during payment, but let QR/results retain screen ownership.
  if (_paymentScreenActive || _mediaRestoreSuppressed) return;
  ++_displayGeneration;
  // A burst of item taps must not stack a full serial write per tap.
  // The in-flight write finishes, then one write sends the latest cart.
  if (_cartWriteInFlight) return;
  await _drainCartDisplay();
}

Future<void> _drainCartDisplay() async {
  if (_cartWriteInFlight || _paymentScreenActive || _mediaRestoreSuppressed) {
    return;
  }
  _cartWriteInFlight = true;
  var followUp = false;
  var failures = 0;
  try {
    while (!_paymentScreenActive && !_mediaRestoreSuppressed) {
      final generation = _displayGeneration;
      final port = await _findDqr222Port();
      if (port == null || _paymentScreenActive || _mediaRestoreSuppressed) {
        return;
      }
      if (generation != _displayGeneration) continue;
      try {
        await _writeReady(port, generation);
      } on Object catch (error) {
        // Do not abandon a newer cart because an obsolete serial write failed.
        if (generation != _displayGeneration) continue;
        if (generation == _displayGeneration) {
          _lastDetectedPort = null;
          _readyScreenKey = null;
        }
        developer.log(
          'Cart display failed on $port: $error',
          name: 'SELFX.DQR222',
        );
        // A single failed latest write must not leave the previous bill on
        // screen indefinitely. Retry through discovery with the newest cart.
        if (++failures <= 2) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          continue;
        }
        return;
      }
      if (generation == _displayGeneration) {
        _cartWrittenGeneration = generation;
        followUp = true;
        return;
      }
    }
  } finally {
    _cartWriteInFlight = false;
    if (followUp &&
        !_paymentScreenActive &&
        !_mediaRestoreSuppressed &&
        _displayGeneration != _cartWrittenGeneration) {
      unawaited(_drainCartDisplay());
    }
  }
}

Future<bool> showDqr222PaymentQr({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? upiId,
  String? restaurantName,
  String? restaurantLogoUrl,
  int? timeoutSeconds,
}) async {
  final key = jsonEncode([
    orderNumber,
    buildDqr222PaymentCommand(qr: qr, amount: amount, upiId: upiId),
  ]);
  final previous = _paymentRequest;
  if (previous != null &&
      previous.generation == _displayGeneration &&
      previous.key == key &&
      _paymentScreenActive) {
    // Share both pending and completed writes. Do not restart expiry or audio.
    return previous.result;
  }
  final result = _showDqr222PaymentQr(
    qr: qr,
    orderNumber: orderNumber,
    amount: amount,
    payeeName: payeeName,
    upiId: upiId,
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
    timeoutSeconds: timeoutSeconds,
  );
  _paymentRequest = (generation: _displayGeneration, key: key, result: result);
  try {
    final shown = await result;
    if (!shown && identical(_paymentRequest?.result, result)) {
      _paymentRequest = null;
    }
    return shown;
  } on Object {
    if (identical(_paymentRequest?.result, result)) _paymentRequest = null;
    rethrow;
  }
}

Future<bool> _showDqr222PaymentQr({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? upiId,
  String? restaurantName,
  String? restaurantLogoUrl,
  int? timeoutSeconds,
}) async {
  if (!_dqr222PlatformSupported) return false;
  final requestTimer = Stopwatch()..start();
  final generation = ++_displayGeneration;
  _cancelTimers();
  _paymentScreenActive = true;
  _activePaymentOrderNumber = orderNumber;
  _readyScreenKey = null;
  _rememberRestaurant(restaurantName, restaurantLogoUrl);
  final timeout = timeoutSeconds != null && timeoutSeconds > 0
      ? timeoutSeconds
      : 300;
  final port = await _findDqr222Port();
  debugPrint(
    '[DQR222][TIMING] payment portLookupMs=${requestTimer.elapsedMilliseconds}',
  );
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return false;
  }

  // Keep payment writes in the same queue as home and result writes.
  // The worker retains the COM port between text updates.
  var nativeScreenShown = false;
  try {
    try {
      await _queueCommandWrite(port, [
        'stoprotation',
        // Payment expiry is owned by _expiryTimer, not the ad interval.
        buildDqr222PaymentCommand(qr: qr, amount: amount, upiId: upiId),
        'stoprotation',
      ], generation: generation);
      if (generation != _displayGeneration) return false;
      nativeScreenShown = true;
    } on Object catch (error) {
      developer.log(
        'Native payment command failed on $port: $error',
        name: 'SELFX.DQR222',
      );
    }
    if (nativeScreenShown) {
      _expiryTimer = Timer(
        Duration(seconds: timeout),
        () => unawaited(
          _showExpired(port, generation: generation, orderNumber: orderNumber),
        ),
      );
      developer.log(
        'Native payment QR displayed on $port',
        name: 'SELFX.DQR222',
      );
      return true;
    }
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return false;
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      _paymentScreenActive = false;
      _cancelTimers();
    }
    developer.log(
      'Payment display failed on $port: $error',
      name: 'SELFX.DQR222',
    );
    debugPrint('[DQR222][PAYMENT] display failed on $port: $error');
    return false;
  }
}

Future<void> clearDqr222CustomerDisplay() async {
  if (!_dqr222PlatformSupported) return;
  _cartCommand = null;
  _readyScreenKey = null;
  _activePaymentOrderNumber = null;
  final generation = ++_displayGeneration;
  _paymentScreenActive = false;
  _cancelTimers();
  final port = await _findDqr222Port();
  if (port == null) return;
  // Wait for exclusive serial ownership before restoring home.
  await _waitForDisplayWrites();
  try {
    await _writeReady(port, generation);
  } on Object catch (error) {
    _readyScreenKey = null;
    developer.log('Clear failed on $port: $error', name: 'SELFX.DQR222');
  }
}

Future<void> showDqr222PaymentExpired({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dqr222PlatformSupported) return;
  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _cancelTimers();
  _rememberRestaurant(restaurantName, restaurantLogoUrl);
  final port = await _findDqr222Port();
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return;
  }
  await _waitForDisplayWrites();
  await _showExpired(port, generation: generation, orderNumber: orderNumber);
}

/// A late failure for a different order must not replace the current QR.
Future<void> showDqr222PaymentFailed({required String orderNumber}) async {
  if (!_paymentScreenActive || _activePaymentOrderNumber != orderNumber) return;
  await showDqr222PaymentExpired(orderNumber: orderNumber);
}

Future<void> showDqr222PaymentCancelled({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dqr222PlatformSupported) return;
  _cancelledCartCommand = _cartCommand;
  _cartCommand = null;
  _activePaymentOrderNumber = null;
  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _cancelTimers();
  _rememberRestaurant(restaurantName, restaurantLogoUrl);
  final port = await _findDqr222Port();
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return;
  }
  // Preserve serial ownership while the previous batch finishes.
  await _waitForDisplayWrites();
  if (generation != _displayGeneration) return;
  try {
    await _queueCommandWrite(port, [
      'stoprotation',
      'audioon',
      _nativeResultCommand(
        'DisplayCancelQRCodeScreen',
        orderNumber: orderNumber,
      ),
      'stoprotation',
    ], generation: generation);
    if (generation != _displayGeneration) return;
    unawaited(_returnHomeAfterResult(port, generation));
  } on Object catch (error) {
    developer.log(
      'Native cancelled image is unavailable on $port: $error',
      name: 'SELFX.DQR222',
    );
    if (generation != _displayGeneration) return;
    try {
      await _queueCommandWrite(port, [
        'stoprotation',
        _nativeResultCommand(
          'DisplayFailQRCodeScreen',
          orderNumber: orderNumber,
        ),
        'stoprotation',
      ], generation: generation);
    } on Object catch (fallbackError) {
      developer.log(
        'Cancellation fallback failed: $fallbackError',
        name: 'SELFX.DQR222',
      );
    }
    if (generation == _displayGeneration) {
      unawaited(_returnHomeAfterResult(port, generation));
    }
  }
}

Future<void> showDqr222PaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dqr222PlatformSupported) return;
  _cartCommand = null;
  _activePaymentOrderNumber = null;
  // The paid bill must not be written again when the success screen ends.
  _cartCommand = null;
  _cancelledCartCommand = null;
  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _cancelTimers();
  _rememberRestaurant(restaurantName, restaurantLogoUrl);
  final paidTime = paidAt ?? DateTime.now();
  final port = await _findDqr222Port();
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return;
  }
  await _waitForDisplayWrites();
  if (generation != _displayGeneration) return;
  try {
    await _queueCommandWrite(port, [
      'stoprotation',
      'audioon',
      'setvolume**$_dqr222Volume',
      _nativeResultCommand(
        'DisplaySuccessQRCodeScreen',
        mobile: transactionId,
        orderNumber: orderNumber,
        date: paidTime,
      ),
      'stoprotation',
    ], generation: generation);
    if (generation != _displayGeneration) return;
    unawaited(_returnHomeAfterResult(
      port,
      generation,
      duration: Duration.zero,
      clearCart: true,
    ));
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      unawaited(_returnHomeAfterResult(
        port,
        generation,
        duration: Duration.zero,
        clearCart: true,
      ));
    }
    developer.log('Success screen/audio failed: $error', name: 'SELFX.DQR222');
  }
}

Future<void> _showExpired(
  String port, {
  required int generation,
  String? orderNumber,
}) async {
  if (generation != _displayGeneration) return;
  _paymentRequest = null;
  _activePaymentOrderNumber = null;
  _cancelTimers();
  try {
    await _queueCommandWrite(port, [
      'stoprotation',
      'audioon',
      _nativeResultCommand('DisplayFailQRCodeScreen', orderNumber: orderNumber),
      'stoprotation',
    ], generation: generation);
    unawaited(_returnHomeAfterResult(port, generation));
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      unawaited(_returnHomeAfterResult(port, generation));
    }
    developer.log('Expired screen failed: $error', name: 'SELFX.DQR222');
  }
}

Future<void> _returnHomeAfterResult(
  String port,
  int generation, {
  Duration duration = _dqr222ResultDuration,
  bool clearCart = false,
}) async {
  if (duration > Duration.zero) {
    await Future<void>.delayed(duration);
  }
  if (generation != _displayGeneration) return;
  if (clearCart) {
    _cartCommand = null;
    _cancelledCartCommand = null;
  }
  _paymentScreenActive = false;
  try {
    await _writeReady(port, generation);
  } on Object catch (error) {
    _readyScreenKey = null;
    developer.log(
      'Could not restore the home screen on $port: $error',
      name: 'SELFX.DQR222',
    );
  }
}

Future<void> _writeReady(String port, int generation) async {
  final cart = _cartCommand;
  if (cart != null) {
    // Try the native billjson command first — it only sends a JSON payload
    // that the device firmware renders, which is vastly faster than encoding
    // and uploading a JPEG. Fall back to cart-image mode only when the device
    // rejects billjson (the flag persists for this session to avoid retrying
    // a device that does not support it).
    if (!_useCartImage) {
      try {
        await _queueCommandWrite(port, ['stoprotation', cart], generation: generation);
      } on StateError catch (error) {
        if (!error.message.toString().contains('did not acknowledge the bill')) {
          rethrow;
        }
        _useCartImage = true;
        debugPrint('[DQR222][CART] Native bill unacknowledged; using RAM JPEG display.');
      }
    }
    if (_useCartImage) {
      if (generation != _displayGeneration) return;
      final bill = jsonDecode(cart.substring('billjson**'.length)) as Map<String, dynamic>;
      final jpeg = await renderDqr222CartJpeg(bill);
      await _queueCommandWrite(port, [
        'stoprotation', '__cartjpeg**${base64Encode(jpeg)}',
      ], generation: generation);
    }
    if (generation == _displayGeneration) _readyScreenKey = _readyKey(port);
    return;
  }
  await _queueDqr222Operation(() async {
    if (generation != _displayGeneration || _mediaRestoreSuppressed) return;
    await _writeCommands(port, [
      // Advertisements own the display only while no payment is active.
      // Play the uploaded welcome once, not on every return from payment.
      'audioon',
      'setvolume**$_dqr222Volume',
      if (_welcomedPort != port) 'play**welcome.mp3',
      ...dqr222StartAdvertisementCommands,
    ]);
    _welcomedPort = port;
  });
  if (generation == _displayGeneration) {
    _readyScreenKey = _readyKey(port);
  }
}

void _rememberRestaurant(String? name, String? _) {
  // Advertisement images are already stored on the device; no artwork is
  // regenerated when restaurant metadata changes.
}

void _cancelTimers() {
  _expiryTimer?.cancel();
  _expiryTimer = null;
}

/// Aborts any in-flight serial write and clears the pending queue so that
/// cancel/clear/expired commands can execute immediately without waiting
/// behind a potentially stuck 20-second warm-session timeout.
///
/// Drain the current batch without breaking exclusive serial ownership.
Future<void> _waitForDisplayWrites() async {
  if (!Platform.isWindows) return;
  // Stale queued batches skip themselves using their display generation.
  await (_dqr222WriteQueue ?? Future<void>.value());
}

// The native WelcomeScreen is device firmware artwork. Restaurant metadata is
// not rendered into that image, so a later metadata refresh must not replay
// welcome audio or briefly restart the built-in offer rotation.
String _readyKey(String port) => port;

String _nativeResultCommand(
  String command, {
  String? mobile,
  String? orderNumber,
  DateTime? date,
}) {
  final resultDate = date ?? DateTime.now();
  final formattedDate =
      '${resultDate.day.toString().padLeft(2, '0')}-'
      '${resultDate.month.toString().padLeft(2, '0')}-'
      '${resultDate.year}';
  return '$command**${_commandField(mobile, fallback: 'SELFX')}'
      '**${_commandField(orderNumber)}**$formattedDate';
}

String _commandField(String? value, {String fallback = '-'}) {
  final sanitized = value
      ?.replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll('**', ' ')
      .trim();
  if (sanitized == null || sanitized.isEmpty) return fallback;
  return sanitized;
}

Future<String?> _findDqr222Port({bool forceDiscovery = false}) async {
  if (dqr222TestTransport != null) return dqr222TestTransport!.findPort();
  // Status polling refreshes discovery. Do not launch PowerShell/pnputil
  // again for every cart edit and payment on an already detected device.
  if (!forceDiscovery && _lastDetectedPort != null) {
    return _lastDetectedPort;
  }
  // An owned live session already identifies the device. A failed write tears
  // it down, so the next request performs full discovery again.
  if (!forceDiscovery &&
      Platform.isWindows &&
      _windowsConnection.connectedPort != null) {
    return _windowsConnection.connectedPort;
  }
  if (Platform.isAndroid) {
    final port = await findAndroidUsbCustomerDisplay('dqr222');
    _lastDetectedPort = port;
    return port;
  }
  const script = r'''
$serialPorts = @(
  [System.IO.Ports.SerialPort]::GetPortNames() |
    ForEach-Object { $_.ToUpperInvariant() } |
    Sort-Object -Unique
)

# The Enum registry keeps removed devices, so PortName alone can select a
# stale COM port. pnputil's /connected list gives the ports that are actually
# present now and continues to work when Windows assigns a different COM
# number after the cable is moved to another USB socket.
$activePorts = @()
try {
  $pnputil = Join-Path $env:WINDIR 'System32\pnputil.exe'
  $deviceLines = @(& $pnputil /enum-devices /connected /class Ports 2>$null)
  foreach ($line in $deviceLines) {
    foreach ($match in [regex]::Matches([string]$line, '\((COM\d+)\)')) {
      $activePorts += $match.Groups[1].Value.ToUpperInvariant()
    }
  }
  $activePorts = @($activePorts | Sort-Object -Unique)
} catch {
  $activePorts = @()
}

$connectedPorts = if ($activePorts.Count -gt 0) {
  @($serialPorts | Where-Object { $activePorts -contains $_ })
} else {
  $serialPorts
}
$override = $env:SELFX_DQR222_PORT_OVERRIDE
if ($override) {
  $override = $override.Trim().ToUpperInvariant()
  if ($override -match '^COM\d+$' -and $connectedPorts -contains $override) {
    [Console]::Out.Write($override)
    exit 0
  }
}

$candidates = @()
$usbRoots = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB' -ErrorAction SilentlyContinue
foreach ($usbRoot in $usbRoots) {
  foreach ($instance in (Get-ChildItem $usbRoot.PSPath -ErrorAction SilentlyContinue)) {
    $parameters = Get-ItemProperty `
      ($instance.PSPath + '\Device Parameters') `
      -ErrorAction SilentlyContinue
    $port = [string]$parameters.PortName
    $port = $port.Trim().ToUpperInvariant()
    if ($port -and $connectedPorts -contains $port) {
      $properties = Get-ItemProperty $instance.PSPath -ErrorAction SilentlyContinue
      $identity = @(
        $usbRoot.PSChildName,
        $instance.PSChildName,
        $properties.FriendlyName,
        $properties.DeviceDesc,
        $properties.Mfg,
        $properties.BusReportedDeviceDesc
      ) -join ' '
      $score = 0
      if ($usbRoot.PSChildName -like 'VID_303A&PID_1001*') { $score = 100 }
      elseif ($identity -match '(?i)DQR[ -]?222') { $score = 90 }
      elseif ($identity -match '(?i)Bonrix|Embedded Innovations') { $score = 80 }
      # Bonrix also ships this USB model with the CH340 bridge named in its
      # Windows driver download. It has a generic Windows name, so accept it
      # only through the unique-candidate rule below.
      elseif ($usbRoot.PSChildName -like 'VID_1A86&PID_7523*') { $score = 70 }
      if (
        $score -gt 0 -and
        $usbRoot.PSChildName -notlike 'VID_0525&PID_A4A7*' -and
        $usbRoot.PSChildName -notlike 'VID_0483&PID_5740*'
      ) {
        $candidates += [pscustomobject]@{ Port = $port; Score = $score }
      }
    }
  }
}

$ranked = @($candidates | Sort-Object Score -Descending | Group-Object Port | ForEach-Object {
  $_.Group | Sort-Object Score -Descending | Select-Object -First 1
})
if ($ranked.Count -gt 0 -and $ranked[0].Score -ge 80) {
  [Console]::Out.Write($ranked[0].Port)
  exit 0
}
$bridgeCandidates = @($ranked | Where-Object { $_.Score -eq 70 })
if ($bridgeCandidates.Count -eq 1) {
  [Console]::Out.Write($bridgeCandidates[0].Port)
  exit 0
}
''';
  try {
    final result = await Process.run(
      'powershell.exe',
      const [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      includeParentEnvironment: true,
      environment: {
        ...Platform.environment,
        'SELFX_DQR222_PORT_OVERRIDE':
            Platform.environment['SELFX_DQR222_PORT'] ?? '',
      },
    ).timeout(const Duration(seconds: 5));
    final port = result.stdout.toString().trim().toUpperCase();
    return result.exitCode == 0 && RegExp(r'^COM\d+$').hasMatch(port)
        ? port
        : null;
  } on Object {
    return null;
  }
}

/// Keep ownership of the serial queue until the child actually exits, including
/// on timeout. Future.timeout alone leaves a PowerShell writer running.
Future<ProcessResult> _runSerialProcess(
  String executable,
  List<String> arguments, {
  required Map<String, String> environment,
  required Encoding stdoutEncoding,
  required Encoding stderrEncoding,
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
  );
  final output = process.stdout.transform(stdoutEncoding.decoder).join();
  final errors = StringBuffer();
  final errorDone = process.stderr
      .transform(stderrEncoding.decoder)
      .transform(const LineSplitter())
      .forEach((line) {
        errors.writeln(line);
        debugPrint(line);
      });
  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    process.kill();
  });
  try {
    final exitCode = await process.exitCode;
    final stdout = await output;
    await errorDone;
    if (timedOut) {
      throw TimeoutException(
        'DQR-222 serial operation timed out; connection closed.',
        timeout,
      );
    }
    return ProcessResult(process.pid, exitCode, stdout, errors.toString());
  } finally {
    timer.cancel();
  }
}

Future<String> _readWindowsDqr222FileInfo(
  String port, {
  required Dqr222MediaKind kind,
}) async {
  await _windowsConnection.close();
  const script = r'''
$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new(
  $env:SELFX_DQR222_PORT,
  [int]$env:SELFX_DQR222_BAUD,
  [System.IO.Ports.Parity]::None,
  8,
  [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 250
$serial.WriteTimeout = 5000
try {
  $serial.Open()
  Start-Sleep -Milliseconds 500
  $serial.DiscardInBuffer()
  $serial.DiscardOutBuffer()
  $serial.Write($env:SELFX_DQR222_INFO_COMMAND + "`n")
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $response = [System.Text.StringBuilder]::new()
  while ($timer.ElapsedMilliseconds -lt 6000) {
    if ($serial.BytesToRead -gt 0) {
      [void]$response.Append($serial.ReadExisting())
      $value = $response.ToString()
      if ($value.Contains('"' + $env:SELFX_DQR222_FILE_KEY + '"') -and $value.Contains('"availableBytes"') -and $value.TrimEnd().EndsWith('}')) {
        break
      }
    }
    Start-Sleep -Milliseconds 40
  }
  [Console]::Out.Write($response.ToString())
} finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
''';
  final result = await _runSerialProcess(
    'powershell.exe',
    const [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ],
    environment: {
      ...Platform.environment,
      'SELFX_DQR222_PORT': port,
      'SELFX_DQR222_BAUD': '$_dqr222BaudRate',
      'SELFX_DQR222_INFO_COMMAND': kind.fileInfoCommand,
      'SELFX_DQR222_FILE_KEY': kind.fileInfoKey,
    },
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
    timeout: const Duration(seconds: 12),
  );
  if (result.exitCode != 0) {
    _lastDetectedPort = null;
    final error = result.stderr.toString().trim();
    throw StateError(error.isEmpty ? 'DQR-222 fileinfo failed.' : error);
  }
  return result.stdout.toString();
}

Future<Dqr222AdvertisementUploadResult> _uploadAndroidDqr222Advertisement(
  Uint8List bytes, {
  required String fileName,
  required int fileSize,
  required Dqr222MediaKind kind,
}) async {
  final result = await uploadAndroidDqr222Advertisement(
    fileName: fileName,
    bytes: bytes,
    chunkSize: dqr222MediaChunkSize,
    audio: kind == Dqr222MediaKind.audio,
  );
  return verifyDqr222UploadResult(
    fileName: fileName,
    expectedSize: fileSize,
    beforeFileInfo: result['beforeFileInfo']?.toString() ?? '',
    afterFileInfo: result['afterFileInfo']?.toString() ?? '',
    acknowledgedChunks: _integerValue(result['chunkCount']),
    kind: kind,
  );
}

Future<Dqr222AdvertisementUploadResult> _uploadWindowsDqr222Advertisement(
  String port,
  File source, {
  required String fileName,
  required int fileSize,
  required Dqr222MediaKind kind,
}) async {
  await _windowsConnection.close();
  const script = r'''
$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new(
  $env:SELFX_DQR222_PORT,
  [int]$env:SELFX_DQR222_BAUD,
  [System.IO.Ports.Parity]::None,
  8,
  [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 250
$serial.WriteTimeout = 5000

function Read-For([int]$milliseconds) {
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $response = [System.Text.StringBuilder]::new()
  while ($timer.ElapsedMilliseconds -lt $milliseconds) {
    if ($serial.BytesToRead -gt 0) {
      [void]$response.Append($serial.ReadExisting())
    }
    Start-Sleep -Milliseconds 35
  }
  return $response.ToString()
}

function Read-FileInfo {
  $serial.Write($env:SELFX_DQR222_INFO_COMMAND + "`n")
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $response = [System.Text.StringBuilder]::new()
  while ($timer.ElapsedMilliseconds -lt 6000) {
    if ($serial.BytesToRead -gt 0) {
      [void]$response.Append($serial.ReadExisting())
      $value = $response.ToString()
      $start = $value.IndexOf('{"' + $env:SELFX_DQR222_FILE_KEY + '"')
      if ($start -ge 0) {
        $candidate = $value.Substring($start).Trim()
        try {
          $parsed = $candidate | ConvertFrom-Json
          if ($null -ne $parsed.($env:SELFX_DQR222_FILE_KEY)) { return $parsed }
        } catch {
          # The JSON frame has not finished arriving yet.
        }
      }
    }
    Start-Sleep -Milliseconds 35
  }
  throw 'DQR-222 fileinfo response timed out.'
}

function Wait-ChunkAck([int]$chunkNumber) {
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $response = [System.Text.StringBuilder]::new()
  while ($timer.ElapsedMilliseconds -lt 5000) {
    if ($serial.BytesToRead -gt 0) {
      [void]$response.Append($serial.ReadExisting())
      if ($response.ToString() -cmatch '(?m)^ok\r?$') {
        return $response.ToString()
      }
    }
    Start-Sleep -Milliseconds 25
  }
  throw "DQR-222 did not acknowledge advertisement chunk $chunkNumber."
}

try {
  $sourcePath = [System.IO.Path]::GetFullPath($env:SELFX_DQR222_MEDIA_PATH)
  $bytes = [System.IO.File]::ReadAllBytes($sourcePath)
  $expectedSize = [int64]$env:SELFX_DQR222_MEDIA_SIZE
  if ($bytes.LongLength -ne $expectedSize) {
    throw "Selected JPEG changed before upload. Expected $expectedSize bytes, found $($bytes.LongLength)."
  }

  $serial.Open()
  Start-Sleep -Milliseconds 2000
  $serial.DiscardInBuffer()
  $serial.DiscardOutBuffer()

  $serial.Write("stoprotation`n")
  [void](Read-For 750)
  $before = Read-FileInfo
  if ([int64]$before.availableBytes -lt $expectedSize) {
    throw 'Not enough free display storage for this JPEG.'
  }
  $original = @($before.($env:SELFX_DQR222_FILE_KEY) | Where-Object { $_.filename -ceq $env:SELFX_DQR222_MEDIA_NAME } | Select-Object -First 1)
  $originalSize = if ($original.Count -gt 0) { [int64]$original[0].size } else { $null }
  [Console]::Error.WriteLine("[DQR222][MEDIA] original $($env:SELFX_DQR222_MEDIA_NAME) size=$originalSize")

  $command = $env:SELFX_DQR222_UPLOAD_COMMAND
  [Console]::Error.WriteLine("[DQR222][MEDIA] command=$command expectedBytes=$expectedSize")
  $serial.Write($command + "`n")
  [void](Read-For 500)

  $offset = 0
  $chunkNumber = 0
  while ($offset -lt $bytes.Length) {
    $count = [Math]::Min(1024, $bytes.Length - $offset)
    $serial.Write($bytes, $offset, $count)
    $chunkNumber++
    $ack = Wait-ChunkAck $chunkNumber
    [Console]::Error.WriteLine("[DQR222][MEDIA] chunk=$chunkNumber bytes=$count ACK=$($ack.Trim())")
    $offset += $count
  }

  [void](Read-For 750)
  $after = Read-FileInfo
  $stored = @($after.($env:SELFX_DQR222_FILE_KEY) | Where-Object { $_.filename -ceq $env:SELFX_DQR222_MEDIA_NAME } | Select-Object -First 1)
  if ($stored.Count -eq 0) {
    throw "DQR-222 fileinfo does not contain $($env:SELFX_DQR222_MEDIA_NAME) after upload."
  }
  $storedSize = [int64]$stored[0].size
  if ($storedSize -ne $expectedSize) {
    throw "DQR-222 stored $storedSize bytes; expected $expectedSize bytes."
  }
  [Console]::Error.WriteLine("[DQR222][MEDIA] finalSize=$storedSize overwriteVerified=true")
  $output = [ordered]@{
    beforeFileInfo = ($before | ConvertTo-Json -Depth 5 -Compress)
    afterFileInfo = ($after | ConvertTo-Json -Depth 5 -Compress)
    chunkCount = $chunkNumber
  }
  [Console]::Out.Write(($output | ConvertTo-Json -Compress))
} finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
''';
  final chunkCount =
      (fileSize + dqr222MediaChunkSize - 1) ~/ dqr222MediaChunkSize;
  final result = await _runSerialProcess(
    'powershell.exe',
    const [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ],
    environment: {
      ...Platform.environment,
      'SELFX_DQR222_PORT': port,
      'SELFX_DQR222_BAUD': '$_dqr222BaudRate',
      'SELFX_DQR222_MEDIA_PATH': source.path,
      'SELFX_DQR222_MEDIA_NAME': fileName,
      'SELFX_DQR222_MEDIA_SIZE': '$fileSize',
      'SELFX_DQR222_INFO_COMMAND': kind.fileInfoCommand,
      'SELFX_DQR222_FILE_KEY': kind.fileInfoKey,
      'SELFX_DQR222_UPLOAD_COMMAND': buildDqr222AdvertisementUploadCommand(
        fileName: fileName,
        fileSize: fileSize,
        kind: kind,
      ),
    },
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
    timeout: Duration(seconds: 30 + chunkCount * 10),
  );
  final mediaLog = result.stderr.toString().trim();
  if (mediaLog.isNotEmpty) debugPrint(mediaLog);
  if (result.exitCode != 0) {
    throw StateError(
      mediaLog.isEmpty ? 'DQR-222 advertisement upload failed.' : mediaLog,
    );
  }
  final decoded = jsonDecode(result.stdout.toString());
  if (decoded is! Map) {
    throw StateError('DQR-222 returned an invalid upload result.');
  }
  return verifyDqr222UploadResult(
    fileName: fileName,
    expectedSize: fileSize,
    beforeFileInfo: decoded['beforeFileInfo']?.toString() ?? '',
    afterFileInfo: decoded['afterFileInfo']?.toString() ?? '',
    acknowledgedChunks: _integerValue(decoded['chunkCount']),
    kind: kind,
  );
}

@visibleForTesting
Dqr222AdvertisementUploadResult verifyDqr222UploadResult({
  required String fileName,
  required int expectedSize,
  required String beforeFileInfo,
  required String afterFileInfo,
  required int acknowledgedChunks,
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) {
  final expectedChunks =
      (expectedSize + dqr222MediaChunkSize - 1) ~/ dqr222MediaChunkSize;
  if (acknowledgedChunks != expectedChunks) {
    throw StateError(
      'DQR-222 acknowledged $acknowledgedChunks of $expectedChunks chunks.',
    );
  }
  int? originalSize;
  for (final image in parseDqr222AdvertisementFileInfo(
    beforeFileInfo,
    kind: kind,
  )) {
    if (image.fileName == fileName) {
      originalSize = image.size;
      break;
    }
  }
  int? storedSize;
  for (final image in parseDqr222AdvertisementFileInfo(
    afterFileInfo,
    kind: kind,
  )) {
    if (image.fileName == fileName) {
      storedSize = image.size;
      break;
    }
  }
  if (storedSize == null) {
    throw StateError(
      'DQR-222 fileinfo does not contain $fileName after upload.',
    );
  }
  if (storedSize != expectedSize) {
    throw StateError(
      'DQR-222 stored $storedSize bytes for $fileName; expected $expectedSize.',
    );
  }
  developer.log(
    'Advertisement verified file=$fileName originalSize=$originalSize '
    'storedSize=$storedSize chunks=$acknowledgedChunks',
    name: 'SELFX.DQR222.MEDIA',
  );
  return Dqr222AdvertisementUploadResult(
    fileName: fileName,
    originalSize: originalSize,
    storedSize: storedSize,
    chunkCount: acknowledgedChunks,
  );
}

int _integerValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Future<T> _queueDqr222Operation<T>(Future<T> Function() operation) {
  final result = (_dqr222WriteQueue ?? Future<void>.value()).then(
    (_) => operation(),
  );
  _dqr222WriteQueue = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return result;
}

Future<void> _queueCommandWrite(
  String port,
  List<String> commands, {
  int? generation,
}) {
  final queuedAt = Stopwatch()..start();
  final operation = (_dqr222WriteQueue ?? Future<void>.value()).then((_) async {
    if (generation != null && generation != _displayGeneration) return;
    if (_paymentScreenActive &&
        commands.any(
          (command) =>
              command.startsWith('billjson**') ||
              command.startsWith('__cartjpeg**'),
        )) {
      return;
    }
    if (_mediaRestoreSuppressed && commands.contains('startrotation')) return;
    debugPrint('[DQR222][TIMING] queueWaitMs=${queuedAt.elapsedMilliseconds}');
    await _writeCommands(port, commands);
  });
  _dqr222WriteQueue = operation.catchError((Object _) {});
  return operation;
}

List<String> _withoutCustomerDisplayAudio(List<String> commands) {
  if (CustomerVoiceService.instance.isEnabled) return commands;
  return [
    for (final command in commands)
      if (command != 'audioon' &&
          !command.startsWith('setvolume**') &&
          !command.startsWith('play**'))
        command,
  ];
}

Future<void> _writeCommands(String port, List<String> commands) async {
  commands = _withoutCustomerDisplayAudio(commands);
  if (commands.isEmpty) return;
  if (dqr222TestTransport != null) {
    await dqr222TestTransport!.writeCommands(commands);
    return;
  }
  if (commands.any(
    (command) => command.contains('\n') || command.contains('\r'),
  )) {
    throw ArgumentError.value(
      commands,
      'commands',
      'Commands must be single-line.',
    );
  }
  if (Platform.isAndroid) {
    final response = await writeAndroidDqr222Commands(commands);
    _validateDqr222Response(
      port,
      commands,
      response,
      requirePaymentAcknowledgement: false,
    );
    return;
  }
  if (!RegExp(r'^COM\d+$').hasMatch(port)) {
    throw ArgumentError.value(port, 'port', 'Invalid COM port');
  }

  const script = r'''
$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new(
  $env:SELFX_DQR222_PORT,
  [int]$env:SELFX_DQR222_BAUD,
  [System.IO.Ports.Parity]::None,
  8,
  [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 250
$serial.WriteTimeout = 5000
try {
  $maxOpenRetries = 5
  $serial.Encoding = [System.Text.Encoding]::UTF8
  $openRetry = 0
  while ($true) {
    try {
      $serial.Open()
      break
    } catch [System.UnauthorizedAccessException] {
      # Another process (e.g. a previous worker that survived a hot-restart)
      # still holds the port. Wait for it to release and try again.
      if ($openRetry -ge $maxOpenRetries) { throw }
      $openRetry++
      Start-Sleep -Milliseconds 800
    } catch [System.IO.IOException] {
      # Port briefly disappeared (USB reconnect race). Give it a moment.
      if ($openRetry -ge $maxOpenRetries) { throw }
      $openRetry++
      Start-Sleep -Milliseconds 800
    }
  }
  # Only a newly opened connection needs boot settling; warm edits skip this.
  Start-Sleep -Milliseconds 1500
  $serial.DiscardInBuffer()
  $serial.DiscardOutBuffer()
  # Keep serial ownership between updates so cart edits do not reset the unit.
  while ($null -ne ($line = Read-SelfxRequest)) {
  $request = $line | ConvertFrom-Json
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  $qrWriteMs = $null
  $cartImageSent = $false
  $firmwareWait = $false
  try {
  $serial.DiscardInBuffer()
  # Explicit array cast is required for Windows PowerShell 5.1.
  $commands = [object[]]$request.commands
  foreach ($command in $commands) {
    if ([string]$command -like '__cartjpeg**') {
      $bytes = [Convert]::FromBase64String(([string]$command).Substring(12))
      $serial.Write("startsendingfile cart.jpeg $($bytes.Length)`n")
      Start-Sleep -Milliseconds 200
      for ($offset = 0; $offset -lt $bytes.Length; $offset += 1024) {
        $count = [Math]::Min(1024, $bytes.Length - $offset)
        $serial.Write($bytes, $offset, $count)
        Start-Sleep -Milliseconds 20
      }
      $serial.BaseStream.Flush()
      # Write() can return while bytes remain in the driver. Drain the UART
      # before the short JPEG decode interval; cart images have no audio wait.
      $drainTimer = [System.Diagnostics.Stopwatch]::StartNew()
      while ($serial.BytesToWrite -gt 0) {
        if ($drainTimer.ElapsedMilliseconds -gt 5000) { throw 'Cart image serial drain timed out.' }
        Start-Sleep -Milliseconds 10
      }
      Start-Sleep -Milliseconds 300
      $cartImageSent = $true
      continue
    }
    $serial.Write(([string]$command) + "`n")
    if ([string]$command -match '^DisplayQRCodeScreen\*\*') {
      $qrWriteMs = $timer.ElapsedMilliseconds
    }
    if ([string]$command -eq 'play**welcome.mp3') {
      Start-Sleep -Milliseconds 1800
    } elseif ([string]$command -match '^WelcomeScreen\*\*') {
      # This unit accepts stoprotation 1.5 seconds after WelcomeScreen. Give it
      # a little margin without holding a payment request behind a long idle
      # screen write.
      Start-Sleep -Milliseconds 1500
      $firmwareWait = $true
    } elseif ([string]$command -match '^Display.*Screen\*\*') {
      # Screen rendering/audio is synchronous on firmware 1.0. Commands sent
      # during this window are silently dropped, including stoprotation.
      # 1200 ms is enough for the device to render the QR and play the beep;
      # the previous 3000 ms caused the visible ~3-second delay on screen.
      Start-Sleep -Milliseconds 1200
      $firmwareWait = $true
    } elseif ([string]$command -match '^(delete|billjson)\*\*') {
      Start-Sleep -Milliseconds 1200
      $firmwareWait = $true
    } else {
      Start-Sleep -Milliseconds 200
    }
  }
  $serial.BaseStream.Flush()
  # A screen or bill command already waited for the firmware to finish
  # drawing. The 500 ms tail is only for short commands that still need an
  # acknowledgement before the next update.
  if (-not $cartImageSent -and -not $firmwareWait) { Start-Sleep -Milliseconds 500 }
  $response = ''
  if ($serial.BytesToRead -gt 0) { $response = $serial.ReadExisting() }
  [Console]::Out.WriteLine((@{id=$request.id; response=$response; qrWriteMs=$qrWriteMs; elapsedMs=$timer.ElapsedMilliseconds} | ConvertTo-Json -Compress))
  [Console]::Out.Flush()
  } catch {
    [Console]::Out.WriteLine((@{id=$request.id; error=$_.Exception.Message} | ConvertTo-Json -Compress))
    [Console]::Out.Flush()
    break
  }
  }
} finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
''';

  late String response;
  try {
    response = await _windowsConnection.writeCommands(
      port,
      commands,
      script: script,
      baudRate: _dqr222BaudRate,
    );
  } on Object {
    _readyScreenKey = null;
    _lastDetectedPort = null;
    await _windowsConnection.close();
    rethrow;
  }
  // A firmware-level rejection does not mean the serial connection is broken.
  // Keep it open so the fallback can run without resetting the display.
  _validateDqr222Response(port, commands, response);
}

@visibleForTesting
void validateDqr222ResponseForTest(List<String> commands, String response) =>
    _validateDqr222Response('COM14', commands, response);

void _validateDqr222Response(
  String port,
  List<String> commands,
  String response, {
  bool requirePaymentAcknowledgement = true,
}) {
  debugPrint(
    '[DQR222][SERIAL] port=$port commands=${commands.length} '
    'response=${response.isEmpty ? '<empty>' : response}',
  );
  final paymentQrRequested = commands.any(
    (command) => command.startsWith('DisplayQRCodeScreen**'),
  );
  if (commands.any((command) => command.startsWith('billjson**'))) {
    final billResponse = response.split(RegExp(r'[\r\n]+')).where((line) {
      final text = line.trim();
      return text.isNotEmpty &&
          !text.startsWith('ESP32 Chip') &&
          text != 'Rotation mode stopped.';
    }).join('\n');
    if (billResponse.isEmpty) {
      throw StateError(
        'DQR-222 did not acknowledge the bill on $port; '
        'received only startup/rotation output or no response.',
      );
    }
  }
  if (RegExp(
    r'\b(error|invalid|failed)\b',
    caseSensitive: false,
  ).hasMatch(response)) {
    throw StateError('DQR-222 rejected a display command: $response');
  }
  if (requirePaymentAcknowledgement &&
      paymentQrRequested &&
      !RegExp(
        r'QR\s*Code\s*Generation|displayqr\.mp3',
        caseSensitive: false,
      ).hasMatch(response)) {
    throw StateError(
      'DQR-222 did not acknowledge QR generation on $port.'
      '${response.isEmpty ? '' : ' Response: $response'}',
    );
  }
  developer.log(
    'DQR-222 acknowledged ${commands.length} command(s) on $port.',
    name: 'SELFX.DQR222',
  );
}
