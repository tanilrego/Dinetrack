import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class SupervisorPage extends StatefulWidget {
  const SupervisorPage({super.key});

  @override
  State<SupervisorPage> createState() => _SupervisorPageState();
}

class _SupervisorPageState extends State<SupervisorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Supervisor Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 24),
              tooltip: 'Logout',
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await supabase.auth.signOut();
                          if (mounted) {
                            if (kIsWeb) {
                              // ignore: avoid_web_libraries_in_flutter
                              html.window.location.reload();
                            } else {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Logged out successfully'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.restaurant), text: 'All Restaurants'),
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
              Tab(icon: Icon(Icons.card_membership), text: 'Subscriptions'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllRestaurantsTab(),
          _buildPendingApprovalsTab(),
          _buildSubscriptionsTab(),
        ],
      ),
    );
  }

  // ALL RESTAURANTS TAB
  Widget _buildAllRestaurantsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllRestaurants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final restaurants = snapshot.data ?? [];

        if (restaurants.isEmpty) {
          return _buildEmptyState(
            icon: Icons.restaurant,
            title: 'No Restaurants',
            subtitle: 'All registered restaurants will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFF4F46E5),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurants[index];
              return _buildRestaurantCard(restaurant, isApproved: true);
            },
          ),
        );
      },
    );
  }

  // PENDING APPROVALS TAB
  Widget _buildPendingApprovalsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPendingRestaurants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final pendingRestaurants = snapshot.data ?? [];

        if (pendingRestaurants.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: 'No Pending Approvals',
            subtitle: 'All new restaurants have been reviewed',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFF4F46E5),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: pendingRestaurants.length,
            itemBuilder: (context, index) {
              final restaurant = pendingRestaurants[index];
              return _buildPendingRestaurantCard(restaurant);
            },
          ),
        );
      },
    );
  }

  // SUBSCRIPTIONS TAB
  Widget _buildSubscriptionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRestaurantSubscriptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final subscriptions = snapshot.data ?? [];

        if (subscriptions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.card_membership,
            title: 'No Subscriptions',
            subtitle: 'Subscription data will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFF4F46E5),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              return _buildSubscriptionCard(subscription);
            },
          ),
        );
      },
    );
  }

  // EMPTY STATE
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 50, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280).withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ERROR STATE
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.error_outline, size: 50, color: Colors.red),
          ),
          const SizedBox(height: 20),
          const Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280).withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // RESTAURANT CARD
  Widget _buildRestaurantCard(
    Map<String, dynamic> restaurant, {
    bool isApproved = true,
  }) {
    final id = restaurant['id'];
    final name = restaurant['name'] ?? 'Unknown';
    final email = restaurant['email'] ?? 'N/A';
    final phone = restaurant['phone'] ?? 'N/A';
    final address = restaurant['address'] ?? 'N/A';
    final imageUrl = restaurant['image_url'];
    final status = restaurant['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section - Small Avatar Style
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small Image Thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF9FAFB),
                                child: Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: const Color(
                                    0xFF4F46E5,
                                  ).withValues(alpha: 0.3),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFFF9FAFB),
                            child: Icon(
                              Icons.restaurant,
                              size: 40,
                              color: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Header with Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'active'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Details
            _buildDetailRow(Icons.email, 'Email:', email),
            _buildDetailRow(Icons.phone, 'Phone:', phone),
            _buildDetailRow(Icons.location_on, 'Address:', address),
            const SizedBox(height: 12),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRestaurantDetails(restaurant),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context, id, name),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // PENDING RESTAURANT CARD
  Widget _buildPendingRestaurantCard(Map<String, dynamic> restaurant) {
    final id = restaurant['id'];
    final name = restaurant['name'] ?? 'Unknown';
    final email = restaurant['email'] ?? 'N/A';
    final phone = restaurant['phone'] ?? 'N/A';
    final imageUrl = restaurant['image_url'];
    final submittedDate = restaurant['created_at'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Header Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small Image Thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF9FAFB),
                                child: Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.3),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFFF9FAFB),
                            child: Icon(
                              Icons.restaurant,
                              size: 40,
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDetailRow(Icons.email, 'Email:', email),
            _buildDetailRow(Icons.phone, 'Phone:', phone),
            _buildDetailRow(Icons.calendar_today, 'Submitted:', submittedDate),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveRestaurant(context, id, name),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectRestaurant(context, id, name),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // SUBSCRIPTION CARD
  Widget _buildSubscriptionCard(Map<String, dynamic> subscription) {
    final restaurantName = subscription['restaurant_name'] ?? 'Unknown';
    final planType = subscription['plan_type'] ?? 'Basic';
    final status = subscription['status'] ?? 'active';
    final startDate = subscription['start_date'] ?? 'N/A';
    final endDate = subscription['end_date'] ?? 'N/A';
    final price = subscription['price'] ?? '0.00';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  restaurantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'active'
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : status == 'expired'
                      ? Colors.red.withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'active'
                        ? const Color(0xFF10B981)
                        : status == 'expired'
                        ? Colors.red
                        : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Type',
                      style: TextStyle(
                        color: const Color(0xFF6B7280).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      planType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        color: const Color(0xFF6B7280).withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MK$price',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.date_range, 'Start Date:', startDate),
          _buildDetailRow(Icons.date_range, 'End Date:', endDate),
        ],
      ),
    );
  }

  // DETAIL ROW
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // DELETE CONFIRMATION
  void _showDeleteConfirmation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Restaurant'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteRestaurant(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // SUPABASE OPERATIONS
  Future<List<Map<String, dynamic>>> _fetchAllRestaurants() async {
    try {
      final response = await supabase
          .from('establishments')
          .select('*, users!owner_id(email, profile_image_url, full_name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((est) {
        final owner = est['users'];
        return {
          'id': est['id'],
          'name': est['name'],
          'type': est['type'],
          'address': est['address'],
          'phone': est['phone'],
          'description': est['description'],
          'dine_coins_balance': est['dine_coins_balance'],
          'is_active': est['is_active'],
          'supervisor_approved': est['supervisor_approved'],
          'created_at': est['created_at'],
          'email': owner != null ? owner['email'] : 'N/A',
          'image_url': owner != null ? owner['profile_image_url'] : null,
          'owner_name': owner != null ? owner['full_name'] : 'N/A',
          'status': est['is_active'] ? 'active' : 'inactive',
        };
      }).toList();
    } catch (e) {
      throw 'Error fetching establishments: $e';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPendingRestaurants() async {
    try {
      final response = await supabase
          .from('establishments')
          .select('*, users!owner_id(email, profile_image_url)')
          .eq('supervisor_approved', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((est) {
        final owner = est['users'];
        return {
          'id': est['id'],
          'name': est['name'],
          'email': owner != null ? owner['email'] : 'N/A',
          'phone': est['phone'],
          'created_at': est['created_at'],
          'image_url': owner != null ? owner['profile_image_url'] : null,
        };
      }).toList();
    } catch (e) {
      throw 'Error fetching pending establishments: $e';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRestaurantSubscriptions() async {
    try {
      final response = await supabase
          .from('subscriptions')
          .select('*, restaurants(name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response).map((sub) {
        return {
          ...sub,
          'restaurant_name': sub['restaurants']['name'] ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      throw 'Error fetching subscriptions: $e';
    }
  }

  Future<void> _deleteRestaurant(String id) async {
    try {
      await supabase
          .from('establishments')
          .update({'is_active': false})
          .eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant deactivated successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating restaurant: $e')),
        );
      }
    }
  }

  Future<void> _approveRestaurant(
    BuildContext context,
    String id,
    String name,
  ) async {
    try {
      await supabase
          .from('establishments')
          .update({'supervisor_approved': true})
          .eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name approved successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving restaurant: $e')),
        );
      }
    }
  }

  Future<void> _rejectRestaurant(
    BuildContext context,
    String id,
    String name,
  ) async {
    try {
      await supabase
          .from('establishments')
          .update({'is_active': false, 'supervisor_approved': false})
          .eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting restaurant: $e')),
        );
      }
    }
  }

  void _showRestaurantDetails(Map<String, dynamic> restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Restaurant Details',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  Icons.restaurant,
                  'Name:',
                  restaurant['name'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.email,
                  'Email:',
                  restaurant['email'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.phone,
                  'Phone:',
                  restaurant['phone'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.location_on,
                  'Address:',
                  restaurant['address'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.person,
                  'Owner:',
                  restaurant['owner_name'] ?? 'N/A',
                ),
                _buildDetailRow(
                  Icons.description,
                  'Description:',
                  restaurant['description'] ?? 'N/A',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
