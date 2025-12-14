// Stub implementation for web - PayChangu is not used on web
class PayChangu {
  PayChangu(dynamic config);

  dynamic launchPayment({
    required dynamic request,
    required Function(dynamic) onSuccess,
    required Function(dynamic) onError,
    required Function() onCancel,
  }) {
    throw UnimplementedError('PayChangu is only available on mobile platforms');
  }
}

class PayChanguConfig {
  PayChanguConfig({required String secretKey, required bool isTestMode});
}

class PaymentRequest {
  PaymentRequest({
    required String txRef,
    required int amount,
    required dynamic currency,
    required String firstName,
    required String lastName,
    required String email,
    required String callbackUrl,
    required String returnUrl,
    required Map<String, dynamic> meta,
  });
}

class Currency {
  static const MWK = null;
}
