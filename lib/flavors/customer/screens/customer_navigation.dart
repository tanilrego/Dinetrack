import 'package:flutter/material.dart';
import 'home_customer.dart';
import 'favorites_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../../../../core/widgets/paychangu_checkout.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CustomerNavigation extends StatefulWidget {
  final String establishmentId;
  final String? tableId;

  const CustomerNavigation({
    super.key,
    required this.establishmentId,
    this.tableId,
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
    _resolveTableId();
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

  // Resolve table ID - use provided tableId or get a default one
  Future<void> _resolveTableId() async {
    if (widget.tableId != null) {
      setState(() {
        _resolvedTableId = widget.tableId;
      });
    } else {
      final defaultTableId = await _getDefaultTableId();
      if (mounted) {
        setState(() {
          _resolvedTableId = defaultTableId;
        });
      }
    }
  }

  // Get default table ID for the establishment
  Future<String> _getDefaultTableId() async {
    try {
      final response = await _supabaseService.client
          .from('tables')
          .select()
          .eq('establishment_id', widget.establishmentId)
          .eq('is_available', true)
          .limit(1);

      if (response.isNotEmpty) {
        return response[0]['id'] as String;
      }
      return 'default-table-id';
    } catch (e) {
      debugPrint('Error getting default table ID: $e');
      return 'default-table-id';
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

        // Call PayChangu create edge function to get payment parameters
        final paymentResponse = await _supabaseService.client.functions.invoke(
          'paychangu-create',
          body: {
            'order_id': orderId,
            'tx_ref': txRef,
            'payer_customer_id': _supabaseService.client.auth.currentUser!.id,
            'amount': finalAmount,
            'return_url':
                'https://dinetrack-3hhc.onrender.com/#/restaurant/${widget.establishmentId}',
          },
        );

        if (paymentResponse.status != 200 || paymentResponse.data == null) {
          throw 'Failed to initiate payment';
        }

        final paymentData = paymentResponse.data;
        final checkoutUrl = paymentData['checkout_url'] as String? ?? '';

        // Save establishment ID to storage in case return URL hash is stripped
        if (kIsWeb) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'pending_payment_restaurant_id',
            widget.establishmentId,
          );
        }

        // Navigate to PayChangu payment screen
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PayChanguCheckout(
                checkoutUrl: checkoutUrl,
                onSuccess: () => _handlePaymentSuccess(orderId),
                onError: () => _handlePaymentFailure('Payment Error'),
                onCancel: () => _handlePaymentCancellation(),
              ),
            ),
          );
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
          .eq('id', orderId);

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
