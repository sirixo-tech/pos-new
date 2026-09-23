import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:qr/qr.dart';

import '../../config/pos_app_info.dart';
import 'android_usb_customer_display_transport.dart';

const _dq11Width = 320;
const _dq11Height = 480;
const _dq11FrameBytes = _dq11Width * _dq11Height * 2;
const _dq11BaudRate = 921600;
const _countdownRefresh = Duration(seconds: 1);
const _expiredGrace = Duration(seconds: 30);

Future<void> _dq11WriteQueue = Future<void>.value();
Future<image.Image?>? _companyLogoFuture;
final Map<String, Future<image.Image?>> _restaurantLogoCache = {};
String? _lastRestaurantName;
String? _lastRestaurantLogoUrl;
Timer? _expiryTimer;
Timer? _countdownTimer;
bool _countdownWriteInProgress = false;
bool _paymentScreenActive = false;
bool _homeWriteInProgress = false;
String? _readyScreenKey;
int _displayGeneration = 0;

typedef Dq11DisplayStatus = ({bool connected, String? port, String message});

bool get _dq11PlatformSupported => Platform.isWindows || Platform.isAndroid;

/// Renders the shared 320 x 480 customer-display artwork as JPEG.
///
/// DQ11 transports RGB565 while DQR-222 transports JPEG. Keeping the artwork
/// here gives both devices the same payment lifecycle without making either
/// serial protocol depend on the other.
Future<Uint8List> renderCustomerDisplayPaymentJpeg({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? restaurantName,
  String? restaurantLogoUrl,
  DateTime? expiresAt,
}) async => _rgb565FrameToJpeg(
  await _buildPaymentFrame(
    qr: qr,
    orderNumber: orderNumber,
    amount: amount,
    payeeName: payeeName,
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
    expiresAt: expiresAt,
  ),
);

Future<Uint8List> renderCustomerDisplayReadyJpeg({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async => _rgb565FrameToJpeg(
  await _buildReadyFrame(
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
  ),
);

Future<Uint8List> renderCustomerDisplayExpiredJpeg({
  String? restaurantName,
  String? restaurantLogoUrl,
  int graceSeconds = 0,
}) async => _rgb565FrameToJpeg(
  await _buildExpiredFrame(
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
    graceSeconds: graceSeconds,
  ),
);

Future<Uint8List> renderCustomerDisplayCancelledJpeg({
  String? orderNumber,
  String? restaurantName,
}) async => _rgb565FrameToJpeg(
  await _buildCancelledFrame(
    orderNumber: orderNumber,
    restaurantName: restaurantName,
  ),
);

Future<Uint8List> renderCustomerDisplaySuccessJpeg({
  required double amount,
  required DateTime paidAt,
  String? orderNumber,
  String? transactionId,
  String? restaurantName,
}) async => _rgb565FrameToJpeg(
  await _buildSuccessFrame(
    amount: amount,
    paidAt: paidAt,
    orderNumber: orderNumber,
    transactionId: transactionId,
    restaurantName: restaurantName,
  ),
);

Future<Dq11DisplayStatus> getDq11DisplayStatus() async {
  if (!_dq11PlatformSupported) {
    return (
      connected: false,
      port: null,
      message: 'DQ11 QR display is not supported on this platform.',
    );
  }
  final port = await _findDq11Port();
  if (port == null) {
    _readyScreenKey = null;
    return (
      connected: false,
      port: null,
      message: 'DQ11 QR display is disconnected. Connect its USB cable.',
    );
  }
  return (
    connected: true,
    port: port,
    message: 'DQ11 QR display connected on $port.',
  );
}

Future<void> showDq11HomeIfIdle({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dq11PlatformSupported || _paymentScreenActive || _homeWriteInProgress) {
    return;
  }
  if (restaurantName?.trim().isNotEmpty == true) {
    _lastRestaurantName = restaurantName;
  }
  if (restaurantLogoUrl?.trim().isNotEmpty == true) {
    _lastRestaurantLogoUrl = restaurantLogoUrl;
  }
  final generation = _displayGeneration;
  final port = await _findDq11Port();
  if (port == null ||
      _paymentScreenActive ||
      generation != _displayGeneration) {
    return;
  }
  final readyKey = [
    port,
    _lastRestaurantName?.trim() ?? '',
    _lastRestaurantLogoUrl?.trim() ?? '',
  ].join('|');
  if (_readyScreenKey == readyKey) return;
  _homeWriteInProgress = true;
  try {
    final frame = await _buildReadyFrame(
      restaurantName: _lastRestaurantName,
      restaurantLogoUrl: _lastRestaurantLogoUrl,
    );
    if (_paymentScreenActive || generation != _displayGeneration) return;
    await _queueFrameWrite(port, frame, generation: generation);
    if (_paymentScreenActive || generation != _displayGeneration) return;
    _readyScreenKey = readyKey;
    developer.log('Home screen displayed on $port', name: 'SELFX.DQ11');
  } on Object catch (error) {
    _readyScreenKey = null;
    developer.log('Home screen failed on $port: $error', name: 'SELFX.DQ11');
  } finally {
    _homeWriteInProgress = false;
  }
}

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
  if (!_dq11PlatformSupported) return false;

  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _expiryTimer?.cancel();
  _expiryTimer = null;
  _countdownTimer?.cancel();
  _countdownTimer = null;

  final port = await _findDq11Port();
  if (port == null) {
    _paymentScreenActive = false;
    _readyScreenKey = null;
    developer.log('USB display not detected', name: 'SELFX.DQ11');
    return false;
  }

  // Do not report DQ11 mode until the first QR frame is physically written.
  // Port discovery only proves that Windows can see the USB device; it does
  // not prove that the serial port can be opened or that the display received
  // the frame. Returning early here caused checkout to hide the POS QR even
  // when the DQ11 write subsequently failed in the background.
  return _displayDq11PaymentQr(
    port: port,
    generation: generation,
    qr: qr,
    orderNumber: orderNumber,
    amount: amount,
    payeeName: payeeName,
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
    timeoutSeconds: timeoutSeconds,
  );
}

Future<bool> _displayDq11PaymentQr({
  required String port,
  required int generation,
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? restaurantName,
  String? restaurantLogoUrl,
  int? timeoutSeconds,
}) async {
  try {
    _lastRestaurantName = restaurantName;
    _lastRestaurantLogoUrl = restaurantLogoUrl;
    final validTimeout = timeoutSeconds != null && timeoutSeconds > 0
        ? timeoutSeconds
        : null;
    final expiresAt = validTimeout == null
        ? null
        : DateTime.now().add(Duration(seconds: validTimeout));
    final frame = await _buildPaymentFrame(
      qr: qr,
      orderNumber: orderNumber,
      amount: amount,
      payeeName: payeeName,
      restaurantName: restaurantName,
      restaurantLogoUrl: restaurantLogoUrl,
      expiresAt: expiresAt,
    );
    if (generation != _displayGeneration || !_paymentScreenActive) {
      return false;
    }
    await _queueFrameWrite(port, frame, generation: generation);
    if (generation != _displayGeneration || !_paymentScreenActive) {
      return false;
    }
    if (expiresAt != null) {
      _countdownTimer = Timer.periodic(_countdownRefresh, (_) {
        unawaited(
          _refreshPaymentCountdown(
            port,
            generation: generation,
            expiresAt: expiresAt,
            qr: qr,
            orderNumber: orderNumber,
            amount: amount,
            payeeName: payeeName,
            restaurantName: restaurantName,
            restaurantLogoUrl: restaurantLogoUrl,
          ),
        );
      });
      final timeUntilExpiry = expiresAt.difference(DateTime.now());
      _expiryTimer = Timer(
        timeUntilExpiry.isNegative ? Duration.zero : timeUntilExpiry,
        () {
          if (generation != _displayGeneration) return;
          _countdownTimer?.cancel();
          _countdownTimer = null;
          unawaited(
            _showExpiredGrace(
              port,
              generation: generation,
              restaurantName: restaurantName,
              restaurantLogoUrl: restaurantLogoUrl,
            ),
          );
        },
      );
    }
    developer.log('Payment QR displayed on $port', name: 'SELFX.DQ11');
    return true;
  } on Object catch (error) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    developer.log('Display failed on $port: $error', name: 'SELFX.DQ11');
    return false;
  }
}

