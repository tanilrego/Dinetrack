import 'package:flutter/material.dart';

import '../../landing_page.dart';
import '../services/auth_service.dart';
import '../../flavors/customer/screens/customer_navigation.dart';
import '../../flavors/operator/screens/home_operator.dart';
import '../../flavors/kitchen/screens/home_kitchen.dart';
import '../../flavors/supervisor/screens/home_supervisor.dart';

class RoleBasedRouter extends StatefulWidget {
  final String userId;
  final String? pendingEstablishmentId;
  final String? tableId;

  const RoleBasedRouter({
    super.key,
    required this.userId,
    this.pendingEstablishmentId,
    this.tableId,
  });

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  String? _userRole;
  bool _loading = true;

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
        final targetId =
            widget.pendingEstablishmentId ?? AuthService.pendingEstablishmentId;

        if (targetId != null) {
          return CustomerNavigation(
            establishmentId: targetId,
            tableId: widget.tableId,
          );
        }

        // If no target establishment, user shouldn't be here as 'logged in customer'
        // Sign out and show landing page (effectively "no session" state)
        // We do this via a microtask to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await AuthService().signOut();
        });
        // Return loading or landing page (which will rebuild shortly)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
