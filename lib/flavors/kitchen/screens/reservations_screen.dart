import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ReservationsScreen extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;

  const ReservationsScreen({
    super.key,
    required this.establishmentId,
    required this.isDarkMode,
  });

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _reservations = [];
  String _filterStatus = 'pending'; // pending, confirmed, all

  @override
  void initState() {
    super.initState();
    _fetchReservations();
    _subscribeToReservations();
  }

  void _subscribeToReservations() {
    _supabaseService.client
        .channel('public:reservations:${widget.establishmentId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'establishment_id',
            value: widget.establishmentId,
          ),
          callback: (payload) {
            _fetchReservations(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _fetchReservations({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      var query = _supabaseService.client
          .from('reservations')
          .select('*, users:customer_id(full_name, email, phone)')
          .eq('establishment_id', widget.establishmentId);

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final response = await query.order('reservation_time', ascending: true);
      if (mounted) {
        setState(() {
          _reservations = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reservations: $e')),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _supabaseService.client
          .from('reservations')
          .update({'status': status})
          .eq('id', id);

      // _fetchReservations(); // Handled by subscription now automatically

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservation marked as $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reservations',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip('Pending', 'pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Confirmed', 'confirmed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All History', 'all'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reservations.isEmpty
                  ? Center(
                      child: Text(
                        'No reservations found',
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.grey
                              : Colors.grey[600],
                          fontSize: 18,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _reservations.length,
                      itemBuilder: (context, index) {
                        return _buildReservationCard(_reservations[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = status);
          _fetchReservations();
        }
      },
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (widget.isDarkMode ? Colors.white70 : Colors.black87),
      ),
      backgroundColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final user = reservation['users'];
    final customerName = user != null
        ? (user['full_name'] ?? 'Unknown')
        : 'Guest';
    final customerPhone = user != null ? (user['phone'] ?? 'N/A') : 'N/A';
    final timeStr = reservation['reservation_time'];
    final time = DateTime.parse(
      timeStr,
    ).toLocal(); // Supabase returns UTC usually
    final status = reservation['status'];
    final partySize = reservation['party_size'];
    final notes = reservation['special_requests'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(time),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  Text(
                    DateFormat('d').format(time),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  Text(
                    DateFormat('Hm').format(time),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: widget.isDarkMode
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$partySize People', // Party Size
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.grey
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.phone,
                        size: 16,
                        color: widget.isDarkMode
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customerPhone,
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.grey
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Note: $notes',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status/Actions
            if (status == 'pending') ...[
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 30,
                ),
                onPressed: () => _updateStatus(reservation['id'], 'confirmed'),
                tooltip: 'Confirm',
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                onPressed: () => _updateStatus(reservation['id'], 'cancelled'),
                tooltip: 'Decline',
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'confirmed'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == 'confirmed' ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'confirmed' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
