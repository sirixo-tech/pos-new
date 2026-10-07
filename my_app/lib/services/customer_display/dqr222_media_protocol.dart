import 'dart:convert';
import 'dart:typed_data';

const int dqr222MediaChunkSize = 1024;
// Conservatively interpret the vendor's "under 100 KB" as < 100,000 bytes.
const int dqr222AdvertisementSizeLimit = 100000;
const dqr222StartAdvertisementCommands = ['settimer**5', 'startrotation'];

void validateDqr222MediaSize(int size, Dqr222MediaKind kind) {
  if (kind == Dqr222MediaKind.advertisement &&
      size >= dqr222AdvertisementSizeLimit) {
    throw const FormatException(
      'Advertisement JPEG must be under 100 KB (100,000 bytes).',
    );
  }
}

enum Dqr222MediaKind {
  advertisement,
  audio;

  String get fileInfoCommand => this == audio ? 'fileinfomp3' : 'fileinfo';
  String get fileInfoKey => this == audio ? 'mp3files' : 'images';
  String get uploadPrefix => this == audio ? 'sendingaudio' : 'sending';
}

const dqr222AudioSlots = <String, String>{
  'welcome.mp3': 'Welcome',
  'displayqr.mp3': 'Payment QR',
  'success.mp3': 'Payment successful',
  'fail.mp3': 'Payment failed / expired',
  'cancel.mp3': 'Payment cancelled',
  'pending.mp3': 'Payment pending',
};

bool looksLikeDqr222Mp3(Uint8List bytes) {
  if (bytes.length < 3) return false;
  final id3 = bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
  final frame = bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
  return id3 || frame;
}

/// Known payment slots, or any simple mp3 name already stored on the display.
String playableDqr222AudioFileName(String value) {
  final name = value.trim();
  final lower = name.toLowerCase();
  for (final slot in dqr222AudioSlots.keys) {
    if (slot.toLowerCase() == lower) return slot;
  }
  if (RegExp(r'^[A-Za-z0-9_-]+\.mp3$').hasMatch(name)) return name;
  throw const FormatException('Select a device audio file.');
}

String normalizeDqr222MediaFileName(String value, Dqr222MediaKind kind) {
  if (kind == Dqr222MediaKind.advertisement) {
    return normalizeDqr222AdvertisementFileName(value);
  }
  if (!dqr222AudioSlots.containsKey(value)) {
    throw const FormatException('Select a device audio slot.');
  }
  return value;
}

class Dqr222AdvertisementImage {
  const Dqr222AdvertisementImage({required this.fileName, required this.size});

  final String fileName;
  final int size;
}

class Dqr222AdvertisementUploadResult {
  const Dqr222AdvertisementUploadResult({
    required this.fileName,
    required this.originalSize,
    required this.storedSize,
    required this.chunkCount,
  });

  final String fileName;
  final int? originalSize;
  final int storedSize;
  final int chunkCount;

  bool get replacedExisting => originalSize != null;
}

String normalizeDqr222AdvertisementFileName(String value) {
  final fileName = value.trim();
  if (!RegExp(
    r'^[A-Za-z0-9_-]+\.jpeg$',
    caseSensitive: false,
  ).hasMatch(fileName)) {
    throw const FormatException(
      'Use a simple .jpeg filename, for example 1.jpeg or offer_1.jpeg.',
    );
  }
  return fileName;
}

String buildDqr222AdvertisementUploadCommand({
  required String fileName,
  required int fileSize,
  int chunkSize = dqr222MediaChunkSize,
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) {
  final normalized = normalizeDqr222MediaFileName(fileName, kind);
  validateDqr222MediaSize(fileSize, kind);
  if (fileSize <= 0) {
    throw ArgumentError.value(fileSize, 'fileSize', 'File must not be empty.');
  }
  if (chunkSize != dqr222MediaChunkSize) {
    throw ArgumentError.value(
      chunkSize,
      'chunkSize',
      'DQR-222 uploads use 1024-byte chunks.',
    );
  }
  return '${kind.uploadPrefix}**$normalized**$fileSize**$chunkSize';
}

/// Single-file command captured in the user's vendor investigation.
/// Restrict the target to a basename, never a folder, wildcard, or audio file.
String buildDqr222AdvertisementDeleteCommand(String fileName) =>
    'delete**images**${normalizeDqr222AdvertisementFileName(fileName)}';

void verifyDqr222AdvertisementDeletion({
  required String fileName,
  required List<Dqr222AdvertisementImage> before,
  required List<Dqr222AdvertisementImage> after,
}) {
  if (after.any((file) => file.fileName == fileName)) {
    throw StateError(
      '$fileName is still on the display. Deletion not verified.',
    );
  }
  for (final file in before.where((file) => file.fileName != fileName)) {
    if (!after.any(
      (other) => other.fileName == file.fileName && other.size == file.size,
    )) {
      throw StateError(
        'File verification changed unexpectedly for ${file.fileName}. Refresh the display files.',
      );
    }
  }
}

List<Dqr222AdvertisementImage> parseDqr222AdvertisementFileInfo(
  String response, {
  Dqr222MediaKind kind = Dqr222MediaKind.advertisement,
}) {
  final payload = _extractJsonObject(response, kind.fileInfoKey);
  final label = kind == Dqr222MediaKind.audio ? 'audio' : 'advertisement';
  if (payload == null) {
    throw FormatException(
      'DQR-222 did not return $label file information.',
    );
  }
  final decoded = jsonDecode(payload);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('DQR-222 returned invalid file information.');
  }
  final rawImages = decoded[kind.fileInfoKey];
  if (rawImages is! List) {
    throw FormatException('DQR-222 file information has no $label list.');
  }
  final images = <Dqr222AdvertisementImage>[];
  for (final rawImage in rawImages) {
    if (rawImage is! Map) continue;
    final fileName = rawImage['filename']?.toString().trim() ?? '';
    final rawSize = rawImage['size'];
    final size = rawSize is num ? rawSize.toInt() : int.tryParse('$rawSize');
    if (fileName.isEmpty || size == null || size < 0) continue;
    images.add(Dqr222AdvertisementImage(fileName: fileName, size: size));
  }
  images.sort(
    (left, right) => _naturalNameCompare(left.fileName, right.fileName),
  );
  return images;
}

String? _extractJsonObject(String input, String requiredKey) {
  final startPattern = RegExp('\\{\\s*"${RegExp.escape(requiredKey)}"\\s*:');
  final match = startPattern.firstMatch(input);
  if (match == null) return null;
  final start = match.start;
  var depth = 0;
  var inString = false;
  var escaping = false;
  for (var index = start; index < input.length; index++) {
    final character = input[index];
    if (inString) {
      if (escaping) {
        escaping = false;
      } else if (character == '\\') {
        escaping = true;
      } else if (character == '"') {
        inString = false;
      }
      continue;
    }
    if (character == '"') {
      inString = true;
    } else if (character == '{') {
      depth++;
    } else if (character == '}') {
      depth--;
      if (depth == 0) return input.substring(start, index + 1);
    }
  }
  return null;
}

int _naturalNameCompare(String left, String right) {
  final leftNumber = int.tryParse(left.split('.').first);
  final rightNumber = int.tryParse(right.split('.').first);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (leftNumber != null) return -1;
  if (rightNumber != null) return 1;
  return left.toLowerCase().compareTo(right.toLowerCase());
}
