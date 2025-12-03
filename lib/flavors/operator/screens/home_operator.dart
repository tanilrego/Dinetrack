//lib/flavors/operator/screens/home_operator.dart
import 'package:flutter/material.dart';
import 'package:dinetrack/core/services/supabase_service.dart';
import 'qr_code_generator.dart';

class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  final supabase = SupabaseService().client;
  final SupabaseService _supabaseService = SupabaseService();
  String _currentEstablishmentId = '';
  // Dashboard data
  double totalSales = 0;
  int totalOrders = 0;
  int activeTables = 0;
  List<Map<String, dynamic>> staffList = [];
  List<Map<String, dynamic>> qrCodesList = [];
  bool isDarkMode = false;
  bool isLoading = true;

  // Navigation
  int selectedMenuIndex = 0; // 0 = Dashboard, 1 = Menu, 2 = Orders, 3 = QR Codes, etc.

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
      if (user != null) {
        final operatorData = await supabase
            .from('kitchen_assignments')
            .select('establishment_id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (operatorData != null) {
          // Ensure it's a string and not null
          final establishmentId = operatorData['establishment_id'];
          if (establishmentId != null) {
            _currentEstablishmentId = establishmentId.toString();
            print('Establishment ID loaded: $_currentEstablishmentId'); // Debug
          }
        }
      }
      if (_currentEstablishmentId.isEmpty) {
        print('Warning: Establishment ID is empty!');
        return;
      }

      // Load sales data for today
      final salesData = await supabase
          .from('orders')
          .select('total_amount')
          .gte('created_at', DateTime.now().toIso8601String().split('T')[0])
          .eq('establishment_id', _currentEstablishmentId);

      totalSales = (salesData as List).fold(
          0.0,
              (sum, order) => sum + ((order['total_amount'] ?? 0) as num).toDouble());

      totalOrders = (salesData as List).length;

      // Load active tables - from 'tables' table
      final tablesData = await supabase
          .from('tables')
          .select('id')
          .eq('is_available', false)
          .eq('establishment_id', _currentEstablishmentId);

      activeTables = (tablesData as List).length;

      // Load staff data
      final staffData = await supabase
          .from('staff_assignments')
          .select('name, email, role')
          .eq('is_active', true)
          .eq('establishment_id', _currentEstablishmentId);

      staffList = List<Map<String, dynamic>>.from(staffData as List);

      // Load QR codes data from 'tables' table
      final qrData = await supabase
          .from('tables')
          .select('id, label, table_number, qr_code, qr_code_data, capacity, is_available, created_at')
          .eq('establishment_id', _currentEstablishmentId)
          .order('table_number');

      qrCodesList = List<Map<String, dynamic>>.from(qrData as List);
    } catch (e) {
      print('Error loading dashboard data: $e');
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
        return _buildMenuView();
      case 2:
        return _buildOrdersView();
      case 3:
        return QrCodeGeneratorScreen(
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
        style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildOrdersView() {
    return Center(
      child: Text(
        'Orders View',
        style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildInventoryView() {
    return Center(
      child: Text(
        'Inventory Management',
        style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildStaffView() {
    return Center(
      child: Text(
        'Staff Management',
        style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildSettingsView() {
    return Center(
      child: Text(
        'Settings',
        style: TextStyle(fontSize: 24, color: isDarkMode ? Colors.white : Colors.black),
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
          _buildSidebarIcon(Icons.settings, 6),
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
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant),
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
            color: isActive ? Colors.white.withValues(alpha:0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
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
                const SizedBox(width: 8),
                // Logout button
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add any additional user info here if needed
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
            'Active Tables',
            activeTables.toString(),
            Colors.yellow.shade100,
            Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color bgColor, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              color: textColor.withValues(alpha:0.8),
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
            color: Colors.black.withValues(alpha:0.05),
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
                'Available Staff',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: index % 2 == 0
                      ? Colors.white
                      : Colors.blue.shade50.withValues(alpha:0.3),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        staff['name'] ?? '',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        staff['email'] ?? '',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        staff['role'] ?? '',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}