import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Downloads and rasterizes a logo for ESC/POS thermal printers.
class ThermalLogo {
  ThermalLogo._();

  static final Map<String, List<int>> _cache = {};
  static final Map<String, DateTime> _unavailableUntil = {};

  /// Raster ESC/POS bytes for [url], or null when unavailable.
  static Future<List<int>?> rasterBytes({
    required String? url,
    required int maxWidthDots,
    String align = 'left',
    int? paperWidthDots,
  }) async {
    if (url == null || url.trim().isEmpty || maxWidthDots < 16) {
      return null;
    }

    final paper = paperWidthDots ?? maxWidthDots;
    final cacheKey = '$url|$maxWidthDots|$align|$paper';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final pausedUntil = _unavailableUntil[url];
    if (pausedUntil != null && DateTime.now().isBefore(pausedUntil)) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        _unavailableUntil[url] = DateTime.now().add(const Duration(seconds: 30));
        return null;
      }

      final decoded = img.decodeImage(response.bodyBytes);
      if (decoded == null) {
        return null;
      }

      final resized = _resize(decoded, maxWidthDots);
      final positioned = _positionOnPaper(resized, paper, align);
      final raster = _toRasterBytes(positioned);
      _cache[cacheKey] = raster;
      _unavailableUntil.remove(url);
      return raster;
    } catch (_) {
      _unavailableUntil[url] = DateTime.now().add(const Duration(seconds: 30));
      return null;
    }
  }

  static img.Image _resize(img.Image source, int maxWidthDots) {
    if (source.width <= maxWidthDots) {
      return source;
    }

    final ratio = maxWidthDots / source.width;
    final targetHeight = (source.height * ratio).round().clamp(1, 512);
    return img.copyResize(
      source,
      width: maxWidthDots,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  static img.Image _positionOnPaper(img.Image image, int paperWidthDots, String align) {
    if (align == 'left' || image.width >= paperWidthDots) {
      return image;
    }

    final canvas = img.Image(width: paperWidthDots, height: image.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final x = align == 'right'
        ? paperWidthDots - image.width
        : ((paperWidthDots - image.width) / 2).round();

    img.compositeImage(canvas, image, dstX: x.clamp(0, paperWidthDots), dstY: 0);
    return canvas;
  }

  static List<int> _toRasterBytes(img.Image image) {
    final width = image.width;
    final height = image.height;
    final bytesPerRow = (width + 7) ~/ 8;
    final out = Uint8List(8 + bytesPerRow * height);
    var offset = 0;

    // GS v 0 — raster bit image (normal density).
    out[offset++] = 0x1D;
    out[offset++] = 0x76;
    out[offset++] = 0x30;
    out[offset++] = 0x00;
    out[offset++] = bytesPerRow & 0xFF;
    out[offset++] = (bytesPerRow >> 8) & 0xFF;
    out[offset++] = height & 0xFF;
    out[offset++] = (height >> 8) & 0xFF;

    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < bytesPerRow; xByte++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x < width) {
            final pixel = image.getPixel(x, y);
            final luminance = img.getLuminance(pixel);
            if (luminance < 160) {
              value |= 0x80 >> bit;
            }
          }
        }
        out[offset++] = value;
      }
    }

    return out;
  }
}
