import 'package:flutter/material.dart';
import 'package:paychangu_flutter/paychangu_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaychanguInlinePaymentScreen extends StatelessWidget {
  final String checkoutUrl;
  final String transactionReference;
  final String orderId;
  final VoidCallback onSuccess;
  final Function(String) onFailure;
  final VoidCallback onCancel;
  final String secretKey;

  const PaychanguInlinePaymentScreen({
    super.key,
    required this.checkoutUrl,
    required this.transactionReference,
    required this.orderId,
    required this.onSuccess,
    required this.onFailure,
    required this.onCancel,
    required this.secretKey,
  });

  // Helper function to fetch all necessary payment data
  Future<Map<String, dynamic>> _fetchPaymentData(
    SupabaseClient supabase,
    String userId,
    String orderId,
  ) async {
    try {
      // Fetch order details including customer and establishment info
      final orderResponse = await supabase
          .from('orders')
          .select('''
        total_amount,
        establishment_id,
        customer:users!orders_customer_id_fkey (
          email,
          full_name,
          phone
        )
      ''')
          .eq('id', orderId)
          .single();

      final totalAmount = orderResponse['total_amount'] as double;
      final establishmentId = orderResponse['establishment_id'] as String;
      final customerData = orderResponse['customer'] as Map<String, dynamic>;

      // Parse customer name (assuming full_name is stored as "First Last")
      final fullName = customerData['full_name'] as String? ?? 'Customer';
      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : 'Customer';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : 'Name';

      // Fetch establishment email for business notifications (optional)
      final establishmentResponse = await supabase
          .from('establishments')
          .select('name, owner_id')
          .eq('id', establishmentId)
          .single();

      return {
        'amount': (totalAmount * 100)
            .round(), // Convert to smallest currency unit if needed
        'first_name': firstName,
        'last_name': lastName,
        'email': customerData['email'] as String? ?? '$userId@dinetrack.com',
        'phone':
            customerData['phone'] as String? ??
            '', // Can be used for mobile money
        'establishment_id': establishmentId,
        'establishment_name':
            establishmentResponse['name'] as String? ?? 'Restaurant',
      };
    } catch (e) {
      debugPrint('Error fetching payment data: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the Supabase client
    final supabase = Supabase.instance.client;
    // Get the current authenticated user (should exist since they're checking out)
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      // Handle case where user is not authenticated (should not happen at this point)
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('User not authenticated. Please sign in.'),
        ),
      );
    }

    // Initialize PayChangu SDK
    final paychangu = PayChangu(
      PayChanguConfig(
        secretKey: secretKey, // Use the passed secret key
        isTestMode: true,
      ),
    );

    // Create PaymentRequest with data fetched from database
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPaymentData(supabase, currentUser.id, orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Failed to load payment data: ${snapshot.error}'),
            ),
          );
        }

        final paymentData = snapshot.data!;

        // Check the exact type needed for currency - it might be an enum or string
        // Based on paychangu_flutter package
        final request = PaymentRequest(
          txRef: transactionReference,
          amount: paymentData['amount'] as int,
          currency: Currency.MWK,
          firstName: paymentData['first_name'] as String,
          lastName: paymentData['last_name'] as String,
          email: paymentData['email'] as String,
          callbackUrl:
              'https://xsflgrmqvnggtdggacrd.supabase.co/functions/v1/paychangu-webhook',
          returnUrl: 'https://dinetrack-3hhc.onrender.com/#/order-complete',
          meta: {
            'order_id': orderId,
            'checkout_url': checkoutUrl,
            'customer_id': currentUser.id,
            'establishment_id': paymentData['establishment_id'] as String,
          },
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Complete Payment'), elevation: 0),
          body: paychangu.launchPayment(
            request: request,
            onSuccess: (response) {
              debugPrint('Payment UI flow completed: $response');
              Navigator.pop(context);
              onSuccess();
            },
            onError: (error) {
              debugPrint('Payment failed: $error');
              Navigator.pop(context);
              onFailure(error.toString());
            },
            onCancel: () {
              debugPrint('Payment cancelled by user');
              Navigator.pop(context);
              onCancel();
            },
          ),
        );
      },
    );
  }
}
