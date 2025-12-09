import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PaymentService {
  final SupabaseClient supabase;
  final Uuid uuid = const Uuid();

  PaymentService(this.supabase);

  // Create PayChangu payment for a single order
  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required String payerCustomerId,
    String paymentMethod = 'mobile_money',
    String? phoneNumber,
  }) async {
    try {
      // Generate idempotency key
      final idempotencyKey = uuid.v4();

      debugPrint(
        'Creating payment for order $orderId with idempotency key: $idempotencyKey',
      );

      // Call Edge Function
      final response = await supabase.functions.invoke(
        'create-paychangu-payment',
        body: {
          'order_id': orderId,
          'payer_customer_id': payerCustomerId,
          'payment_method': paymentMethod,
          if (phoneNumber != null) 'phone_number': phoneNumber,
        },
        headers: {'Idempotency-Key': idempotencyKey},
      );

      debugPrint('Payment creation response: ${response.data}');
      return response.data;
    } catch (e) {
      debugPrint('Error creating payment: $e');
      rethrow;
    }
  }

  // Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      final response = await supabase.functions.invoke(
        'check-payment-status',
        body: {'payment_id': paymentId},
      );

      return response.data;
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      rethrow;
    }
  }

  // Get payment details
  Future<Map<String, dynamic>> getPaymentDetails(String paymentId) async {
    try {
      final response = await supabase
          .from('payments')
          .select('''
            *,
            order:orders(
              id,
              order_number,
              total_amount,
              payment_status,
              establishment:establishments(name)
            )
          ''')
          .eq('id', paymentId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching payment details: $e');
      rethrow;
    }
  }

  // Get user's payment history
  Future<List<Map<String, dynamic>>> getPaymentHistory({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await supabase
          .from('payments')
          .select('''
            *,
            order:orders(
              id,
              order_number,
              total_amount,
              payment_status,
              establishment:establishments(name)
            )
          ''')
          .eq('payer_customer_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching payment history: $e');
      rethrow;
    }
  }

  // Subscribe to payment status changes
  RealtimeChannel subscribeToPayment(String paymentId) {
    return supabase
        .channel('payment-$paymentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: paymentId,
          ),
          callback: (payload) {
            debugPrint('Payment update received: $payload');
          },
        );
  }

  // Poll payment status until completed or failed
  Stream<Map<String, dynamic>> pollPaymentStatus(
    String paymentId, {
    Duration interval = const Duration(seconds: 5),
    int maxAttempts = 60, // 5 minutes
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    int attempts = 0;

    Future<void> poll() async {
      if (attempts >= maxAttempts) {
        controller.add({
          'status': 'timeout',
          'message': 'Payment status check timeout',
          'payment_id': paymentId,
        });
        await controller.close();
        return;
      }

      try {
        final status = await checkPaymentStatus(paymentId);
        controller.add(status);

        if (status['status'] == 'completed' || status['status'] == 'failed') {
          await controller.close();
          return;
        }

        // Continue polling
        attempts++;
        await Future.delayed(interval);
        await poll();
      } catch (e) {
        controller.addError(e);
        await controller.close();
      }
    }

    // Start polling
    poll();
    return controller.stream;
  }
}
