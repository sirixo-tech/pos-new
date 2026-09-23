import 'dart:convert';

/// Native bill command; no image rendering or upload is needed.
String buildDqr222BillCommand(Map<String, dynamic> cart) {
  final items = cart['items'] as List? ?? const [];
  return 'billjson**${jsonEncode({
    'storeInfo': {
      'storeName': cart['restaurant_name'] ?? '',
      'address': '', 'phone': '', 'gstin': '',
    },
    'billInfo': {'billNo': '', 'date': '', 'time': '', 'cashier': ''},
    'customerInfo': {'customerName': '', 'customerPhone': ''},
    'items': items.map((item) => {
      'itemName': item['name'],
      'quantity': item['quantity'],
      'pricePerUnit': item['price'],
      'total': (item['quantity'] as num) * (item['price'] as num),
    }).toList(),
    'totals': {
      'subTotal': cart['subtotal'],
      'tax': cart['tax'] ?? 0,
      'discount': (cart['discount'] as Map?)?['amount'] ?? 0,
      'totalAmount': cart['total'],
      'amountPaid': 0,
      'paymentMethod': '',
    },
    'footer': {'message': 'Please review your order', 'website': ''},
  })}';
}

String buildDqr222PaymentCommand({
  required String qr,
  required double? amount,
  String? upiId,
}) {
  final resolvedUpiId = _resolveUpiId(qr, upiId);
  if (resolvedUpiId == null) {
    throw ArgumentError(
      'DQR-222 payment command requires a UPI ID or a QR pa parameter.',
    );
  }
  return 'DisplayQRCodeScreen**${_commandField(qr)}'
      '**${_amountField(amount)}**${_commandField(resolvedUpiId)}';
}

String? _resolveUpiId(String qr, String? explicitUpiId) {
  final explicit = explicitUpiId?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final parsed = Uri.tryParse(qr);
  final payeeAddress = parsed?.queryParameters['pa']?.trim();
  return payeeAddress == null || payeeAddress.isEmpty ? null : payeeAddress;
}

String _amountField(double? amount) {
  if (amount == null || !amount.isFinite || amount < 0) return '0';
  final fixed = amount.toStringAsFixed(2);
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}

String _commandField(String value) =>
    value.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll('**', ' ').trim();