Future<void> clearDq11CustomerDisplay() async {
  if (!_dq11PlatformSupported) return;
  final generation = ++_displayGeneration;
  _paymentScreenActive = false;
  _expiryTimer?.cancel();
  _expiryTimer = null;
  _countdownTimer?.cancel();
  _countdownTimer = null;
  final port = await _findDq11Port();
  if (port == null) return;

  try {
    await _queueFrameWrite(
      port,
      await _buildReadyFrame(
        restaurantName: _lastRestaurantName,
        restaurantLogoUrl: _lastRestaurantLogoUrl,
      ),
      generation: generation,
    );
    if (generation != _displayGeneration) return;
    _readyScreenKey = [
      port,
      _lastRestaurantName?.trim() ?? '',
      _lastRestaurantLogoUrl?.trim() ?? '',
    ].join('|');
    developer.log('Ready screen displayed on $port', name: 'SELFX.DQ11');
  } on Object catch (error) {
    _readyScreenKey = null;
    // A detached optional display must never interrupt order completion.
    developer.log('Clear failed on $port: $error', name: 'SELFX.DQ11');
  }
}

Future<void> showDq11PaymentCancelled({
  String? orderNumber,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dq11PlatformSupported) return;
  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _expiryTimer?.cancel();
  _expiryTimer = null;
  _countdownTimer?.cancel();
  _countdownTimer = null;

  if (restaurantName?.trim().isNotEmpty == true) {
    _lastRestaurantName = restaurantName;
  }
  if (restaurantLogoUrl?.trim().isNotEmpty == true) {
    _lastRestaurantLogoUrl = restaurantLogoUrl;
  }
  final port = await _findDq11Port();
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return;
  }

  try {
    await _queueFrameWrite(
      port,
      await _buildCancelledFrame(
        orderNumber: orderNumber,
        restaurantName: _lastRestaurantName,
      ),
      generation: generation,
    );
    if (generation != _displayGeneration) return;
    // Delivery of the cancelled screen is authoritative. Returning to the
    // ready screen is background work so cancellation does not freeze the POS
    // for another full serial-frame transfer.
    unawaited(_returnHomeAfterCancelled(port, generation));
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      _paymentScreenActive = false;
      _readyScreenKey = null;
    }
    developer.log(
      'Cancelled screen failed on $port: $error',
      name: 'SELFX.DQ11',
    );
  }
}

