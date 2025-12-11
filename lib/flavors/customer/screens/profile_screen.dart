import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic>? _userData;
  double _dineCoinsBalance = 0.0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user != null) {
        // Fetch user profile data
        final userResponse = await _supabaseService.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        setState(() {
          _userData = userResponse;
        });

        // Calculate DineCoins balance from ledger
        final dineCoinsResponse = await _supabaseService.client
            .from('dinecoins_ledger')
            .select()
            .eq('user_id', user.id);

        double balance = 0.0;
        for (final record in dineCoinsResponse) {
          final amount = (record['amount'] as num).toDouble();
          final type = record['transaction_type'] as String;
          if (type == 'credit') {
            balance += amount;
          } else if (type == 'debit') {
            balance -= amount;
          }
        }
        setState(() {
          _dineCoinsBalance = balance;
        });

        // Fetch order statistics
        final ordersResponse = await _supabaseService.client
            .from('orders')
            .select()
            .eq('customer_id', user.id);

        final pending = ordersResponse
            .where(
              (order) =>
                  order['status'] != 'completed' &&
                  order['status'] != 'cancelled',
            )
            .length;

        setState(() {
          _totalOrders = ordersResponse.length;
          _pendingOrders = pending;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      // Clear any pending establishment ID to prevent auto-reentry
      AuthService.pendingEstablishmentId = null;

      await _supabaseService.client.auth.signOut();

      // The AuthGate stream in main.dart will handle the UI switch to LandingPage
      // But just in case, we can force a rebuild or pop if we were deep in navigation
      if (mounted) {
        // Clearing navigation stack prevents "back" button issues
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  void _showDineCoinsHistory() {
    showDialog(
      context: context,
      builder: (context) =>
          DineCoinsHistoryDialog(supabaseService: _supabaseService),
    );
  }

  void _showOrderHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrderHistoryScreen(supabaseService: _supabaseService),
      ),
    );
  }

  void _showUserDetails() {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(
        userData: _userData,
        onUpdate: _loadUserData,
        supabaseService: _supabaseService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "My Account",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Profile Header
                _buildProfileHeader(),
                const SizedBox(height: 30),

                // Statistics Cards
                _buildStatisticsCards(),
                const SizedBox(height: 20),

                // Menu Items
                _buildMenuItems(),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final fullName = _userData?['full_name'] as String? ?? 'Guest User';
    final email = _userData?['email'] as String? ?? 'No email';
    final userType = _userData?['user_type'] as String? ?? 'customer';

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: Color(0xFF2196F3), size: 30),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(email, style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  userType.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        // DineCoins Card
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    color: Color(0xFF53B175),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dineCoinsBalance.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF53B175),
                    ),
                  ),
                  const Text(
                    'DineCoins',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Orders Card
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Icon(Icons.shopping_bag, color: Colors.blue, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    _totalOrders.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    'Total Orders',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Pending Orders Card
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pendingOrders.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Text(
                    'Pending',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        _buildMenuItem(
          Icons.shopping_bag_outlined,
          "Order History",
          _showOrderHistory,
        ),
        _buildMenuItem(
          Icons.card_giftcard,
          "DineCoins History",
          _showDineCoinsHistory,
        ),
        _buildMenuItem(Icons.badge_outlined, "My Details", _showUserDetails),
        _buildMenuItem(Icons.location_on_outlined, "Delivery Address", () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery address feature coming soon!'),
            ),
          );
        }),
        _buildMenuItem(Icons.credit_card, "Payment Methods", () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment methods feature coming soon!'),
            ),
          );
        }),
        _buildMenuItem(Icons.help_outline, "Help & Support", () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Help & support feature coming soon!'),
            ),
          );
        }),
        _buildMenuItem(Icons.info_outline, "About", () {
          showAboutDialog(
            context: context,
            applicationName: 'DineEasy',
            applicationVersion: '1.0.0',
            applicationIcon: const Icon(
              Icons.restaurant,
              color: Color(0xFF53B175),
            ),
          );
        }),

        const SizedBox(height: 20),
        // Logout Button
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _signOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2F3F2),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Color(0xFF53B175)),
                SizedBox(width: 20),
                Text(
                  "Log Out",
                  style: TextStyle(
                    color: Color(0xFF53B175),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.black),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.black,
          ),
          onTap: onTap,
        ),
        const Divider(),
      ],
    );
  }
}

