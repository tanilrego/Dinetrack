// Web stub implementation - PayChangu is not used on web
// This avoids importing webview_flutter on web platforms

import 'package:flutter/widgets.dart';

class PayChangu {
  PayChangu(PayChanguConfig config);

  Widget launchPayment({
    required PaymentRequest request,
    required Function(dynamic) onSuccess,
    required Function(dynamic) onError,
    required Function() onCancel,
  }) {
    // Return an error widget - this should never be called on web
    // because web uses PaychanguInlinePaymentScreen with iframe instead
    return const Center(child: Text('PayChangu SDK not available on web'));
  }
}

class PayChanguConfig {
  PayChanguConfig({required String secretKey, required bool isTestMode});
}

class PaymentRequest {
  PaymentRequest({
    required String txRef,
    required int amount,
    required Currency currency,
    required String firstName,
    required String lastName,
    required String email,
    required String callbackUrl,
    required String returnUrl,
    required Map<String, dynamic> meta,
  });
}

class Currency {
  static const Currency MWK = Currency._();
  const Currency._();
}