Future<void> _returnHomeAfterCancelled(String port, int generation) async {
  await Future<void>.delayed(const Duration(seconds: 3));
  if (generation != _displayGeneration) return;
  try {
    final frame = await _buildReadyFrame(
      restaurantName: _lastRestaurantName,
      restaurantLogoUrl: _lastRestaurantLogoUrl,
    );
    if (generation != _displayGeneration) return;
    await _queueFrameWrite(port, frame, generation: generation);
    if (generation != _displayGeneration) return;
    _paymentScreenActive = false;
    _readyScreenKey = [
      port,
      _lastRestaurantName?.trim() ?? '',
      _lastRestaurantLogoUrl?.trim() ?? '',
    ].join('|');
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      _paymentScreenActive = false;
      _readyScreenKey = null;
    }
    developer.log(
      'Ready screen after cancellation failed on $port: $error',
      name: 'SELFX.DQ11',
    );
  }
}

Future<void> showDq11PaymentSuccess({
  required double amount,
  String? orderNumber,
  String? transactionId,
  DateTime? paidAt,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (!_dq11PlatformSupported) return;
  final generation = ++_displayGeneration;
  _paymentScreenActive = true;
  _readyScreenKey = null;
  _expiryTimer?.cancel();
  _expiryTimer = null;
  _countdownTimer?.cancel();
  _countdownTimer = null;

  if (restaurantName?.trim().isNotEmpty == true) {
    _lastRestaurantName = restaurantName;
  }
  if (restaurantLogoUrl?.trim().isNotEmpty == true) {
    _lastRestaurantLogoUrl = restaurantLogoUrl;
  }
  final port = await _findDq11Port();
  if (port == null || generation != _displayGeneration) {
    if (generation == _displayGeneration) _paymentScreenActive = false;
    return;
  }

  try {
    await _queueFrameWrite(
      port,
      await _buildSuccessFrame(
        amount: amount,
        orderNumber: orderNumber,
        transactionId: transactionId,
        paidAt: paidAt ?? DateTime.now(),
        restaurantName: _lastRestaurantName,
      ),
      generation: generation,
    );
    if (generation != _displayGeneration) return;
    unawaited(_announceDq11Payment(amount));
    await Future<void>.delayed(const Duration(seconds: 4));
    if (generation != _displayGeneration) return;
    _paymentScreenActive = false;
    await _queueFrameWrite(
      port,
      await _buildReadyFrame(
        restaurantName: _lastRestaurantName,
        restaurantLogoUrl: _lastRestaurantLogoUrl,
      ),
      generation: generation,
    );
    if (generation != _displayGeneration) return;
    _readyScreenKey = [
      port,
      _lastRestaurantName?.trim() ?? '',
      _lastRestaurantLogoUrl?.trim() ?? '',
    ].join('|');
  } on Object catch (error) {
    if (generation == _displayGeneration) {
      _paymentScreenActive = false;
      _readyScreenKey = null;
    }
    developer.log(
      'Payment success screen failed on $port: $error',
      name: 'SELFX.DQ11',
    );
  }
}

Future<void> _announceDq11Payment(double amount) async {
  if (!Platform.isWindows) return;
  final safeAmount = amount.isFinite && amount >= 0 ? amount : 0;
  const script = r'''
Add-Type -AssemblyName System.Speech
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$amount = [decimal]::Parse(
  $env:SELFX_PAID_AMOUNT,
  [Globalization.CultureInfo]::InvariantCulture
)
$rupees = [math]::Floor($amount)
$paise = [math]::Round(($amount - $rupees) * 100)
$message = "Thank you, Boss! You paid $rupees rupees"
if ($paise -gt 0) { $message += " and $paise paise" }
$message += ". Enjoy your meal!"
$voice.Speak($message)
$voice.Dispose()
''';
  try {
    await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      environment: {'SELFX_PAID_AMOUNT': safeAmount.toStringAsFixed(2)},
    ).timeout(const Duration(seconds: 12));
  } on Object catch (error) {
    // Speech is an enhancement; display and payment completion must continue.
    developer.log('Payment announcement failed: $error', name: 'SELFX.DQ11');
  }
}

