// lib/flavors/customer/screens/qr_table_menu_screen.dart
import 'package:flutter/material.dart';
import 'customer_navigation.dart';

class QRTableMenuScreen extends StatelessWidget {
  final String establishmentId;
  final String tableId;
  const QRTableMenuScreen({
    super.key,
    required this.establishmentId,
    required this.tableId,
  });

  @override
  Widget build(BuildContext context) {
    // Navigate to the main customer navigation which includes cart state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerNavigation(
            establishmentId: establishmentId,
            initialTableNumber: tableId,
          ),
        ),
      );
    });

    // Show loading screen during navigation
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF53B175)),
            const SizedBox(height: 20),
            Text(
              'Loading menu for table...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
