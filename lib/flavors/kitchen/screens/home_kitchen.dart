import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dinetrack/landing_page.dart';
import '../../../../core/services/supabase_service.dart';
import 'add_menu_item_page.dart'; // We'll create this

class KitchenStaffScreen extends StatefulWidget {
  const KitchenStaffScreen({super.key});

  @override
  State<KitchenStaffScreen> createState() => _KitchenStaffScreenState();
}

class _KitchenStaffScreenState extends State<KitchenStaffScreen> {
  final supabase = SupabaseService().client;

  List<TableOrder> _kdsOrders = [];
  String _kdsFilter = 'Waiting'; // Waiting, Preparing, Ready
  bool isDarkMode = false;
  bool isLoading = true;
  int selectedMenuIndex = 0;
  String _currentEstablishmentId = '';
  String _kitchenStaffName = 'Kitchen Staff';
  String _kitchenStation = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadEstablishmentId().then((_) async {
      await _loadKDSOrders();
      _subscribeToKDS();
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _loadEstablishmentId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        print('DEBUG: Loading establishment for user: ${user.id}');

        // Load User details first
        final userDetails = await supabase
            .from('users')
            .select('full_name, profile_image_url')
            .eq('id', user.id)
            .maybeSingle();

        if (userDetails != null) {
          print('DEBUG: User details loaded: ${userDetails['full_name']}');
          setState(() {
            _kitchenStaffName = userDetails['full_name'] ?? 'Kitchen Staff';
            // For kitchen staff, we want the restaurant profile image potentially, or user profile.
            // User said: "on the profile it should use thee restaurant profile".
            // This implies if the user profile image is NOT set, use restaurant image? Or ALWAYS use restaurant image?
            // "on the profile it should use thee restaurant profile" -> likely means the establishment's logo.
            // But usually the top right is the USER.
            // Let's load user profile image first. If we want establishment image, we explicitly load it later.
            _profileImageUrl = userDetails['profile_image_url'];
          });
        }

        // Check kitchen_assignments table
        print('DEBUG: Checking kitchen_assignments table...');
        final kitchenData = await supabase
            .from('kitchen_assignments')
            .select('establishment_id, assigned_station')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();

        if (kitchenData != null) {
          final establishmentId = kitchenData['establishment_id'].toString();
          print(
            'DEBUG: Found kitchen assignment - Establishment ID: $establishmentId',
          );

          setState(() {
            _currentEstablishmentId = establishmentId;
            _kitchenStation = kitchenData['assigned_station'] ?? 'Kitchen';
          });

          // Fetch establishment image to use as profile image as requested
          final estData = await supabase
              .from('establishments')
              .select('image_url')
              .eq('id', establishmentId)
              .maybeSingle();
          if (estData != null && estData['image_url'] != null) {
            setState(() {
              _profileImageUrl = estData['image_url'];
            });
          }
        } else {
          // Fallback logic...
          final userData = await supabase
              .from('users')
              .select('user_type')
              .eq('id', user.id)
              .maybeSingle();

          if (userData != null && userData['user_type'] == 'kitchen') {
            final establishments = await supabase
                .from('establishments')
                .select('id, image_url')
                .limit(1);

            if (establishments.isNotEmpty) {
              final establishmentId = establishments[0]['id'].toString();
              setState(() {
                _currentEstablishmentId = establishmentId;
                if (establishments[0]['image_url'] != null) {
                  _profileImageUrl = establishments[0]['image_url'];
                }
              });
            }
          }
        }
      }
    } catch (e) {
      // print('Error loading establishment ID: $e');
    }
  }

  Future<void> _loadKDSOrders() async {
    if (_currentEstablishmentId.isEmpty) {
      print('DEBUG KDS: Establishment ID is empty, cannot load orders');
      return;
    }

    try {
      print(
        'DEBUG KDS: Loading orders for establishment: $_currentEstablishmentId',
      );

      // First, let's see ALL orders for this establishment (no filters)
      final allOrdersResponse = await supabase
          .from('orders')
          .select('id, status, payment_status, establishment_id, created_at')
          .eq('establishment_id', _currentEstablishmentId);

      print(
        'DEBUG KDS: Total orders in DB for this establishment: ${allOrdersResponse.length}',
      );
      if (allOrdersResponse.isNotEmpty) {
        for (var order in allOrdersResponse) {
          print(
            '  - Order: ${order['id']}, status="${order['status']}", payment_status="${order['payment_status']}", created=${order['created_at']}',
          );
        }
      }

      // Now load with filters
      final response = await supabase
          .from('orders')
          .select('*, order_items(*, menu_items(*))')
          .eq('establishment_id', _currentEstablishmentId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .neq('status', 'served') // Assuming served is history
          .order('created_at', ascending: true);

      print('DEBUG KDS: Found ${response.length} orders after filtering');
      if (response.isNotEmpty) {
        for (var order in response) {
          print(
            '  - Filtered Order ID: ${order['id']}, Status: ${order['status']}, Payment Status: ${order['payment_status']}',
          );
        }
      }

      setState(() {
        _kdsOrders = (response as List)
            .map((json) => TableOrder.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('ERROR loading KDS orders: $e');
    }
  }

  void _subscribeToKDS() {
    supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            // print('KDS Update Recieved: ${payload.eventType}');
            _loadKDSOrders();
          },
        )
        .subscribe();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    print('DEBUG: Attempting to update order $orderId to status: $newStatus');
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      print('DEBUG: Successfully updated order $orderId to $newStatus');

      // Force reload to ensure UI updates immediately
      await _loadKDSOrders();
    } catch (e) {
      print('ERROR: Failed to update order status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        // Explicitly navigate to LandingPage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(child: _buildMainContent()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMainContent() {
    switch (selectedMenuIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildClosedOrdersView();
      case 2:
        return _buildShoppingCartView();
      case 3:
        if (_currentEstablishmentId.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading establishment data...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          );
        }
        return AddMenuItemPage(
          establishmentId: _currentEstablishmentId,
          isDarkMode: isDarkMode,
          onMenuItemAdded: () {
            // Refresh or show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Menu item added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      case 4:
        return _buildSettingsView();
      case 5:
        return _buildAssistanceView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    // Filter orders based on _kdsFilter
    List<TableOrder> filteredOrders = _kdsOrders.where((order) {
      if (_kdsFilter == 'Waiting') {
        // Note: 'paid' is a payment_status, not a status
        return order.status == 'pending' || order.status == 'confirmed';
      } else if (_kdsFilter == 'Preparing') {
        return order.status == 'preparing';
      } else if (_kdsFilter == 'Ready') {
        return order.status == 'ready';
      }
      return true;
    }).toList();

    return Column(
      children: [
        // KDS Header & Filters
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kitchen Display System',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Row(
                children: [
                  _buildFilterButton('Waiting', Colors.orange),
                  const SizedBox(width: 12),
                  _buildFilterButton('Preparing', Colors.blue),
                  const SizedBox(width: 12),
                  _buildFilterButton('Ready', Colors.green),
                ],
              ),
            ],
          ),
        ),

        // Orders Grid
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.kitchen,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No orders in $_kdsFilter',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio:
                        0.85, // Increased from 0.75 for smaller cards
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(filteredOrders[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String filter, Color color) {
    bool isSelected = _kdsFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _kdsFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(TableOrder order) {
    Color statusColor;
    String nextStatus;
    String actionLabel;
    IconData actionIcon;

    switch (order.status) {
      case 'pending':
      case 'confirmed':
        statusColor = Colors.orange;
        nextStatus = 'preparing';
        actionLabel = 'Start Preparing';
        actionIcon = Icons.soup_kitchen;
        break;
      case 'preparing':
        statusColor = Colors.blue;
        nextStatus = 'ready';
        actionLabel = 'Mark Ready';
        actionIcon = Icons.check_circle;
        break;
      case 'ready':
        statusColor = Colors.green;
        nextStatus = 'served'; // Or completed
        actionLabel = 'Served';
        actionIcon = Icons.done_all;
        break;
      default:
        statusColor = Colors.grey;
        nextStatus = 'completed';
        actionLabel = 'Complete';
        actionIcon = Icons.check;
    }

    // Time elapsed
    final elapsed = DateTime.now().difference(order.createdAt);
    final elapsedStr = '${elapsed.inMinutes}m';

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table ${order.tableNumber ?? "?"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '#${order.orderNumber ?? "?"}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        elapsedStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: order.items.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty)
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.price != null)
                            Text(
                              'MWK ${item.price!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.greenAccent
                                    : Colors.green.shade700,
                              ),
                            ),
                          if (item.modification != null &&
                              item.modification!.isNotEmpty)
                            Text(
                              item.modification!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(order.id, nextStatus),
                icon: Icon(actionIcon),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedOrdersView() {
    return FutureBuilder<List<dynamic>>(
      future: _loadClosedOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading closed orders: ${snapshot.error}',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          );
        }

        final closedOrders = snapshot.data ?? [];

        if (closedOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: isDarkMode ? Colors.white : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Closed Orders',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No closed orders available',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: closedOrders.length,
          itemBuilder: (context, index) {
            return _buildClosedOrderCard(
              TableOrder.fromJson(closedOrders[index]),
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _loadClosedOrders() async {
    if (_currentEstablishmentId.isEmpty) return [];

    try {
      final response = await supabase
          .from('orders')
          .select('*, order_items(*, menu_items(*))')
          .eq('establishment_id', _currentEstablishmentId)
          .or('status.eq.served,status.eq.completed')
          .order('updated_at', ascending: false)
          .limit(20); // Show last 20 closed orders

      return response as List;
    } catch (e) {
      print('Error loading closed orders: $e');
      return [];
    }
  }

  Widget _buildClosedOrderCard(TableOrder order) {
    final completedTime = DateTime.now().difference(order.createdAt);
    final completedStr = '${completedTime.inMinutes}m ago';

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table ${order.tableNumber ?? "?"}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '#${order.orderNumber ?? "?"}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        completedStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: order.items.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingCartView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: isDarkMode ? Colors.white : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Shopping Cart',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No items in cart',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 80,
            color: isDarkMode ? Colors.white : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your preferences',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 40),
          _buildSidebarIcon(Icons.dashboard, 0, 'Dashboard'),
          _buildSidebarIcon(Icons.close, 1, 'Closed Orders'),
          _buildSidebarIcon(Icons.shopping_cart, 2, 'Shopping'),
          _buildSidebarIcon(Icons.receipt, 3, 'Add Menu Item'),
          _buildSidebarIcon(Icons.notifications_active, 5, 'Assistance'),
          const Spacer(),
          // Replaced Settings with Logout as requested ("place the logout where theres settings icon")
          GestureDetector(
            onTap: _signOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 24),
              ),
            ),
          ),
          // _buildSidebarIcon(Icons.settings, 4, 'Settings'),  <-- Removed Settings from sidebar
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebarIcon(IconData icon, int index, String tooltip) {
    bool isActive = selectedMenuIndex == index;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedMenuIndex = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  // ... rest of your existing methods (_buildLogo, _buildTopBar, _buildCustomersTable, _buildCustomerRow)
  // Keep all your existing methods from the original code
  Widget _buildLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search anything',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  onPressed: () => setState(() => isDarkMode = !isDarkMode),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _kitchenStaffName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                _kitchenStation.isNotEmpty
                    ? '($_kitchenStation)'
                    : '(Kitchen Staff)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAssistanceView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('assist_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter for open requests for current establishment
        final requests = snapshot.data!.where((req) {
          return req['establishment_id'].toString() ==
                  _currentEstablishmentId &&
              req['status'] == 'open';
        }).toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active assistance requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assistance Requests',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final tableId = req['table_id'] ?? 'Unknown';
                    // You might want to fetch table number using tableId if needed
                    // For now, displaying ID or name if available
                    final time = DateTime.parse(req['created_at']).toLocal();
                    final timeString =
                        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";

                    return Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.priority_high, color: Colors.white),
                        ),
                        title: Text(
                          'Table $tableId needs assistance',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text('Requested at $timeString'),
                        trailing: ElevatedButton.icon(
                          onPressed: () async {
                            // Mark as resolved
                            await supabase
                                .from('assist_requests')
                                .update({'status': 'resolved'})
                                .eq('id', req['id']);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request marked as resolved'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Resolve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// KDS Models
class TableOrder {
  final String id;
  final int? tableNumber;
  final int? orderNumber;
  final String status;
  final List<OrderItem> items;
  final DateTime createdAt;

  TableOrder({
    required this.id,
    this.tableNumber,
    this.orderNumber,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory TableOrder.fromJson(Map<String, dynamic> json) {
    print('DEBUG TableOrder.fromJson: ${json.keys}');
    print('  table_no: ${json['table_no']}');
    print('  order_number: ${json['order_number']}');
    print('  order_items: ${json['order_items']}');

    return TableOrder(
      id: json['id'],
      tableNumber:
          json['table_no'], // Changed from table_number to table_no based on Schema
      orderNumber: json['order_number'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      items:
          (json['order_items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class OrderItem {
  final String id;
  final String name;
  final String? description;
  final double? price;
  final String? modification;
  final bool isCompleted;

  OrderItem({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.modification,
    this.isCompleted = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    print('DEBUG OrderItem.fromJson called');
    // We need to handle the case where menu_item is joined
    final menuItem = json['menu_items']; // Assuming join
    final name = menuItem != null ? menuItem['name'] : 'Unknown Item';
    final description = menuItem != null ? menuItem['description'] : null;
    final price = menuItem != null
        ? (menuItem['price'] as num?)?.toDouble()
        : null;

    return OrderItem(
      id: json['id'],
      name: name,
      description: description,
      price: price,
      modification: json['special_instructions'],
      isCompleted: false, // Default to false since DB doesn't have it
    );
  }
}
