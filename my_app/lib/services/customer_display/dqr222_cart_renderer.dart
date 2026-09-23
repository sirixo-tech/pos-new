import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image;

/// Fits the most recent items and the complete payable total on a 320x480 unit.
Future<Uint8List> renderDqr222CartJpeg(Map<String, dynamic> bill) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xffffffff), BlendMode.src);
  void text(String value, double x, double y, double width, double size,
      {bool bold = false, TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(
        color: const Color(0xff172033), fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
      textDirection: TextDirection.ltr, textAlign: align, maxLines: 1, ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, Offset(x, y));
    painter.dispose();
  }
  String money(dynamic value) => (value as num? ?? 0).toStringAsFixed(2);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 62), Paint()..color = const Color(0xffffeddc));
  text('${bill['storeInfo']?['storeName'] ?? 'Your order'}', 16, 18, 288, 22, bold: true);
  final items = bill['items'] as List;
  text('YOUR ORDER · ${items.length} items', 16, 68, 288, 16, bold: true);
  final start = items.length > 5 ? items.length - 5 : 0;
  for (var i = start; i < items.length; i++) {
    final item = items[i];
    final y = 100.0 + (i - start) * 53;
    if ((i - start).isEven) {
      canvas.drawRect(Rect.fromLTWH(8, y - 3, 304, 52), Paint()..color = const Color(0xfff4f6f8));
    }
    text('${item['itemName']}', 16, y, 190, 17, bold: true);
    text('${item['quantity']} × ${money(item['pricePerUnit'])}', 16, y + 26, 190, 14);
    text(money(item['total']), 214, y + 12, 90, 17, bold: true, align: TextAlign.right);
  }
  if (start > 0) text('Showing last 5 of ${items.length} items', 16, 369, 288, 13);
  canvas.drawRect(const Rect.fromLTWH(0, 400, 320, 80), Paint()..color = const Color(0xffffeddc));
  text('PAYABLE', 16, 410, 288, 15, bold: true);
  text('INR ${money(bill['totals']?['totalAmount'])}', 16, 433, 288, 28, bold: true);
  final picture = recorder.endRecording();
  final bitmap = await picture.toImage(320, 480);
  try {
    final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    return Uint8List.fromList(image.encodeJpg(image.decodePng(png!.buffer.asUint8List())!, quality: 85));
  } finally {
    bitmap.dispose();
    picture.dispose();
  }
}
