import 'package:flutter/material.dart';

import '../l10n/pos_l10n.dart';

const List<String> kOrderCancelReasons = [
  'customer_request',
  'duplicate_order',
  'item_unavailable',
  'wrong_order',
  'payment_issue',
  'kitchen_issue',
  'test_order',
  'other',
];

const List<String> kManualPaymentMethods = [
  'cash',
  'card',
  'wallet',
  'other',
];

const List<String> kGatewayPaymentMethods = [
  'phonepe',
  'paytm',
];

/// Core tender methods plus active QR gateways (PhonePe/Paytm when configured).
List<String> markPaidPaymentMethods(Iterable<String> activeGatewaySlugs) {
  final active = activeGatewaySlugs
      .map((slug) => slug.trim().toLowerCase())
      .where(kGatewayPaymentMethods.contains)
      .toSet();
  return [
    ...kManualPaymentMethods,
    ...kGatewayPaymentMethods.where(active.contains),
  ];
}

String orderCancelReasonLabel(BuildContext context, String code) {
  return switch (code) {
    'customer_request' => context.posText(
        'cancelReasonCustomerRequest',
        'Customer request',
      ),
    'duplicate_order' =>
      context.posText('cancelReasonDuplicateOrder', 'Duplicate order'),
    'item_unavailable' =>
      context.posText('cancelReasonItemUnavailable', 'Item unavailable'),
    'wrong_order' =>
      context.posText('cancelReasonWrongOrder', 'Wrong order / mistake'),
    'payment_issue' =>
      context.posText('cancelReasonPaymentIssue', 'Payment issue'),
    'kitchen_issue' =>
      context.posText('cancelReasonKitchenIssue', 'Kitchen issue'),
    'test_order' =>
      context.posText('cancelReasonTestOrder', 'Test / training order'),
    'other' => context.posText('cancelReasonOther', 'Other'),
    _ => code,
  };
}

String manualPaymentMethodLabel(BuildContext context, String method) {
  return switch (method) {
    'cash' => context.posText('methodCash', 'Cash'),
    'card' => context.posText('methodCard', 'Card'),
    'wallet' => context.posText('methodWallet', 'Wallet'),
    'other' => context.posText('methodOther', 'Other'),
    'phonepe' => context.posText('methodPhonepe', 'UPI Payment'),
    'paytm' => context.posText('methodPaytm', 'UPI Payment'),
    _ => method,
  };
}

bool isManualPaymentMethod(String? method) {
  final value = (method ?? '').trim().toLowerCase();
  return kManualPaymentMethods.contains(value) ||
      kGatewayPaymentMethods.contains(value);
}
