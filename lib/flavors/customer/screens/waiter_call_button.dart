// lib/flavors/customer/widgets/waiter_call_button.dart
import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';

class WaiterCallButton extends StatefulWidget {
  final String establishmentId;
  final String tableId;
  const WaiterCallButton({
    super.key,
    required this.establishmentId,
    required this.tableId,
  });

  @override
  State<WaiterCallButton> createState() => _WaiterCallButtonState();
}

class _WaiterCallButtonState extends State<WaiterCallButton> {
  final SupabaseService _svc = SupabaseService();
  bool _sending = false;

  Future<void> _callWaiter() async {
    setState(() => _sending = true);
    try {
      // Remove .execute() and just await the insert
      await _svc.client.from('assist_requests').insert({
        'establishment_id': widget.establishmentId,
        'table_id': widget.tableId,
        'status': 'open',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiter called successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to call waiter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _sending ? null : _callWaiter,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      tooltip: 'Call Waiter',
      child: _sending
          ? const CircularProgressIndicator(color: Colors.white)
          : const Icon(Icons.assistant),
    );
  }
}