Future<void> _refreshPaymentCountdown(
  String port, {
  required int generation,
  required DateTime expiresAt,
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  if (generation != _displayGeneration ||
      _countdownWriteInProgress ||
      !DateTime.now().isBefore(expiresAt)) {
    return;
  }
  _countdownWriteInProgress = true;
  try {
    final frame = await _buildPaymentFrame(
      qr: qr,
      orderNumber: orderNumber,
      amount: amount,
      payeeName: payeeName,
      restaurantName: restaurantName,
      restaurantLogoUrl: restaurantLogoUrl,
      expiresAt: expiresAt,
    );
    if (generation != _displayGeneration ||
        !DateTime.now().isBefore(expiresAt)) {
      return;
    }
    await _queueFrameWrite(port, frame, generation: generation);
  } on Object catch (error) {
    developer.log(
      'Countdown refresh failed on $port: $error',
      name: 'SELFX.DQ11',
    );
  } finally {
    _countdownWriteInProgress = false;
  }
}

Future<void> _showExpiredGrace(
  String port, {
  required int generation,
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  final graceEndsAt = DateTime.now().add(_expiredGrace);
  try {
    while (generation == _displayGeneration) {
      final remaining = _remainingSeconds(graceEndsAt);
      if (remaining <= 0) break;
      final frame = await _buildExpiredFrame(
        restaurantName: restaurantName,
        restaurantLogoUrl: restaurantLogoUrl,
        graceSeconds: remaining,
      );
      if (generation != _displayGeneration) return;
      await _queueFrameWrite(port, frame, generation: generation);

      final nextUpdateAt = graceEndsAt.subtract(
        Duration(seconds: remaining - 1),
      );
      final delay = nextUpdateAt.difference(DateTime.now());
      if (delay.inMilliseconds > 0) await Future<void>.delayed(delay);
    }
    if (generation != _displayGeneration) return;
    _paymentScreenActive = false;
    await _queueFrameWrite(
      port,
      await _buildReadyFrame(
        restaurantName: restaurantName,
        restaurantLogoUrl: restaurantLogoUrl,
      ),
      generation: generation,
    );
    _readyScreenKey = [
      port,
      restaurantName?.trim() ?? '',
      restaurantLogoUrl?.trim() ?? '',
    ].join('|');
    developer.log('Returned to ready screen on $port', name: 'SELFX.DQ11');
  } on Object catch (error) {
    _readyScreenKey = null;
    developer.log('Expiry grace failed on $port: $error', name: 'SELFX.DQ11');
  }
}

Future<String?> _findDq11Port() async {
  if (Platform.isAndroid) {
    return findAndroidUsbCustomerDisplay('dq11');
  }
  // Win32_SerialPort/Get-PnpDevice can return no device for this DQ11 even
  // while Windows reports the USB device as Started. Resolve its current COM
  // port from the VID/PID registry entry, then ask pnputil whether that exact
  // instance is physically connected. No COM number is assumed or saved.
  const script = r'''
$connectedPorts = [System.IO.Ports.SerialPort]::GetPortNames()
$usbRoots = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB' `
  -ErrorAction SilentlyContinue |
  Where-Object { $_.PSChildName -like 'VID_0483&PID_5740*' }

foreach ($usbRoot in $usbRoots) {
  foreach ($instance in (Get-ChildItem $usbRoot.PSPath -ErrorAction SilentlyContinue)) {
    $parameters = Get-ItemProperty `
      ($instance.PSPath + '\Device Parameters') `
      -ErrorAction SilentlyContinue
    $port = $parameters.PortName
    if ($port -and
        $connectedPorts -contains $port) {
      $instanceId = 'USB\' + $usbRoot.PSChildName + '\' + $instance.PSChildName
      $deviceState = (& pnputil.exe /enum-devices /connected /instanceid $instanceId 2>$null) -join "`n"
      if ($deviceState -match [regex]::Escape($instanceId) -and
          $deviceState -match '(?im)^Status\s*:\s*Started\s*$') {
        [Console]::Out.Write($port)
        exit 0
      }
    }
  }
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
    ).timeout(const Duration(seconds: 5));
    final port = result.stdout.toString().trim().toUpperCase();
    return result.exitCode == 0 && RegExp(r'^COM\d+$').hasMatch(port)
        ? port
        : null;
  } on Object {
    return null;
  }
}

Future<void> _queueFrameWrite(String port, Uint8List frame, {int? generation}) {
  final operation = _dq11WriteQueue.then((_) async {
    // A screen can become obsolete while it waits behind a 300 KB serial
    // transfer. Never send a frame belonging to a cancelled/older payment.
    if (generation != null && generation != _displayGeneration) return;
    await _writeFrame(port, frame);
  });
  _dq11WriteQueue = operation.catchError((Object _) {});
  return operation;
}

Future<void> _writeFrame(String port, Uint8List frame) async {
  if (frame.length != _dq11FrameBytes) {
    throw StateError(
      'Invalid DQ11 frame size ${frame.length}; expected $_dq11FrameBytes.',
    );
  }
  if (Platform.isAndroid) {
    await writeAndroidDq11Frame(frame);
    return;
  }
  if (!RegExp(r'^COM\d+$').hasMatch(port)) {
    throw ArgumentError.value(port, 'port', 'Invalid COM port');
  }

  const writerScript = r'''
$ErrorActionPreference = 'Stop'
$portName = $env:SELFX_DQ11_PORT
$baud = [int]$env:SELFX_DQ11_BAUD
$serial = [System.IO.Ports.SerialPort]::new(
  $portName,
  $baud,
  [System.IO.Ports.Parity]::None,
  8,
  [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.WriteTimeout = 15000
try {
  $serial.Open()
  $length = [int]$env:SELFX_DQ11_LENGTH
  $inputStream = [Console]::OpenStandardInput()
  $buffer = New-Object byte[] 16384
  $sent = 0
  while ($sent -lt $length) {
    $remaining = $length - $sent
    $read = $inputStream.Read(
      $buffer,
      0,
      [Math]::Min($buffer.Length, $remaining)
    )
    if ($read -le 0) { break }
    $serial.Write($buffer, 0, $read)
    $sent += $read
  }
  if ($sent -ne $length) {
    throw "Frame length mismatch. Expected $length bytes, sent $sent."
  }
  $serial.BaseStream.Flush()
} finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
''';

  final process = await Process.start(
    'powershell.exe',
    const [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      writerScript,
    ],
    environment: {
      ...Platform.environment,
      'SELFX_DQ11_PORT': port,
      'SELFX_DQ11_BAUD': '$_dq11BaudRate',
      'SELFX_DQ11_LENGTH': '${frame.length}',
    },
  );

  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  final stdoutDrain = process.stdout.drain<void>();
  late final int exitCode;
  try {
    process.stdin.add(frame);
    await process.stdin.close();
    exitCode = await process.exitCode.timeout(const Duration(seconds: 20));
  } on Object {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on Object {
      // The child was already force-terminated or Windows is still reaping it.
    }
    rethrow;
  }
  final stderr = (await stderrFuture).trim();
  await stdoutDrain;
  if (exitCode != 0) {
    throw StateError(
      stderr.isEmpty ? 'DQ11 serial writer exited with $exitCode.' : stderr,
    );
  }
}

Future<Uint8List> _buildPaymentFrame({
  required String qr,
  String? orderNumber,
  double? amount,
  String? payeeName,
  String? restaurantName,
  String? restaurantLogoUrl,
  DateTime? expiresAt,
}) async {
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  image.fill(canvas, color: image.ColorRgb8(255, 252, 250));
  final companyLogo = await _loadCompanyLogo();
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 136, y: 4, size: 48);
  } else {
    image.drawString(
      canvas,
      'SELFX',
      font: image.arial24,
      y: 15,
      color: image.ColorRgb8(255, 91, 24),
    );
  }
  final restaurant = _displayText(restaurantName, maximum: 24);
  image.drawString(
    canvas,
    restaurant.isEmpty ? 'Restaurant' : restaurant,
    font: restaurant.length > 18 ? image.arial14 : image.arial24,
    y: 54,
    color: image.ColorRgb8(24, 34, 50),
  );
  _drawAccentDivider(canvas, y: 78);
  image.drawString(
    canvas,
    'SCAN TO PAY',
    font: image.arial24,
    y: 85,
    color: image.ColorRgb8(255, 82, 12),
  );

  _drawAccentDivider(canvas, y: 111);
  final qrBottom = _drawQr(canvas, qr, top: 120, maxSize: 238, decorated: true);
  final amountY = qrBottom + 6;
  final orderY = amountY + 31;
  final countdownY = orderY + 22;

  final amountText = amount == null ? '' : 'INR ${amount.toStringAsFixed(2)}';
  if (amountText.isNotEmpty) {
    image.drawString(
      canvas,
      amountText,
      font: image.arial24,
      y: amountY,
      color: image.ColorRgb8(255, 82, 12),
    );
  }
  final safeOrder = _displayText(orderNumber, maximum: 34);
  if (safeOrder.isNotEmpty) {
    image.drawString(
      canvas,
      'ORDER  $safeOrder',
      font: image.arial14,
      y: orderY,
      color: image.ColorRgb8(24, 34, 50),
    );
  }
  if (expiresAt != null) {
    image.drawString(
      canvas,
      'EXPIRES IN ${_durationText(_remainingSeconds(expiresAt))}',
      font: image.arial14,
      y: countdownY,
      color: image.ColorRgb8(255, 82, 12),
    );
  }
  _drawAccentDivider(canvas, y: 425);
  _drawAccentFooter(canvas, top: 434);
  image.drawString(
    canvas,
    'SELFX POS',
    font: image.arial14,
    y: 455,
    color: image.ColorRgb8(255, 255, 255),
  );
  return _toRgb565(canvas);
}

Future<Uint8List> _buildExpiredFrame({
  String? restaurantName,
  String? restaurantLogoUrl,
  required int graceSeconds,
}) async {
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  image.fill(canvas, color: image.ColorRgb8(248, 250, 252));
  image.fillRect(
    canvas,
    x1: 0,
    y1: 0,
    x2: _dq11Width - 1,
    y2: 78,
    color: image.ColorRgb8(15, 23, 42),
  );
  await _drawBrandHeader(
    canvas,
    restaurantName: restaurantName,
    restaurantLogoUrl: restaurantLogoUrl,
  );
  image.drawString(
    canvas,
    'QR EXPIRED',
    font: image.arial24,
    y: 112,
    color: image.ColorRgb8(220, 38, 38),
  );
  final companyLogo = await _loadCompanyLogo();
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 100, y: 166, size: 120);
  }
  image.drawString(
    canvas,
    'Need a fresh payment QR?',
    font: image.arial14,
    y: 316,
    color: image.ColorRgb8(24, 34, 50),
  );
  image.drawString(
    canvas,
    'Please ask the cashier',
    font: image.arial14,
    y: 347,
    color: image.ColorRgb8(71, 85, 105),
  );
  image.drawString(
    canvas,
    'HOME IN ${_durationText(graceSeconds)}',
    font: image.arial24,
    y: 375,
    color: image.ColorRgb8(220, 38, 38),
  );
  image.drawString(
    canvas,
    'Fast  |  Simple  |  Secure',
    font: image.arial14,
    y: 418,
    color: image.ColorRgb8(255, 91, 24),
  );
  image.drawString(
    canvas,
    'Powered by SELFX POS',
    font: image.arial14,
    y: 452,
    color: image.ColorRgb8(71, 85, 105),
  );
  return _toRgb565(canvas);
}

Future<Uint8List> _buildCancelledFrame({
  String? orderNumber,
  String? restaurantName,
}) async {
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  image.fill(canvas, color: image.ColorRgb8(255, 252, 250));
  final companyLogo = await _loadCompanyLogo();
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 132, y: 18, size: 56);
  }
  final restaurant = _displayText(restaurantName, maximum: 24);
  image.drawString(
    canvas,
    restaurant.isEmpty ? 'Restaurant' : restaurant,
    font: restaurant.length > 18 ? image.arial14 : image.arial24,
    y: 88,
    color: image.ColorRgb8(24, 34, 50),
  );
  _drawAccentDivider(canvas, y: 122);
  image.drawCircle(
    canvas,
    x: 160,
    y: 202,
    radius: 48,
    color: image.ColorRgb8(220, 38, 38),
    antialias: true,
  );
  image.drawLine(
    canvas,
    x1: 132,
    y1: 174,
    x2: 188,
    y2: 230,
    color: image.ColorRgb8(220, 38, 38),
    thickness: 7,
  );
  image.drawLine(
    canvas,
    x1: 188,
    y1: 174,
    x2: 132,
    y2: 230,
    color: image.ColorRgb8(220, 38, 38),
    thickness: 7,
  );
  image.drawString(
    canvas,
    'PAYMENT CANCELLED',
    font: image.arial24,
    y: 273,
    color: image.ColorRgb8(220, 38, 38),
  );
  final order = _displayText(orderNumber, maximum: 30);
  if (order.isNotEmpty) {
    image.drawString(
      canvas,
      'ORDER  $order',
      font: image.arial14,
      y: 316,
      color: image.ColorRgb8(24, 34, 50),
    );
  }
  image.drawString(
    canvas,
    'Returning to ready screen...',
    font: image.arial14,
    y: 357,
    color: image.ColorRgb8(71, 85, 105),
  );
  _drawAccentFooter(canvas, top: 407);
  image.drawString(
    canvas,
    'SELFX POS',
    font: image.arial14,
    y: 454,
    color: image.ColorRgb8(255, 255, 255),
  );
  return _toRgb565(canvas);
}

Future<Uint8List> _buildSuccessFrame({
  required double amount,
  required DateTime paidAt,
  String? orderNumber,
  String? transactionId,
  String? restaurantName,
}) async {
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  image.fill(canvas, color: image.ColorRgb8(255, 252, 250));
  final companyLogo = await _loadCompanyLogo();
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 136, y: 4, size: 48);
  }
  final restaurant = _displayText(restaurantName, maximum: 24);
  image.drawString(
    canvas,
    restaurant.isEmpty ? 'Restaurant' : restaurant,
    font: restaurant.length > 18 ? image.arial14 : image.arial24,
    y: 54,
    color: image.ColorRgb8(24, 34, 50),
  );
  _drawAccentDivider(canvas, y: 78);
  image.drawString(
    canvas,
    'PAYMENT SUCCESSFUL',
    font: image.arial24,
    y: 88,
    color: image.ColorRgb8(255, 82, 12),
  );

  final green = image.ColorRgb8(22, 163, 74);
  _fillCircle(canvas, centerX: 160, centerY: 172, radius: 45, color: green);
  image.drawLine(
    canvas,
    x1: 137,
    y1: 172,
    x2: 153,
    y2: 189,
    color: image.ColorRgb8(255, 255, 255),
    thickness: 8,
  );
  image.drawLine(
    canvas,
    x1: 153,
    y1: 189,
    x2: 187,
    y2: 153,
    color: image.ColorRgb8(255, 255, 255),
    thickness: 8,
  );
  image.drawString(
    canvas,
    'Payment received successfully',
    font: image.arial14,
    y: 229,
    color: image.ColorRgb8(24, 34, 50),
  );
  image.drawString(
    canvas,
    'INR ${amount.toStringAsFixed(2)}',
    font: image.arial24,
    y: 260,
    color: image.ColorRgb8(255, 82, 12),
  );
  final order = _displayText(orderNumber, maximum: 30);
  if (order.isNotEmpty) {
    image.drawString(
      canvas,
      'ORDER  $order',
      font: image.arial14,
      y: 304,
      color: image.ColorRgb8(24, 34, 50),
    );
  }
  final transaction = _displayText(transactionId, maximum: 27);
  if (transaction.isNotEmpty) {
    image.drawString(
      canvas,
      'TXN  $transaction',
      font: image.arial14,
      y: 330,
      color: image.ColorRgb8(24, 34, 50),
    );
  }
  image.drawString(
    canvas,
    'PAID  ${_paidAtText(paidAt)}',
    font: image.arial14,
    y: transaction.isEmpty ? 330 : 356,
    color: image.ColorRgb8(71, 85, 105),
  );
  _drawAccentDivider(canvas, y: 394);
  _drawAccentFooter(canvas, top: 407);
  image.drawString(
    canvas,
    'SELFX POS',
    font: image.arial14,
    y: 454,
    color: image.ColorRgb8(255, 255, 255),
  );
  return _toRgb565(canvas);
}

void _fillCircle(
  image.Image canvas, {
  required int centerX,
  required int centerY,
  required int radius,
  required image.Color color,
}) {
  for (var offsetY = -radius; offsetY <= radius; offsetY++) {
    final halfWidth = math.sqrt(radius * radius - offsetY * offsetY).floor();
    image.drawLine(
      canvas,
      x1: centerX - halfWidth,
      y1: centerY + offsetY,
      x2: centerX + halfWidth,
      y2: centerY + offsetY,
      color: color,
    );
  }
}

String _paidAtText(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${months[value.month - 1]} ${value.year} '
      '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

Future<Uint8List> _buildReadyFrame({
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  image.fill(canvas, color: image.ColorRgb8(255, 252, 250));
  final logos = await Future.wait([
    _loadCompanyLogo(),
    _loadRestaurantLogo(restaurantLogoUrl),
  ]);
  final companyLogo = logos[0];
  final restaurantLogo = logos[1];
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 132, y: 7, size: 56);
  } else {
    image.drawString(
      canvas,
      'SELFX',
      font: image.arial24,
      y: 22,
      color: image.ColorRgb8(255, 91, 24),
    );
  }
  final restaurant = _displayText(restaurantName, maximum: 24);
  image.drawString(
    canvas,
    restaurant.isEmpty ? 'Restaurant' : restaurant,
    font: restaurant.length > 18 ? image.arial14 : image.arial24,
    y: 73,
    color: image.ColorRgb8(24, 34, 50),
  );
  _drawAccentDivider(canvas, y: 104);
  image.drawString(
    canvas,
    'READY TO PAY',
    font: image.arial24,
    y: 116,
    color: image.ColorRgb8(255, 82, 12),
  );
  if (restaurantLogo != null) {
    _drawLogoCard(canvas, restaurantLogo, x: 97, y: 161, size: 126);
  } else if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 97, y: 161, size: 126);
  }
  image.drawString(
    canvas,
    'Your payment QR will',
    font: image.arial14,
    y: 310,
    color: image.ColorRgb8(24, 34, 50),
  );
  image.drawString(
    canvas,
    'appear here automatically',
    font: image.arial14,
    y: 334,
    color: image.ColorRgb8(24, 34, 50),
  );
  image.drawString(
    canvas,
    'Fast  |  Simple  |  Secure',
    font: image.arial14,
    y: 379,
    color: image.ColorRgb8(255, 82, 12),
  );
  _drawAccentFooter(canvas, top: 407);
  image.drawString(
    canvas,
    'SELFX POS',
    font: image.arial14,
    y: 454,
    color: image.ColorRgb8(255, 255, 255),
  );
  return _toRgb565(canvas);
}

void _drawAccentDivider(image.Image canvas, {required int y}) {
  final orange = image.ColorRgb8(255, 91, 24);
  image.fillRect(canvas, x1: 96, y1: y, x2: 148, y2: y + 1, color: orange);
  image.fillRect(canvas, x1: 172, y1: y, x2: 224, y2: y + 1, color: orange);
  image.fillRect(canvas, x1: 157, y1: y - 2, x2: 163, y2: y + 4, color: orange);
}

void _drawAccentFooter(image.Image canvas, {required int top}) {
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(0, top),
      image.Point(64, top + 20),
      image.Point(142, top + 8),
      image.Point(222, top + 24),
      image.Point(_dq11Width - 1, top + 5),
      image.Point(_dq11Width - 1, _dq11Height - 1),
      image.Point(0, _dq11Height - 1),
    ],
    color: image.ColorRgb8(255, 221, 198),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(0, top + 22),
      image.Point(74, top + 34),
      image.Point(158, top + 19),
      image.Point(244, top + 33),
      image.Point(_dq11Width - 1, top + 17),
      image.Point(_dq11Width - 1, _dq11Height - 1),
      image.Point(0, _dq11Height - 1),
    ],
    color: image.ColorRgb8(255, 128, 29),
  );
  image.fillPolygon(
    canvas,
    vertices: [
      image.Point(0, top + 42),
      image.Point(86, top + 35),
      image.Point(178, top + 44),
      image.Point(258, top + 34),
      image.Point(_dq11Width - 1, top + 40),
      image.Point(_dq11Width - 1, _dq11Height - 1),
      image.Point(0, _dq11Height - 1),
    ],
    color: image.ColorRgb8(255, 82, 12),
  );
}

Future<void> _drawBrandHeader(
  image.Image canvas, {
  String? restaurantName,
  String? restaurantLogoUrl,
}) async {
  final logos = await Future.wait([
    _loadCompanyLogo(),
    _loadRestaurantLogo(restaurantLogoUrl),
  ]);
  final companyLogo = logos[0];
  final restaurantLogo = logos[1];
  if (companyLogo != null) {
    _drawLogoCard(canvas, companyLogo, x: 9, y: 9, size: 56);
  }
  if (restaurantLogo != null) {
    _drawLogoCard(canvas, restaurantLogo, x: 255, y: 9, size: 56);
  }

  image.drawString(
    canvas,
    'SELFX POS',
    font: image.arial14,
    y: 16,
    color: image.ColorRgb8(255, 255, 255),
  );
  final name = _displayText(restaurantName, maximum: 22);
  if (name.isNotEmpty) {
    image.drawString(
      canvas,
      name,
      font: image.arial14,
      y: 43,
      color: image.ColorRgb8(203, 213, 225),
    );
  }
}

void _drawLogoCard(
  image.Image canvas,
  image.Image logo, {
  required int x,
  required int y,
  required int size,
}) {
  image.fillRect(
    canvas,
    x1: x,
    y1: y,
    x2: x + size - 1,
    y2: y + size - 1,
    color: image.ColorRgb8(255, 255, 255),
  );
  final resized = image.copyResize(
    logo,
    width: size - 8,
    height: size - 8,
    maintainAspect: true,
    backgroundColor: image.ColorRgba8(255, 255, 255, 0),
    interpolation: image.Interpolation.average,
  );
  image.compositeImage(
    canvas,
    resized,
    dstX: x + 4,
    dstY: y + 4,
    dstW: size - 8,
    dstH: size - 8,
  );
}

Future<image.Image?> _loadCompanyLogo() {
  return _companyLogoFuture ??= () async {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidates = [
      File(
        '${executableDirectory.path}${Platform.pathSeparator}data'
        '${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}web'
        '${Platform.pathSeparator}favicon.png',
      ),
      File('web${Platform.pathSeparator}favicon.png'),
      File(
        '${executableDirectory.path}${Platform.pathSeparator}data'
        '${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}images${Platform.pathSeparator}mainlogo.png',
      ),
      File(
        'assets${Platform.pathSeparator}images${Platform.pathSeparator}mainlogo.png',
      ),
    ];
    for (final file in candidates) {
      if (!await file.exists()) continue;
      final decoded = image.decodeImage(await file.readAsBytes());
      if (decoded != null) return decoded;
    }
    return null;
  }();
}

Future<image.Image?> _loadRestaurantLogo(String? rawUrl) {
  final url = rawUrl?.trim();
  if (url == null || url.isEmpty) return Future.value(null);
  return _restaurantLogoCache.putIfAbsent(url, () async {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return null;
    }
    final uri = parsed.hasScheme
        ? parsed
        : Uri.parse(PosAppInfo.defaultServerUrl).resolveUri(parsed);
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > 2 * 1024 * 1024) {
        return null;
      }
      final builder = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 4))) {
        length += chunk.length;
        if (length > 2 * 1024 * 1024) return null;
        builder.add(chunk);
      }
      return image.decodeImage(builder.takeBytes());
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  });
}

int _drawQr(
  image.Image canvas,
  String data, {
  required int top,
  required int maxSize,
  bool decorated = false,
}) {
  final qrCode = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final qrImage = QrImage(qrCode);
  const quietModules = 4;
  final moduleSize = math.max(
    1,
    maxSize ~/ (qrImage.moduleCount + quietModules * 2),
  );
  final renderedSize = (qrImage.moduleCount + quietModules * 2) * moduleSize;
  final left = (_dq11Width - renderedSize) ~/ 2;
  if (decorated) {
    final centerX = _dq11Width ~/ 2;
    final centerY = top + renderedSize ~/ 2;
    final accent = image.ColorRgb8(255, 213, 190);
    for (
      var radius = renderedSize ~/ 2 + 7;
      radius <= renderedSize ~/ 2 + 19;
      radius += 4
    ) {
      image.drawCircle(
        canvas,
        x: centerX,
        y: centerY,
        radius: radius,
        color: accent,
      );
    }
    image.fillRect(
      canvas,
      x1: left - 4,
      y1: top - 3,
      x2: left + renderedSize + 4,
      y2: top + renderedSize + 4,
      color: image.ColorRgb8(226, 232, 240),
    );
  }
  image.fillRect(
    canvas,
    x1: left,
    y1: top,
    x2: left + renderedSize - 1,
    y2: top + renderedSize - 1,
    color: image.ColorRgb8(255, 255, 255),
  );
  for (var row = 0; row < qrImage.moduleCount; row++) {
    for (var column = 0; column < qrImage.moduleCount; column++) {
      if (!qrImage.isDark(row, column)) continue;
      final x = left + (column + quietModules) * moduleSize;
      final y = top + (row + quietModules) * moduleSize;
      image.fillRect(
        canvas,
        x1: x,
        y1: y,
        x2: x + moduleSize - 1,
        y2: y + moduleSize - 1,
        color: image.ColorRgb8(15, 23, 42),
      );
    }
  }
  return top + renderedSize;
}

String _displayText(String? value, {required int maximum}) {
  final clean =
      value
          ?.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim() ??
      '';
  if (clean.length <= maximum) return clean;
  return '${clean.substring(0, maximum - 3)}...';
}

int _remainingSeconds(DateTime target) {
  final milliseconds = target.difference(DateTime.now()).inMilliseconds;
  if (milliseconds <= 0) return 0;
  return (milliseconds / Duration.millisecondsPerSecond).ceil();
}

String _durationText(int totalSeconds) {
  final safeSeconds = math.max(0, totalSeconds);
  final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Uint8List _toRgb565(image.Image source) {
  final output = Uint8List(_dq11FrameBytes);
  var offset = 0;
  // DQ11's panel controller consumes rows from bottom to top. X remains in
  // normal left-to-right order; reversing X would mirror all text and logos.
  for (var y = _dq11Height - 1; y >= 0; y--) {
    for (var x = 0; x < _dq11Width; x++) {
      final pixel = source.getPixel(x, y);
      final red = pixel.r.toInt();
      final green = pixel.g.toInt();
      final blue = pixel.b.toInt();
      final rgb565 = ((red & 0xf8) << 8) | ((green & 0xfc) << 3) | (blue >> 3);
      // DQ11 accepts RGB565 with the most-significant byte first.
      output[offset++] = rgb565 >> 8;
      output[offset++] = rgb565 & 0xff;
    }
  }
  return output;
}

Uint8List _rgb565FrameToJpeg(Uint8List frame) {
  if (frame.length != _dq11FrameBytes) {
    throw ArgumentError.value(
      frame.length,
      'frame.length',
      'Expected $_dq11FrameBytes RGB565 bytes.',
    );
  }
  final canvas = image.Image(width: _dq11Width, height: _dq11Height);
  var offset = 0;
  for (var y = _dq11Height - 1; y >= 0; y--) {
    for (var x = 0; x < _dq11Width; x++) {
      final rgb565 = (frame[offset++] << 8) | frame[offset++];
      final red5 = (rgb565 >> 11) & 0x1f;
      final green6 = (rgb565 >> 5) & 0x3f;
      final blue5 = rgb565 & 0x1f;
      canvas.setPixelRgb(
        x,
        y,
        (red5 * 255 + 15) ~/ 31,
        (green6 * 255 + 31) ~/ 63,
        (blue5 * 255 + 15) ~/ 31,
      );
    }
  }
  return Uint8List.fromList(image.encodeJpg(canvas, quality: 92));
}
