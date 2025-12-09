import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Supavisor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'All Restaurants'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending Approvals'),
            Tab(icon: Icon(Icons.card_membership), text: 'Subscriptions'),
          ],
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade200),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final restaurants = snapshot.data ?? [];

        if (restaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, size: 80, color: Colors.blue.shade200),
                const SizedBox(height: 16),
                const Text(
                  'No restaurants registered yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade200),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final pendingRestaurants = snapshot.data ?? [];

        if (pendingRestaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 80,
                  color: Colors.blue.shade200,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pending approvals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade200),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final subscriptions = snapshot.data ?? [];

        if (subscriptions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_membership,
                  size: 80,
                  color: Colors.blue.shade200,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No subscriptions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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

  // RESTAURANT CARD WIDGET
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.restaurant, size: 80),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.restaurant, size: 80),
              ),
            // Restaurant Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? Colors.green
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.email, 'Email:', email),
                  _buildDetailRow(Icons.phone, 'Phone:', phone),
                  _buildDetailRow(Icons.location_on, 'Address:', address),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRestaurantDetails(restaurant),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showDeleteConfirmation(context, id, name),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.orange.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.restaurant, size: 80),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.restaurant, size: 80),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.email, 'Email:', email),
                  _buildDetailRow(Icons.phone, 'Phone:', phone),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Submitted:',
                    submittedDate,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _approveRestaurant(context, id, name),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _rejectRestaurant(context, id, name),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.purple.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'active'
                          ? Colors.green
                          : status == 'expired'
                          ? Colors.red
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
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
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          planType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          'MK$price',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.purple,
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
        ),
      ),
    );
  }

  // DETAIL ROW WIDGET
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 13,
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
        title: const Text(
          'Delete Restaurant',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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
          .select('*, users!owner_id(email, profile_image_url)')
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
          .eq('is_active', true)
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
      // Soft delete - set is_active to false
      await supabase
          .from('establishments')
          .update({'is_active': false})
          .eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Establishment deactivated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating establishment: $e')),
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving establishment: $e')),
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
      // Soft delete - set is_active to false
      await supabase
          .from('establishments')
          .update({'is_active': false, 'supervisor_approved': false})
          .eq('id', id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting establishment: $e')),
        );
      }
    }
  }

  void _showRestaurantDetails(Map<String, dynamic> restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.blue,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
