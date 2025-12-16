import 'package:flutter/material.dart';
import 'home_customer.dart';
import 'favorites_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'paychangu_payment_screen.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';
import 'package:flutter/foundation.dart';
// Conditional import: use stub on web, real package on mobile
import 'paychangu_mobile.dart' if (dart.library.html) 'paychangu_web.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/reservation_dialog.dart';
import '../../../../core/services/auth_service.dart';

class CustomerNavigation extends StatefulWidget {
  final String establishmentId;
  final String? initialTableNumber;

  const CustomerNavigation({
    super.key,
    required this.establishmentId,
    this.initialTableNumber,
  });

  @override
  State<CustomerNavigation> createState() => _CustomerNavigationState();
}

class _CustomerNavigationState extends State<CustomerNavigation> {
  int _currentIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();
  String? _resolvedTableId;

  // Cart state management
  final Map<String, CartItem> _cartItems = {};
  double _cartTotal = 0.0;

  int get _cartItemCount =>
      _cartItems.values.fold(0, (count, item) => count + item.quantity);

  @override
  void initState() {
    super.initState();
    // Use passed table number if available to find ID
    if (widget.initialTableNumber != null) {
      _resolveInitialTableNumber();
    }

    _calculateCartTotal();
    // If not passed (Manual), we do NOT prompt yet. We prompt at checkout.

    _calculateCartTotal();

    // Check for payment return success (Web Redirect)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Simple check: if current URL has 'tx_ref', show success message.
        // In a real app, you'd verify this ref with the backend.
        final uri = Uri.base;
        if (uri.queryParameters.containsKey('tx_ref') ||
            uri.queryParameters.containsKey('status')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
          // Optional: clear query params to avoid showing message on refresh?
          // Hard to do without reloading on web, but this is sufficient for user feedback.
        }
      });
    }

    // Check for pending reservation action
    if (AuthService.pendingReservationAction) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthService.pendingReservationAction = false;
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ReservationDialog(
              establishmentId: widget.establishmentId,
              establishmentName: 'Restaurant', // Placeholder
            ),
          );
        }
      });
    }
  }

  // Calculate cart total
  void _calculateCartTotal() {
    setState(() {
      _cartTotal = _cartItems.values.fold(
        0,
        (total, item) => total + (item.menuItem.price * item.quantity),
      );
    });
  }

  Future<void> _resolveInitialTableNumber() async {
    if (widget.initialTableNumber == null) return;

    try {
      // Clean parsing
      final tableNumStr = widget.initialTableNumber!.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      if (tableNumStr.isEmpty) return;

      final tableNum = int.parse(tableNumStr);

      final data = await _supabaseService.client
          .from('tables')
          .select('id')
          .eq('establishment_id', widget.establishmentId)
          .eq('table_number', tableNum)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          _resolvedTableId = data['id'];
        });
        print(
          'DEBUG: Context resolved table number $tableNum to UUID: $_resolvedTableId',
        );
      }
    } catch (e) {
      print('DEBUG: Failed to resolve initial table context: $e');
    }
  }

  // Previously _resolveTableId was called in initState. We removed that.
  // We keep the method for manual invocation at checkout.
  // Previously _resolveTableId was called in initState. We removed that.
  // We keep the method for manual invocation at checkout.
  Future<void> _resolveTableId() async {
    if (_resolvedTableId != null) return;

    // If table ID is not passed (e.g. manual browsing), prompt user to select a table
    // Delay slightly to allow build
    if (mounted) {
      await _showTableSelectionDialog();
    }
  }

  Future<void> _showTableSelectionDialog() async {
    List<dynamic> tables = [];
    try {
      tables = await _supabaseService.client
          .from('tables')
          .select('id, table_number')
          .eq('establishment_id', widget.establishmentId)
          .eq('is_available', true)
          .order('table_number');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching tables: $e')));
      return;
    }

    if (!mounted) return;

    if (tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tables currently available')),
      );
      return;
    }

    String? selectedId = tables[0]['id'] as String;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Table'),
              content: DropdownButton<String>(
                value: selectedId,
                isExpanded: true,
                items: tables.map<DropdownMenuItem<String>>((t) {
                  return DropdownMenuItem(
                    value: t['id'],
                    child: Text('Table ${t['table_number']}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() => selectedId = val);
                },
              ),
              actions: [
                ElevatedButton(
                  onPressed: selectedId == null
                      ? null
                      : () async {
                          final rpcResponse = await _supabaseService.client.rpc(
                            'select_table',
                            params: {'p_table_id': selectedId!},
                          );

                          print('RPC response: $rpcResponse');

                          if (rpcResponse == true) {
                            Navigator.pop(context);
                            setState(() {
                              _resolvedTableId = selectedId;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'That table was just taken. Please choose another.',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedId != null) {
      setState(() {
        _resolvedTableId = selectedId;
      });
    }
  }

  // Add to cart functionality
  void _addToCart(
    MenuItem menuItem, {
    int quantity = 1,
    String? specialInstructions,
  }) {
    setState(() {
      if (_cartItems.containsKey(menuItem.id)) {
        _cartItems[menuItem.id] = CartItem(
          menuItem: menuItem,
          quantity: _cartItems[menuItem.id]!.quantity + quantity,
          specialInstructions:
              specialInstructions ??
              _cartItems[menuItem.id]!.specialInstructions,
        );
      } else {
        _cartItems[menuItem.id] = CartItem(
          menuItem: menuItem,
          quantity: quantity,
          specialInstructions: specialInstructions,
        );
      }
      _calculateCartTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menuItem.name} added to cart'),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Update cart item quantity
  void _updateCartQuantity(String menuItemId, int newQuantity) {
    debugPrint(
      'DEBUG: Updating quantity for $menuItemId from ${_cartItems[menuItemId]?.quantity} to $newQuantity',
    );
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.remove(menuItemId);
        debugPrint('DEBUG: Removed item $menuItemId from cart');
      } else {
        _cartItems[menuItemId] = CartItem(
          menuItem: _cartItems[menuItemId]!.menuItem,
          quantity: newQuantity,
          specialInstructions: _cartItems[menuItemId]!.specialInstructions,
        );
        debugPrint(
          'DEBUG: Updated item $menuItemId quantity to ${_cartItems[menuItemId]!.quantity}',
        );
      }
      _calculateCartTotal();
    });
    debugPrint(
      'DEBUG: Cart now has ${_cartItems.length} items, total: $_cartTotal',
    );
  }

  // Remove from cart
  void _removeFromCart(String menuItemId) {
    setState(() {
      _cartItems.remove(menuItemId);
      _calculateCartTotal();
    });
  }

  // Clear entire cart
  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _cartTotal = 0.0;
    });
  }

  // Enhanced checkout method with PayChangu support
  Future<void> _checkout({
    String paymentMethod = 'cash',
    double dineCoinsUsed = 0.0,
  }) async {
    if (_resolvedTableId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine table. Please scan QR code again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your cart is empty.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Calculate final amount after DineCoins deduction
      final finalAmount = paymentMethod == 'dine_coins'
          ? _cartTotal - dineCoinsUsed
          : _cartTotal;

      // 0. Get table number from tables table
      int? tableNumber;
      if (_resolvedTableId != null) {
        try {
          final tableData = await _supabaseService.client
              .from('tables')
              .select('table_number')
              .eq('id', _resolvedTableId!)
              .maybeSingle();

          tableNumber = tableData?['table_number'];
          print(
            'DEBUG: Fetched table_number: $tableNumber for table_id: $_resolvedTableId',
          );
        } catch (e) {
          print('DEBUG: Could not fetch table number: $e');
        }
      }

      // 1. Create the order
      final orderResponse = await _supabaseService.client
          .from('orders')
          .insert({
            'establishment_id': widget.establishmentId,
            'table_id': _resolvedTableId,
            'customer_id': _supabaseService.client.auth.currentUser?.id,
            'status': 'pending',
            'total_amount': _cartTotal, // Original total
            'special_instructions': _getSpecialInstructions(),
            'table_no': tableNumber, // Supabase handles null values
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // 2. Create order items
      final orderItems = _cartItems.entries.map((entry) {
        final cartItem = entry.value;
        return {
          'order_id': orderId,
          'menu_item_id': cartItem.menuItem.id,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.menuItem.price,
          'line_total': cartItem.quantity * cartItem.menuItem.price,
          'special_instructions': cartItem.specialInstructions,
        };
      }).toList();

      await _supabaseService.client.from('order_items').insert(orderItems);

      // Handle PayChangu payment flow
      if (paymentMethod == 'paychangu') {
        // Generate unique transaction reference
        final txRef =
            'dinetrack-$orderId-${DateTime.now().millisecondsSinceEpoch}';

        try {
          // Get customer details for payment
          final userId = _supabaseService.client.auth.currentUser?.id;
          if (userId == null) throw 'User not authenticated';

          final customerData = await _supabaseService.client
              .from('users')
              .select('full_name, email, phone')
              .eq('id', userId)
              .single();

          String paymentEmail =
              customerData['email'] ?? '$userId@dinetrack.com';
          String paymentPhone = customerData['phone'] ?? '';

          // Parse customer name
          final fullNameStr =
              customerData['full_name'] as String? ?? 'Customer';
          final nameParts = fullNameStr.split(' ');
          final firstName = nameParts.isNotEmpty ? nameParts[0] : 'Customer';
          final lastName = nameParts.length > 1
              ? nameParts.sublist(1).join(' ')
              : 'Name';

          // CHECK IF GUEST OR MISSING PHONE
          // Guest email check: contains 'guest' and 'dinetrack.com' or just check if it matches the generated guest email pattern
          bool isGuest =
              paymentEmail.contains('guest') ||
              paymentEmail.endsWith('@dinetrack.com');
          bool missingPhone = paymentPhone.isEmpty;

          if (isGuest || missingPhone) {
            // Prompt for details
            if (mounted) {
              final result = await showDialog<Map<String, String>>(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  final emailController = TextEditingController(
                    text: isGuest ? '' : paymentEmail,
                  );
                  final phoneController = TextEditingController(
                    text: paymentPhone,
                  );
                  final formKey = GlobalKey<FormState>();

                  return AlertDialog(
                    title: const Text('Contact Details Required'),
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Mobile money payment requires a valid phone number and email.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: 'e.g., 0991234567',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!value.contains('@')) {
                                return 'Invalid email address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context), // Cancel -> returns null
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'email': emailController.text.trim(),
                              'phone': phoneController.text.trim(),
                            });
                          }
                        },
                        child: const Text('Continue'),
                      ),
                    ],
                  );
                },
              );

              if (result == null) {
                // User cancelled the dialog
                throw 'Payment cancelled: Contact details required';
              }

              paymentEmail = result['email']!;
              paymentPhone = result['phone']!;
            }
          }

          // PLATFORM CHECK
          final isDesktop =
              !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux ||
                  defaultTargetPlatform == TargetPlatform.macOS);

          if (isDesktop) {
            // --- DESKTOP FLOW ---
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Initializing Payment...')),
              );
            }

            // 1. Invoke Edge Function to get Checkout URL
            final res = await _supabaseService.client.functions.invoke(
              'create-paychangu-payment',
              body: {
                'order_id': orderId,
                'payer_customer_id': userId,
                // 'payment_method': 'mobile_money', // Default in edge function
                'phone_number': paymentPhone, // Use provided phone
                'email':
                    paymentEmail, // Pass email if supported by edge function
                'return_url': kIsWeb ? Uri.base.toString() : null,
              },
            );

            if (res.status != 200) {
              throw 'Payment initialization failed: ${res.status} ${res.data}';
            }

            final data = res.data;
            if (data == null || data['checkout_url'] == null) {
              throw 'Invalid response from payment server';
            }

            final checkoutUrl = data['checkout_url'] as String;
            final uri = Uri.parse(checkoutUrl);

            // 2. Launch URL
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);

              if (mounted) {
                // 3. Show Dialog & Listen for Realtime Update
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Payment in Progress'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Please complete the payment in the browser window that just opened.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _handlePaymentCancellation();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    );
                  },
                );

                // Subscribe to order status changes
                final channel = _supabaseService.client.channel(
                  'public:orders:$orderId',
                );
                channel
                    .onPostgresChanges(
                      event: PostgresChangeEvent.update,
                      schema: 'public',
                      table: 'orders',
                      filter: PostgresChangeFilter(
                        type: PostgresChangeFilterType.eq,
                        column: 'id',
                        value: orderId,
                      ),
                      callback: (payload) {
                        final newStatus = payload.newRecord['payment_status'];
                        debugPrint('RT: Order status updated to $newStatus');
                        if (newStatus == 'paid') {
                          // Close the dialog if it's still open
                          Navigator.of(context, rootNavigator: true).pop();
                          _handlePaymentSuccess(orderId);
                          _supabaseService.client.removeChannel(channel);
                        } else if (newStatus == 'failed') {
                          Navigator.of(context, rootNavigator: true).pop();
                          _handlePaymentFailure('Payment marked as failed');
                          _supabaseService.client.removeChannel(channel);
                        }
                      },
                    )
                    .subscribe();
              }
            } else {
              throw 'Could not launch payment URL';
            }
          } else if (kIsWeb) {
            // --- WEB FLOW: Navigate to PaychanguInlinePaymentScreen ---
            // Update user details temporarily for this session if needed?
            // The PayChanguInlinePaymentScreen might re-fetch user details.
            // We should pass the phone/email to it.

            // Updating the screen to accept phone/email override would be best,
            // but for now let's pass it via arguments if possible, or update the DB temporarily?
            // User requested NOT to save in DB.
            // But PaychanguInlinePaymentScreen fetches data itself.
            // Solution: We need to modify PaychanguInlinePaymentScreen to accept `email` and `phone` overrides.

            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaychanguInlinePaymentScreen(
                    checkoutUrl: '', // Will be fetched inside the screen
                    transactionReference: txRef,
                    orderId: orderId,
                    secretKey: 'SEC-TEST-awHuCpW5cLHMeMSCf9Swix4qo6qj9mXH',
                    // Pass the captured details
                    customerEmail: paymentEmail,
                    customerPhone: paymentPhone,
                    onSuccess: () {
                      _handlePaymentSuccess(orderId);
                    },
                    onFailure: (error) {
                      _handlePaymentFailure(error);
                    },
                    onCancel: () {
                      _handlePaymentCancellation();
                    },
                  ),
                ),
              );
            }
          } else {
            // --- MOBILE ONLY: Use PayChangu SDK ---
            // Initialize PayChangu SDK
            final paychangu = PayChangu(
              PayChanguConfig(
                secretKey:
                    'SEC-TEST-awHuCpW5cLHMeMSCf9Swix4qo6qj9mXH', // TODO: Move to env
                isTestMode: true,
              ),
            );

            // Create payment request
            final request = PaymentRequest(
              txRef: txRef,
              amount: (finalAmount * 100).round(), // Convert to cents
              currency: Currency.MWK,
              firstName: firstName,
              lastName: lastName,
              email: paymentEmail, // Use captured email
              callbackUrl:
                  'https://xsflgrmqvnggtdggacrd.supabase.co/functions/v1/paychangu-webhook',
              returnUrl:
                  'https://dinetrack-3hhc.onrender.com/#/restaurant/${widget.establishmentId}',
              meta: {
                'order_id': orderId,
                'customer_id': userId,
                'establishment_id': widget.establishmentId,
              },
            );

            // Create payment record in database before launching payment
            await _supabaseService.client.from('payments').insert({
              'order_id': orderId,
              'amount': finalAmount,
              'payment_method': 'paychangu',
              'status': 'pending',
              'idempotency_key': txRef,
              'payer_customer_id': userId,
              'metadata': {
                'tx_ref': txRef,
                'email': paymentEmail, // Store in metadata for reference
                'phone': paymentPhone,
                'created_at': DateTime.now().toIso8601String(),
              },
            });

            // Launch PayChangu payment UI
            if (mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Complete Payment'),
                      elevation: 0,
                    ),
                    body: paychangu.launchPayment(
                      request: request,
                      onSuccess: (response) {
                        debugPrint('Payment UI flow completed: $response');
                        Navigator.pop(context);
                        _handlePaymentSuccess(orderId);
                      },
                      onError: (error) {
                        debugPrint('Payment failed: $error');
                        Navigator.pop(context);
                        _handlePaymentFailure(error.toString());
                      },
                      onCancel: () {
                        debugPrint('Payment cancelled by user');
                        Navigator.pop(context);
                        _handlePaymentCancellation();
                      },
                    ),
                  ),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to initialize payment: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          debugPrint('PayChangu initialization error: $e');
        }
        return; // Exit early for PayChangu - callbacks will handle the rest
      }

      // 3. Create payment record (for non-PayChangu methods)
      await _supabaseService.client.from('payments').insert({
        'order_id': orderId,
        'amount': finalAmount > 0
            ? finalAmount
            : 0, // Handle full DineCoins payment
        'payment_method': paymentMethod,
        'dine_coins_used': dineCoinsUsed,
        'status': paymentMethod == 'dine_coins' && finalAmount <= 0
            ? 'completed'
            : 'pending',
      });

      // 4. If DineCoins were used, update ledger
      if (paymentMethod == 'dine_coins' && dineCoinsUsed > 0) {
        await _supabaseService.client.from('dinecoins_ledger').insert({
          'user_id': _supabaseService.client.auth.currentUser?.id,
          'establishment_id': widget.establishmentId,
          'amount': dineCoinsUsed,
          'transaction_type': 'debit',
          'description': 'Payment for order $orderId',
        });
      }

      // 5. Clear cart and show success
      if (mounted) {
        _clearCart();

        // 6. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${orderId.substring(0, 8)} placed successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      debugPrint('Checkout completed for table: $_resolvedTableId');
      debugPrint('Order ID: $orderId');
      debugPrint('Payment method: $paymentMethod');
      debugPrint('DineCoins used: $dineCoinsUsed');
      debugPrint('Final amount: $finalAmount');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Checkout error: $e');
    }
  }

  // Payment success handler
  Future<void> _handlePaymentSuccess(String orderId) async {
    try {
      // Update order status in database
      await _supabaseService.client
          .from('orders')
          .update({
            'payment_status': 'paid',
            'status': 'confirmed', // Assuming paid means confirmed
          })
          .eq('id', orderId)
          .select();

      debugPrint('DEBUG: Updated order $orderId payment_status to paid');
    } catch (e) {
      debugPrint('ERROR: Failed to update payment status for $orderId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment recorded but status update failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      _clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful! Order #${orderId.substring(0, 8)}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Payment failure handler
  void _handlePaymentFailure(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    debugPrint('Payment failed: $error');
  }

  // Payment cancellation handler
  void _handlePaymentCancellation() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    debugPrint('Payment cancelled by user');
  }

  // Helper method to get special instructions from cart items
  String? _getSpecialInstructions() {
    // Collect all special instructions from cart items
    final instructions = _cartItems.values
        .where(
          (item) =>
              item.specialInstructions != null &&
              item.specialInstructions!.isNotEmpty,
        )
        .map((item) => '${item.menuItem.name}: ${item.specialInstructions}')
        .join('\n');

    return instructions.isNotEmpty ? instructions : null;
  }

  // Get user's DineCoins balance
  Future<double> _getDineCoinsBalance() async {
    try {
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) return 0.0;

      final response = await _supabaseService.client
          .from('dinecoins_ledger')
          .select()
          .eq('user_id', userId);

      double balance = 0.0;
      for (final record in response) {
        final amount = (record['amount'] as num).toDouble();
        final type = record['transaction_type'] as String;
        if (type == 'credit') {
          balance += amount;
        } else if (type == 'debit') {
          balance -= amount;
        }
      }
      return balance;
    } catch (e) {
      debugPrint('Error getting DineCoins balance: $e');
      return 0.0;
    }
  }

  // Handle checkout process with enhanced confirmation dialog
  void _handleCheckout() async {
    // Ensure we have a table ID before proceeding
    if (_resolvedTableId == null) {
      await _resolveTableId();
      if (!mounted) return; // Check if widget is still mounted
    }

    if (_cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your cart is empty.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Get DineCoins balance for payment options
    final dineCoinsBalance = await _getDineCoinsBalance();
    if (!mounted) return; // Check if widget is still mounted

    final canUseDineCoins = dineCoinsBalance > 0;

    // Show enhanced confirmation dialog with payment options
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => CheckoutDialog(
          tableId: _resolvedTableId,
          cartItems: _cartItems,
          cartTotal: _cartTotal,
          dineCoinsBalance: dineCoinsBalance,
          canUseDineCoins: canUseDineCoins,
          onCheckout: _checkout,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeCustomer(
        establishmentId: widget.establishmentId,
        tableId: _resolvedTableId,
        onAddToCart: _addToCart,
        cartItemCount: _cartItemCount,
        cartItems: _cartItems,
        onUpdateQuantity: _updateCartQuantity,
        onRemoveFromCart: _removeFromCart,
        onClearCart: _clearCart,
        cartTotal: _cartTotal,
        onCheckout: _handleCheckout,
      ),
      FavoritesScreen(onAddToCart: _addToCart),
      CartScreen(
        establishmentId: widget.establishmentId,
        cartItems: _cartItems,
        onUpdateQuantity: _updateCartQuantity,
        onRemoveFromCart: _removeFromCart,
        onClearCart: _clearCart,
        cartTotal: _cartTotal,
        onCheckout: _handleCheckout,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF4F46E5),
          unselectedItemColor: const Color(0xFF7C7C7C),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          backgroundColor: Colors.white,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (_cartItemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _cartItemCount > 9 ? '9+' : _cartItemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                children: [
                  const Icon(Icons.shopping_cart),
                  if (_cartItemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _cartItemCount > 9 ? '9+' : _cartItemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Checkout Dialog with payment options
class CheckoutDialog extends StatefulWidget {
  final String? tableId;
  final Map<String, CartItem> cartItems;
  final double cartTotal;
  final double dineCoinsBalance;
  final bool canUseDineCoins;
  final Function({String paymentMethod, double dineCoinsUsed}) onCheckout;

  const CheckoutDialog({
    super.key,
    required this.tableId,
    required this.cartItems,
    required this.cartTotal,
    required this.dineCoinsBalance,
    required this.canUseDineCoins,
    required this.onCheckout,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _selectedPaymentMethod = 'paychangu';
  double _dineCoinsUsed = 0.0;
  final TextEditingController _dineCoinsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set initial DineCoins usage to balance or total, whichever is smaller
    _dineCoinsUsed = widget.dineCoinsBalance > widget.cartTotal
        ? widget.cartTotal
        : widget.dineCoinsBalance;
    _dineCoinsController.text = _dineCoinsUsed.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _dineCoinsController.dispose();
    super.dispose();
  }

  void _updateDineCoinsUsed(String value) {
    final newValue = double.tryParse(value) ?? 0.0;
    setState(() {
      _dineCoinsUsed = newValue.clamp(
        0.0,
        widget.dineCoinsBalance > widget.cartTotal
            ? widget.cartTotal
            : widget.dineCoinsBalance,
      );
    });
  }

  double get _finalAmount {
    return _selectedPaymentMethod == 'dine_coins'
        ? widget.cartTotal - _dineCoinsUsed
        : widget.cartTotal;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Table: ${widget.tableId ?? 'Not specified'}'),
            const SizedBox(height: 8),
            Text('Items: ${widget.cartItems.length}'),
            const SizedBox(height: 8),
            Text('Total: ${widget.cartTotal.toStringAsFixed(0)} MWK'),

            const SizedBox(height: 16),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'paychangu',
                  label: Text('PayChangu'),
                  icon: Icon(Icons.credit_card),
                ),
                ButtonSegment<String>(
                  value: 'dine_coins',
                  label: Text('DineCoins'),
                  icon: Icon(Icons.account_balance_wallet),
                ),
              ],
              selected: {_selectedPaymentMethod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedPaymentMethod = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                selectedBackgroundColor: const Color(0xFF4F46E5),
                selectedForegroundColor: Colors.white,
              ),
            ),

            if (_selectedPaymentMethod == 'dine_coins') ...[
              const SizedBox(height: 16),
              Text(
                'Available DineCoins: ${widget.dineCoinsBalance.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dineCoinsController,
                decoration: const InputDecoration(
                  labelText: 'DineCoins to use',
                  border: OutlineInputBorder(),
                  hintText: 'Enter amount',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                keyboardType: TextInputType.number,
                onChanged: _updateDineCoinsUsed,
              ),
              const SizedBox(height: 8),
              if (_dineCoinsUsed > widget.dineCoinsBalance)
                Text(
                  'Not enough DineCoins. You have ${widget.dineCoinsBalance.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.red),
                ),
            ],

            if (_selectedPaymentMethod == 'dine_coins' &&
                _dineCoinsUsed > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF53B175).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Final Amount to Pay:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_finalAmount.toStringAsFixed(0)} MWK',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF53B175),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to place this order?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onCheckout(
              paymentMethod: _selectedPaymentMethod,
              dineCoinsUsed: _dineCoinsUsed,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF53B175),
            foregroundColor: Colors.white,
          ),
          child: const Text('Place Order'),
        ),
      ],
    );
  }
}
