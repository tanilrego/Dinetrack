import 'package:dinetrack/flavors/operator/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:dinetrack/core/services/supabase_service.dart';
import 'qr_code_generator.dart';
import 'dart:math';

class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  final supabase = SupabaseService().client;
  final SupabaseService _supabaseService = SupabaseService();
  String _currentEstablishmentId = '';
  String _operatorName = 'Operator';
  double totalSales = 0;
  int totalOrders = 0;
  int activeTables = 0;
  List<Map<String, dynamic>> staffList = [];
  List<Map<String, dynamic>> qrCodesList = [];
  bool isDarkMode = false;
  String? _profileImageUrl;

  bool isLoading = true;

  // Navigation
  int selectedMenuIndex =
      0; // 0 = Dashboard, 1 = Menu, 2 = Orders, 3 = QR Codes, etc.

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      // Get current operator's establishment ID
      final user = supabase.auth.currentUser;
      // print('Current user: ${user?.email} (${user?.id})');

      if (user != null) {
        // Fetch User Name and Profile Image
        try {
          final userData = await supabase
              .from('users')
              .select('full_name, profile_image_url')
              .eq('id', user.id)
              .maybeSingle();
          if (userData != null) {
            if (userData['full_name'] != null) {
              _operatorName = userData['full_name'];
            }
            _profileImageUrl = userData['profile_image_url'];
          }
        } catch (_) {}

        // Use the centralized helper method
        final estabId = await _supabaseService.getOperatorEstablishmentId();

        if (estabId != null) {
          _currentEstablishmentId = estabId;
        }
      }

      if (_currentEstablishmentId.isEmpty) {
        // print('❌ CRITICAL: No establishment ID found!');
        // print('User needs to be assigned to an establishment.');
        _showNoEstablishmentDialog();
        setState(() => isLoading = false);
        return;
      }

      // print('✅ FINAL Establishment ID: $_currentEstablishmentId');

      // Load the rest of the dashboard data...
      await _loadEstablishmentDashboardData();
    } catch (e) {
      // print('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadEstablishmentDashboardData() async {
    try {
      // Load sales data for today - only PAID orders
      final salesData = await supabase
          .from('orders')
          .select('total_amount')
          .gte('created_at', DateTime.now().toIso8601String().split('T')[0])
          .eq('establishment_id', _currentEstablishmentId)
          .eq('payment_status', 'paid');

      totalSales = (salesData as List).fold(
        0.0,
        (sum, order) => sum + ((order['total_amount'] ?? 0) as num).toDouble(),
      );

      totalOrders = (salesData as List).length;

      // Load ALL tables for the establishment
      final tablesData = await supabase
          .from('tables')
          .select('id')
          .eq('establishment_id', _currentEstablishmentId);

      activeTables = (tablesData as List).length;

      // Load staff data
      await _loadStaffData();

      // Load QR codes data
      final qrData = await supabase
          .from('tables')
          .select(
            'id, label, table_number, qr_code, qr_code_data, capacity, is_available, created_at',
          )
          .eq('establishment_id', _currentEstablishmentId)
          .order('table_number');

      qrCodesList = List<Map<String, dynamic>>.from(qrData as List);

      // print('✅ Dashboard data loaded successfully');
    } catch (e) {
      // print('Error loading establishment data: $e');
    }
  }

  void _showNoEstablishmentDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('No Establishment Assigned'),
          content: const Text(
            'You need to be assigned to an establishment to use the dashboard. Please contact an administrator.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadStaffData() async {
    // ADD THIS SIMPLE DEBUG FIRST:
    // print('🔴 DEBUG START');
    // print('Current establishment ID: "$_currentEstablishmentId"');
    // print('ID length: ${_currentEstablishmentId.length}');
    // print('Expected ID: "633f850b-3b6d-4cc1-9132-14fdf487440a"');
    // print('IDs match? ${_currentEstablishmentId == "633f850b-3b6d-4cc1-9132-14fdf487440a"}');

    // Test with hardcoded ID
    // const hardcodedId = '633f850b-3b6d-4cc1-9132-14fdf487440a';

    try {
      // final hardcodedResult = await supabase...
      // final variableResult = await supabase...

      // print('Variable result length: ${variableResult.length}');
      // print('Variable result: $variableResult');
    } catch (e) {
      // print('🔴 DEBUG Error: $e');
      // print('Error type: ${e.runtimeType}');
    }

    // print('🔴 DEBUG END\n');

    // If kitchen assignments are found, continue with the rest
    // ... rest of your _loadStaffData method

    try {
      // print('🔍 Loading staff data...');
      // print('Establishment ID: $_currentEstablishmentId');

      if (_currentEstablishmentId.isEmpty) {
        // print('❌ No establishment ID');
        setState(() {
          staffList = [];
        });
        return;
      }

      List<Map<String, dynamic>> allStaff = [];

      // 1. Get staff_assignments (SIMPLEST POSSIBLE QUERY)
      try {
        // print('📋 Getting staff_assignments...');
        final staffResponse = await supabase
            .from('staff_assignments')
            .select()
            .eq('establishment_id', _currentEstablishmentId);

        // print('Found ${staffResponse.length} staff assignments');

        for (var staff in staffResponse) {
          // print('Staff: ${staff['name']} - ${staff['role']}');
          allStaff.add({
            'name': staff['name']?.toString() ?? 'Unknown',
            'email': staff['email']?.toString() ?? 'No email',
            'role': staff['role']?.toString() ?? 'Staff',
          });
        }
      } catch (e) {
        // print('Error with staff_assignments: $e');
      }

      // 2. Get kitchen_assignments (SIMPLEST POSSIBLE QUERY)
      try {
        // print('🍳 Getting kitchen_assignments...');
        final kitchenResponse = await supabase
            .from('kitchen_assignments')
            .select()
            .eq('establishment_id', _currentEstablishmentId);

        // print('Found ${kitchenResponse.length} kitchen assignments');
        // print('Raw kitchen data: $kitchenResponse');

        for (var kitchen in kitchenResponse) {
          final userId = kitchen['user_id']?.toString();
          // print('Kitchen user ID: $userId');

          if (userId != null && userId.isNotEmpty) {
            // Get user details
            try {
              final userResponse = await supabase
                  .from('users')
                  .select()
                  .eq('id', userId)
                  .maybeSingle();

              if (userResponse != null) {
                // print('Found user: $userResponse');
                allStaff.add({
                  'assignment_id':
                      kitchen['id'], // Store assignment ID for deletion
                  'name':
                      userResponse['full_name']?.toString() ?? 'Kitchen Staff',
                  'email': userResponse['email']?.toString() ?? 'No email',
                  'role': kitchen['assigned_station'] ?? 'Kitchen Staff',
                  'is_kitchen': true, // visual flag
                });
              } else {
                // print('No user found for ID: $userId');
                allStaff.add({
                  'assignment_id': kitchen['id'],
                  'name': 'Kitchen Staff',
                  'email': 'No email',
                  'role': kitchen['assigned_station'] ?? 'Kitchen Staff',
                  'is_kitchen': true,
                });
              }
            } catch (e) {
              // print('Error getting user $userId: $e');
              allStaff.add({
                'assignment_id': kitchen['id'],
                'name': 'Kitchen Staff',
                'email': 'No email',
                'role': kitchen['assigned_station'] ?? 'Kitchen Staff',
                'is_kitchen': true,
              });
            }
          }
        }
      } catch (e) {
        // print('Error with kitchen_assignments: $e');
        // print('Error type: ${e.runtimeType}');
      }

      setState(() {
        staffList = allStaff;
      });
    } catch (e) {
      // print('💥 CRITICAL ERROR in _loadStaffData: $e');
      setState(() {
        staffList = [];
      });
    }
  }

  /*
  Future<void> _loadStaffData() async {
    try {
      // print('Loading staff data (simple) for establishment: $_currentEstablishmentId');

      if (_currentEstablishmentId.isEmpty) {
        // print('⚠️ Cannot load staff: establishment ID is empty');
        setState(() { staffList = []; });
        return;
      }

      List<Map<String, dynamic>> allStaff = [];

      // 1. Get staff from staff_assignments
      final staffAssignments = await supabase
          .from('staff_assignments')
          .select('name, email, role')
          .eq('establishment_id', _currentEstablishmentId)
          .eq('is_active', true)
          .order('role')
          .order('name');

      // print('Found ${staffAssignments.length} staff assignments');

      for (var staff in staffAssignments) {
        final name = staff['name']?.toString() ?? 'Unknown';
        final email = staff['email']?.toString() ?? '';
        final role = staff['role']?.toString() ?? 'Staff';

        if (name.isNotEmpty && name != 'Unknown') {
          allStaff.add({
            'name': name,
            'email': email.isEmpty ? 'No email' : email,
            'role': role,
            'source': 'staff_assignments'
          });
        }
      }

      // 2. Get kitchen staff
      try {
        final kitchenAssignments = await supabase
            .from('kitchen_assignments')
            .select('user_id, assigned_station')
            .eq('establishment_id', _currentEstablishmentId)
            .eq('is_active', true);

        // print('Found ${kitchenAssignments.length} kitchen assignments');

        for (var assignment in kitchenAssignments) {
          final userId = assignment['user_id']?.toString();
          final station = assignment['assigned_station']?.toString();

          if (userId != null && userId.isNotEmpty) {
            try {
              // Try to get user details
              final userDetails = await supabase
                  .from('users')
                  .select('full_name, email')
                  .eq('id', userId)
                  .maybeSingle();

              if (userDetails != null) {
                final name = userDetails['full_name']?.toString() ?? 'Unknown';
                final email = userDetails['email']?.toString() ?? '';
                final role = station != null && station.isNotEmpty
                    ? '$station (Kitchen)'
                    : 'Kitchen Staff';

                if (name.isNotEmpty && name != 'Unknown') {
                  allStaff.add({
                    'name': name,
                    'email': email.isEmpty ? 'No email' : email,
                    'role': role,
                    'source': 'kitchen_assignments'
                  });
                }
              } else {
                // Add with minimal info
                allStaff.add({
                  'name': 'Kitchen Staff',
                  'email': 'No email',
                  'role': station != null && station.isNotEmpty
                      ? '$station (Kitchen)'
                      : 'Kitchen Staff',
                  'source': 'kitchen_assignments'
                });
              }
            } catch (e) {
              // print('Error fetching kitchen user $userId: $e');

              // Add with minimal info
              allStaff.add({
                'name': 'Kitchen Staff',
                'email': 'No email',
                'role': station != null && station.isNotEmpty
                    ? '$station (Kitchen)'
                    : 'Kitchen Staff',
                'source': 'kitchen_assignments'
              });
            }
          }
        }
      } catch (e) {
        // print('⚠️ Error loading kitchen assignments: $e');
      }

      // Sort staff
      allStaff.sort((a, b) {
        // Sort by role priority
        final roleOrder = {
          'manager': 1,
          'operator': 2,
          'cashier': 3,
          'waiter': 4,
          'kitchen': 5,
          'staff': 6,
        };

        final roleA = a['role']?.toString().toLowerCase() ?? '';
        final roleB = b['role']?.toString().toLowerCase() ?? '';

        final priorityA = roleOrder[roleA] ?? 99;
        final priorityB = roleOrder[roleB] ?? 99;

        if (priorityA != priorityB) return priorityA.compareTo(priorityB);

        // Then by name
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      });

      setState(() {
        staffList = allStaff;
      });

      // print('✅ Loaded ${staffList.length} staff members');

    } catch (e) {
      // print('❌ Error loading staff data: $e');
      setState(() {
        staffList = [];
      });
    }
  }
*/

  Future<void> _signOut() async {
    try {
      await _supabaseService.client.auth.signOut();
      // Navigate to login screen or handle sign out
      // You might want to use Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      // debugPrint('Error signing out: $e');
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
        return _buildMenuView();
      case 2:
        return _buildOrdersView();
      case 3:
        return QRCodeGeneratorPage(
          establishmentId: _currentEstablishmentId,
          isDarkMode: isDarkMode,
          onBackToDashboard: () {
            setState(() {
              selectedMenuIndex = 0; // Go back to dashboard
            });
          },
          onQRCodeGenerated: () {
            // Refresh dashboard data when QR code is generated
            _loadDashboardData();
          },
        );
      case 4:
        return _buildInventoryView();
      case 5:
        return _buildStaffView();
      case 6:
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
          _buildStatsCards(),
          const SizedBox(height: 32),
          _buildStaffTable(),
        ],
      ),
    );
  }

  // Placeholder views for other menu items
  Widget _buildMenuView() {
    return Center(
      child: Text(
        'Menu Management',
        style: TextStyle(
          fontSize: 24,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildOrdersView() {
    return Center(
      child: Text(
        'Orders View',
        style: TextStyle(
          fontSize: 24,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildInventoryView() {
    return Center(
      child: Text(
        'Inventory Management',
        style: TextStyle(
          fontSize: 24,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildStaffView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Staff Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddKitchenStaffDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Kitchen Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          if (staffList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text(
                  'No staff assigned yet.',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final staff = staffList[index];
                final isKitchen = staff['is_kitchen'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isKitchen
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      child: Icon(
                        isKitchen ? Icons.kitchen : Icons.person,
                        color: isKitchen ? Colors.orange : Colors.blue,
                      ),
                    ),
                    title: Text(
                      staff['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['role'] ?? 'Staff',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        Text(
                          staff['email'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    trailing: isKitchen
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _confirmDeleteStaff(staff),
                          )
                        : null, // Don't allow deleting managers/other staff yet
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _confirmDeleteStaff(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text(
          'Are you sure you want to remove ${staff['name']} from the kitchen staff?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteStaff(staff['assignment_id']);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStaff(String? assignmentId) async {
    if (assignmentId == null) return;

    setState(() => isLoading = true);
    try {
      await _supabaseService.removeKitchenStaff(assignmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member removed successfully')),
        );
        await _loadStaffData(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing staff: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddKitchenStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(); // Or auto-generate
    final stationCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Kitchen Staff'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Invalid email'
                          : null,
                    ),
                    TextFormField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'Temporary password for login',
                      ),
                      validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                      obscureText: true,
                    ),
                    TextFormField(
                      controller: stationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Station',
                        hintText: 'e.g. Grill, Prep, Chef',
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSubmitting = true);

                          try {
                            await _supabaseService.createKitchenStaffAccount(
                              establishmentId: _currentEstablishmentId,
                              email: emailCtrl.text.trim(),
                              password: passwordCtrl.text.trim(),
                              fullName: nameCtrl.text.trim(),
                              station: stationCtrl.text.trim(),
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Kitchen staff added successfully!',
                                  ),
                                ),
                              );
                              _loadDashboardData(); // Refresh all data
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            // Show specific error if possible
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add staff: $e'),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Staff'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 24,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
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
          _buildSidebarIcon(Icons.dashboard, 0),
          _buildSidebarIcon(Icons.restaurant_menu, 1),
          _buildSidebarIcon(Icons.receipt_long, 2),
          _buildSidebarIcon(Icons.qr_code_2, 3),
          _buildSidebarIcon(Icons.inventory_2_outlined, 4),
          _buildSidebarIcon(Icons.people, 5),
          const Spacer(),
          // Logout Icon
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

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
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.restaurant),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarIcon(IconData icon, int index) {
    bool isActive = selectedMenuIndex == index;
    return GestureDetector(
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
              GestureDetector(
                onTap: _navigateToProfile,
                child: Text(
                  _operatorName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              // roles etc if needed
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _navigateToProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              backgroundColor: Colors.grey,
              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperatorProfileScreen(
          establishmentId: _currentEstablishmentId,
          isDarkMode: isDarkMode,
        ),
      ),
    );

    if (result == true) {
      _loadDashboardData(); // Refresh if profile updated
    }
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Sales Today',
            'MWK ${totalSales.toStringAsFixed(0)}',
            Colors.green.shade100,
            Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Orders',
            totalOrders.toString(),
            Colors.blue.shade100,
            Colors.blue.shade700,
            icon: Icons.shopping_bag,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total tables',
            activeTables.toString(),
            Colors.yellow.shade100,
            Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color bgColor,
    Color textColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTable() {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${staffList.length} staff',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Staff List
          if (staffList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No staff members found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add staff members to see them here',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...staffList.asMap().entries.map((entry) {
              final index = entry.key;
              final staff = entry.value;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: index % 2 == 0
                      ? Colors.white
                      : Colors.blue.shade50.withValues(alpha: 0.3),
                  border: Border(
                    bottom: index < staffList.length - 1
                        ? BorderSide(color: Colors.grey.shade200)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    // Profile icon
                    Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _getRoleColor(staff['role'] ?? ''),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(staff['name'] ?? ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: Text(
                        staff['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Text(
                        staff['email'] ?? 'No email',
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(
                            staff['role'] ?? '',
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getRoleColor(
                              staff['role'] ?? '',
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          (staff['role'] ?? 'Staff').toUpperCase(),
                          style: TextStyle(
                            color: _getRoleColor(staff['role'] ?? ''),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // Helper methods
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  Color _getRoleColor(String role) {
    final roleLower = role.toLowerCase();

    if (roleLower.contains('manager') || roleLower.contains('admin')) {
      return const Color(0xFF10B981); // Green
    } else if (roleLower.contains('kitchen') || roleLower.contains('chef')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (roleLower.contains('staff')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (roleLower.contains('waiter') || roleLower.contains('server')) {
      return const Color(0xFF8B5CF6); // Violet
    } else {
      return const Color(0xFF6B7280); // Gray
    }
  }
}
