import 'package:intl/intl.dart';

import '../l10n/pos_translation_store.dart';

String _t(String key, String fallback) =>
    PosTranslationStore.instance.text(key, fallback);

const Map<String, String> _currencySymbols = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
  'CNY': '¥',
  'AUD': r'A$',
  'CAD': r'C$',
  'SGD': r'S$',
  'HKD': r'HK$',
  'NZD': r'NZ$',
  'CHF': 'CHF ',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'QAR': 'QAR ',
  'KWD': 'KWD ',
  'BHD': 'BHD ',
  'OMR': 'OMR ',
  'MYR': 'RM ',
  'THB': '฿',
  'PHP': '₱',
  'IDR': 'Rp ',
  'VND': '₫',
  'KRW': '₩',
  'ZAR': 'R ',
  'NGN': '₦',
  'BRL': r'R$',
  'MXN': r'MX$',
  'SEK': 'kr ',
  'NOK': 'kr ',
  'DKK': 'kr ',
  'PLN': 'zł ',
  'TRY': '₺',
  'RUB': '₽',
};

String normalizeCurrencyCode(String? currencyCode) {
  final code = (currencyCode ?? '').trim().toUpperCase();
  return code.isEmpty ? 'USD' : code;
}

String currencySymbol(String currencyCode) {
  final code = normalizeCurrencyCode(currencyCode);
  return _currencySymbols[code] ?? '$code ';
}

String currencyDisplayLabel(String currencyCode) {
  final code = normalizeCurrencyCode(currencyCode);
  final symbol = _currencySymbols[code];
  if (symbol == null || symbol.trim() == code) {
    return code;
  }
  return '$symbol · $code';
}

String formatMoney(double amount, String currencyCode) {
  final code = normalizeCurrencyCode(currencyCode);
  final symbol = currencySymbol(code);
  final decimals = code == 'JPY' || code == 'KRW' ? 0 : 2;

  try {
    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: symbol,
      decimalDigits: decimals,
    ).format(amount);
    if (formatted.contains(symbol.trim()) || formatted.contains(code)) {
      return formatted;
    }
  } catch (_) {
    // Fall through to manual formatting.
  }

  if (decimals == 0) {
    return '$symbol${amount.round()}';
  }
  return '$symbol${amount.toStringAsFixed(decimals)}';
}

int? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  return int.tryParse(value, radix: 16);
}

String formatPairingCode(String code) {
  final digits = code.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 6) return digits;
  return '${digits.substring(0, 3)} ${digits.substring(3)}';
}

String formatPaymentMethod(String? method) {
  if (method == null || method.isEmpty) return '';

  switch (method.toLowerCase()) {
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'counter':
      return 'Pay at counter';
    case 'phonepe':
    case 'paytm':
      return 'UPI Payment';
    case 'stripe':
      return 'Card';
    default:
      return method
          .split('_')
          .map((part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

String formatPaymentStatus(String? status) {
  switch (status) {
    case 'paid':
      return _t('commonPaid', 'Paid');
    case 'partial':
      return _t('payStatusPartial', 'Partially paid');
    case 'refunded':
      return _t('payStatusRefunded', 'Refunded');
    case 'pending':
      return _t('payStatusPending', 'Payment pending');
    default:
      if (status == null || status.isEmpty) {
        return _t('payStatusPending', 'Payment pending');
      }
      return status
          .split('_')
          .map((part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

const Map<String, String> _thermalCurrencySymbols = {
  'USD': r'$',
  'EUR': 'EUR ',
  'GBP': 'GBP ',
  'INR': '^',
  'JPY': 'JPY ',
  'CNY': 'CNY ',
  'AUD': r'A$',
  'CAD': r'C$',
  'SGD': r'S$',
  'HKD': r'HK$',
  'NZD': r'NZ$',
  'CHF': 'CHF ',
  'AED': 'AED ',
  'SAR': 'SAR ',
  'QAR': 'QAR ',
  'BHD': 'BHD ',
  'OMR': 'OMR ',
  'MYR': 'RM ',
  'THB': 'THB ',
  'PHP': 'PHP ',
  'IDR': 'IDR ',
  'VND': 'VND ',
  'KRW': 'KRW ',
  'ZAR': 'ZAR ',
  'NGN': 'NGN ',
  'BRL': r'R$',
  'MXN': r'MX$',
  'SEK': 'SEK ',
  'NOK': 'NOK ',
  'DKK': 'DKK ',
  'PLN': 'PLN ',
  'TRY': 'TRY ',
  'RUB': 'RUB ',
};

String formatMoneyThermal(
  double amount,
  String currencyCode, {
  bool showSymbol = true,
}) {
  final code = normalizeCurrencyCode(currencyCode);
  final decimals = code == 'JPY' || code == 'KRW' ? 0 : 2;
  final withSeparators = NumberFormat('#,##0${decimals == 0 ? '' : '.00'}', 'en_US')
      .format(decimals == 0 ? amount.abs().round() : amount.abs());
  final signed = amount < 0 ? '-$withSeparators' : withSeparators;

  if (!showSymbol) {
    return signed;
  }

  final symbol = _thermalCurrencySymbols[code] ?? '$code ';
  if (symbol.endsWith(' ')) {
    return '${symbol.trim()} $signed';
  }
  return '$symbol$signed';
}

String formatOrderType(String? type) {
  if (type == null || type.isEmpty) return '';

  switch (type) {
    case 'dine_in':
      return _t('orderTypeDineIn', 'Dine in');
    case 'takeaway':
    case 'pickup':
      return _t('orderTypeTakeaway', 'Takeaway');
    case 'delivery':
      return _t('orderTypeDelivery', 'Delivery');
    default:
      return type
          .split('_')
          .map((part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

/// Receipt / token thermal datetime: `20 Jun 2026 02:30 PM`
String formatReceiptDatetime(DateTime dateTime) {
  return DateFormat('dd MMM yyyy hh:mm a', 'en_US').format(dateTime.toLocal());
}

String formatReceiptDatetimeRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return formatReceiptDatetime(parsed);
}
