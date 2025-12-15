import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/reservation_dialog.dart';
import '../../../../core/services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../login_page.dart';
import '../services/auth_service.dart';

class ReservationDialog extends StatefulWidget {
  final String establishmentId;
  final String? establishmentName;

  const ReservationDialog({
    super.key,
    required this.establishmentId,
    this.establishmentName,
  });

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _specialRequestsCtrl = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _partySize = 2;
  String? _selectedTableId;
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = false;

  // Auth State
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    try {
      final response = await _supabaseService.client
          .from('tables')
          .select('id, table_number, capacity')
          .eq('establishment_id', widget.establishmentId)
          .order('table_number');

      if (mounted) {
        setState(() {
          _tables = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching tables: $e');
    }
  }

  void _checkAuth() {
    setState(() {
      _currentUser = _supabaseService.client.auth.currentUser;
    });
  }

  @override
  void dispose() {
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitReservation() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make a reservation')),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Combine Date and Time
      final DateTime reservationTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await _supabaseService.client.from('reservations').insert({
        'customer_id': _currentUser!.id,
        'establishment_id': widget.establishmentId,
        'reservation_time': reservationTime.toIso8601String(),
        'party_size': _partySize,
        'status': 'pending',
        'special_requests': _specialRequestsCtrl.text.trim(),
        'table_id': _selectedTableId,
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation request sent! Wait for confirmation.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('You need to be signed in to book a table.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Set pending establishment so we return here after login
              AuthService.pendingEstablishmentId = widget.establishmentId;
              AuthService.pendingReservationAction = true;

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(
        'Book a Table at ${widget.establishmentName ?? "Restaurant"}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const Divider(),

              // Time Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedTime == null
                      ? 'Select Time'
                      : _selectedTime!.format(context),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context),
              ),
              const Divider(),

              // Party Size
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Party Size'),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _partySize > 1
                            ? () => setState(() => _partySize--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_partySize',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        onPressed: _partySize < 20
                            ? () => setState(() => _partySize++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Table Selection (Optional)
              DropdownButtonFormField<String>(
                value: _selectedTableId,
                decoration: const InputDecoration(
                  labelText: 'Preferred Table (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_restaurant),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Any available table'),
                  ),
                  ..._tables.map((table) {
                    return DropdownMenuItem<String>(
                      value: table['id'],
                      child: Text(
                        'Table ${table['table_number']} (${table['capacity']} ppl)',
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTableId = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Special Requests
              TextFormField(
                controller: _specialRequestsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Special Requests',
                  hintText: 'e.g. High chair, birthday',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReservation,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Book Table'),
        ),
      ],
    );
  }
}
