import 'package:flutter/material.dart';

import '../../landing_page.dart';
import '../services/auth_service.dart';
//import '../../flavors/customer/screens/home_customer.dart';
import '../../flavors/operator/screens/home_operator.dart';
import '../../flavors/kitchen/screens/home_kitchen.dart';
import '../../flavors/supervisor/screens/home_supervisor.dart';

class RoleBasedRouter extends StatefulWidget {
  const RoleBasedRouter({super.key, required String userId});

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  String? _userRole;
  bool _loading = true;
  String establishmntId = "633f850b-3b6d-4cc1-9132-14fdf487440a";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final authService = AuthService();
    final role = await authService.getUserRole();

    setState(() {
      _userRole = role;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_userRole) {
      case 'customer':
        return const LandingPage(); // Allow customers to select restaurant
      case 'operator':
        return OperatorHomeScreen();
      case 'kitchen':
        return KitchenStaffScreen();
      case 'supervisor':
        return SupervisorPage();
      default:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unknown user role'),
                TextButton(
                  onPressed: _loadUserRole,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
    }
  }
}
