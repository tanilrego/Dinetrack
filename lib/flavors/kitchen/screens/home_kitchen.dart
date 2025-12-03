import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import 'add_menu_item_page.dart'; // We'll create this

class KitchenStaffScreen extends StatefulWidget {
  const KitchenStaffScreen({super.key});

  @override
  State<KitchenStaffScreen> createState() => _KitchenStaffScreenState();
}

class _KitchenStaffScreenState extends State<KitchenStaffScreen> {
  final supabase = SupabaseService().client;
  final SupabaseService _supabaseService = SupabaseService();


  List<Map<String, dynamic>> checkedInCustomers = [];
  bool isDarkMode = false;
  bool isLoading = true;
  int selectedMenuIndex = 0;
  String _currentEstablishmentId = '';

  @override
  void initState() {
    super.initState();
    _loadEstablishmentId();
    _loadCheckedInCustomers();
  }


  Future<void> _loadEstablishmentId() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        print('Current auth user: ${user.id}');

        // Check kitchen_assignments table
        final kitchenData = await supabase
            .from('kitchen_assignments')
            .select('establishment_id')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();

        if (kitchenData != null) {
          final establishmentId = kitchenData['establishment_id'].toString();
          print('Found kitchen assignment. Establishment ID: $establishmentId');

          setState(() {
            _currentEstablishmentId = establishmentId;
          });
        } else {
          print('No kitchen assignment found for user: ${user.id}');
          print('Checking users table for user type...');

          // Check user type in users table
          final userData = await supabase
              .from('users')
              .select('user_type')
              .eq('id', user.id)
              .maybeSingle();

          if (userData != null && userData['user_type'] == 'kitchen') {
            print('User is kitchen staff but not assigned. Using first establishment.');

            // Get first establishment
            final establishments = await supabase
                .from('establishments')
                .select('id')
                .limit(1);

            if (establishments.isNotEmpty) {
              final establishmentId = establishments[0]['id'].toString();
              print('Using establishment: $establishmentId');

              setState(() {
                _currentEstablishmentId = establishmentId;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading establishment ID: $e');
    }
  }

  Future<void> _loadCheckedInCustomers() async {
    setState(() => isLoading = true);

    try {
      // Load checked-in customers with their orders
      final customersData = await supabase
          .from('customer_orders')
          .select('customer_name, table_number, address, status')
          .eq('checked_in', true)
          .order('created_at', ascending: false);

      checkedInCustomers = List<Map<String, dynamic>>.from(customersData as List);
    } catch (e) {
      print('Error loading customers: $e');
      // Mock data for testing
      checkedInCustomers = [
        {
          'customer_name': 'Kumbu Ali',
          'table_number': '5',
          'address': null,
          'status': 'Ordered'
        },
        {
          'customer_name': 'Guest',
          'table_number': '1',
          'address': null,
          'status': 'preparing'
        },
        {
          'customer_name': 'Dop Jaz',
          'table_number': null,
          'address': 'Area47/Sector1/470',
          'status': 'Preparing'
        },
        {
          'customer_name': 'Vasco Giant',
          'table_number': '10',
          'address': null,
          'status': 'Ordered'
        },
      ];
    } finally {
      setState(() => isLoading = false);
    }
  }
  Future<void> _signOut() async {
    try {
      await _supabaseService.client.auth.signOut();
      // Navigate to login screen or handle sign out
      // You might want to use Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildMainContent(),
                ),
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
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'DINETRACK',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildCustomersTable(),
        ],
      ),
    );
  }

  Widget _buildClosedOrdersView() {
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
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
          const Spacer(),
          _buildSidebarIcon(Icons.settings, 4, 'Settings'),
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
              color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
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
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
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
            color: Colors.black.withOpacity(0.05),
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
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: Icon(Icons.logout, color: Colors.white),
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
                'Shoda Man',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '(Receptionist)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTable() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: Text(
                'Checked In Customers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Customer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Table NO./Address',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          checkedInCustomers.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(48.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No customers checked in yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: checkedInCustomers.length,
            itemBuilder: (context, index) {
              final customer = checkedInCustomers[index];
              return _buildCustomerRow(customer, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> customer, int index) {
    final tableOrAddress = customer['table_number'] != null
        ? customer['table_number'].toString()
        : customer['address'] ?? '';

    final status = customer['status'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: index % 2 == 0
            ? Colors.white
            : Colors.blue.shade50.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              customer['customer_name'] ?? 'Guest',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              tableOrAddress,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}