// DineCoins History Dialog
class DineCoinsHistoryDialog extends StatefulWidget {
  final SupabaseService supabaseService;

  const DineCoinsHistoryDialog({super.key, required this.supabaseService});

  @override
  State<DineCoinsHistoryDialog> createState() => _DineCoinsHistoryDialogState();
}

class _DineCoinsHistoryDialogState extends State<DineCoinsHistoryDialog> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDineCoinsHistory();
  }

  Future<void> _loadDineCoinsHistory() async {
    try {
      final user = widget.supabaseService.client.auth.currentUser;
      if (user != null) {
        final response = await widget.supabaseService.client
            .from('dinecoins_ledger')
            .select('*, establishments(name)')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        setState(() {
          _transactions = response;
        });
      }
    } catch (e) {
      debugPrint('Error loading DineCoins history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DineCoins History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF53B175)),
                  )
                : _transactions.isEmpty
                ? const Center(child: Text('No transactions found'))
                : SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        final amount = (transaction['amount'] as num)
                            .toDouble();
                        final type = transaction['transaction_type'] as String;
                        final description =
                            transaction['description'] as String? ?? '';
                        final establishment =
                            transaction['establishments'] != null
                            ? (transaction['establishments']
                                      as Map<String, dynamic>)['name']
                                  as String?
                            : null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              type == 'credit'
                                  ? Icons.add_circle
                                  : Icons.remove_circle,
                              color: type == 'credit'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(description),
                            subtitle: establishment != null
                                ? Text(establishment)
                                : null,
                            trailing: Text(
                              '${type == 'credit' ? '+' : '-'}${amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: type == 'credit'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Order History Screen
class OrderHistoryScreen extends StatefulWidget {
  final SupabaseService supabaseService;

  const OrderHistoryScreen({super.key, required this.supabaseService});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();
  }

  Future<void> _loadOrderHistory() async {
    try {
      final user = widget.supabaseService.client.auth.currentUser;
      if (user != null) {
        final response = await widget.supabaseService.client
            .from('orders')
            .select('*, order_items(*, menu_items(name)), establishments(name)')
            .eq('customer_id', user.id)
            .order('created_at', ascending: false);

        setState(() {
          _orders = response;
        });
      }
    } catch (e) {
      debugPrint('Error loading order history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'confirmed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF53B175)),
            )
          : _orders.isEmpty
          ? const Center(child: Text('No orders found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final orderId = order['id'] as String;
                final totalAmount = (order['total_amount'] as num).toDouble();
                final status = order['status'] as String;
                final createdAt = DateTime.parse(order['created_at'] as String);
                final establishment = order['establishments'] != null
                    ? (order['establishments'] as Map<String, dynamic>)['name']
                          as String?
                    : 'Unknown Establishment';
                final orderItems = order['order_items'] as List? ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${orderId.substring(0, 8)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  status,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          establishment ?? 'Unknown Establishment',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${totalAmount.toStringAsFixed(0)} MWK',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF53B175),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (orderItems.isNotEmpty)
                          Text(
                            '${orderItems.length} item(s)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// User Details Dialog
class UserDetailsDialog extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback onUpdate;
  final SupabaseService supabaseService;

  const UserDetailsDialog({
    super.key,
    required this.userData,
    required this.onUpdate,
    required this.supabaseService,
  });

  @override
  State<UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(
      text: widget.userData?['full_name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userData?['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = widget.supabaseService.client.auth.currentUser;
        if (user != null) {
          await widget.supabaseService.client
              .from('users')
              .update({
                'full_name': _fullNameController.text,
                'phone': _phoneController.text,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', user.id);

          widget.onUpdate();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully!')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF53B175),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
