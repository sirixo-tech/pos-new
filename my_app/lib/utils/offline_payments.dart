/// Payment methods allowed while the POS is offline (cash / external only).
const offlineAllowedPaymentMethods = {
  'cash',
  'card',
  'wallet',
  'other',
};

bool isQrPaymentMethod(String method) {
  return method == 'phonepe' || method == 'paytm';
}

bool isOfflineAllowedPaymentMethod(String method) {
  return offlineAllowedPaymentMethods.contains(method);
}
