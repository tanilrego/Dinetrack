import 'package:flutter/material.dart';

import '../../../../core/services/supabase_service.dart';

import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

class TablesPage extends StatefulWidget {
  final String establishmentId;

  const TablesPage({super.key, required this.establishmentId});

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  final SupabaseService _supabaseService = SupabaseService();

  Map<String, String> _upcomingReservations = {};

  @override
  void initState() {
    super.initState();

    _fetchUpcomingReservations();
  }

  Future<void> _fetchUpcomingReservations() async {
    final now = DateTime.now();

    final tomorrow = now.add(const Duration(days: 1));

    try {
      print(
        // DEBUG: Widened search
        'DEBUG: Fetching reservations for establishment: ${widget.establishmentId}',
      );

      print(
        'DEBUG: Time range: ${now.subtract(const Duration(hours: 2))} to $tomorrow',
      );

      final response = await _supabaseService.client
          .from('reservations')
          .select('table_id, reservation_time, status')
          .eq('establishment_id', widget.establishmentId)
          //.neq('status', 'cancelled')
          //.neq('status', 'completed')
          //.not('table_id', 'is', null) // Let's see if they are null
          .gte(
            'reservation_time',
            now
                .subtract(const Duration(days: 7))
                .toIso8601String(), // Look back 7 days
          )
          .lt(
            'reservation_time',
            now.add(const Duration(days: 30)).toIso8601String(),
          ) // Look ahead 30 days
          .order('reservation_time', ascending: true);

      print('DEBUG: Widened Search Found: ${response.length}');

      final Map<String, String> newMap = {};

      for (final res in response) {
        print('DEBUG: Raw Res: $res');

        if (res['table_id'] == null) {
          print('DEBUG: Found reservation with NULL table_id');
          continue;
        }

        final tableId = res['table_id'] as String;

        final time = DateTime.parse(res['reservation_time'] as String);

        final timeStr = DateFormat('EEE d, HH:mm').format(time);

        if (!newMap.containsKey(tableId)) {
          newMap[tableId] = timeStr;

          // print('DEBUG: Mapped Table $tableId to $timeStr');
        }
      }

      if (mounted) {
        setState(() {
          _upcomingReservations = newMap;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reservations: $e');
    }
  }

  Future<void> _markTableAvailable(String tableId) async {
    try {
      await _supabaseService.client
          .from('tables')
          .update({
            'is_available': true,

            'occupied_at': null,

            'last_activity_at': null,
          })
          .eq('id', tableId);

      // Trigger UI update

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating table: $e'),

            backgroundColor: Colors.red,

            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _downloadQrCodes(List<Map<String, dynamic>> tables) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        build: (context) {
          return [
            pw.Header(
              level: 0,

              child: pw.Text(
                "Table QR Codes",

                style: pw.TextStyle(
                  fontSize: 24,

                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Wrap(
              spacing: 40,

              runSpacing: 40,

              children: tables.map((table) {
                final tableNum = table['table_number'];

                final estId = widget.establishmentId;

                // Production URL structure

                final qrData =
                    'https://dinetrack-3hhc.onrender.com/#/restaurant/$estId?table=$tableNum';

                return pw.Container(
                  width: 150,

                  height: 180,

                  padding: const pw.EdgeInsets.all(10),

                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),

                    borderRadius: pw.BorderRadius.circular(10),
                  ),

                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,

                    children: [
                      pw.BarcodeWidget(
                        data: qrData,

                        barcode: pw.Barcode.qrCode(),

                        width: 100,

                        height: 100,
                      ),

                      pw.SizedBox(height: 10),

                      pw.Text(
                        'Table $tableNum',

                        style: pw.TextStyle(
                          fontSize: 16,

                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

            decoration: BoxDecoration(
              color: Colors.white,

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
                  'Table Management',

                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,

                    color: const Color(0xFF1F2937),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Row(
                      children: [
                        _buildLegendItem(
                          const Color(0xFF10B981),

                          'Available',

                          Icons.check_circle,
                        ),

                        const SizedBox(width: 24),

                        _buildLegendItem(
                          const Color(0xFFEF4444),

                          'Occupied',

                          Icons.cancel,
                        ),
                      ],
                    ),

                    ElevatedButton.icon(
                      onPressed: () async {
                        // We need to fetch tables locally or pass them?

                        // We can't access snapshot data here directly.

                        // We should fetch latest specific for print.

                        final tables = await _supabaseService.client
                            .from('tables')
                            .select()
                            .eq('establishment_id', widget.establishmentId)
                            .order('table_number');

                        final List<Map<String, dynamic>> tableList =
                            List<Map<String, dynamic>>.from(tables);

                        if (tableList.isNotEmpty) {
                          _downloadQrCodes(tableList);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No tables found')),
                          );
                        }
                      },

                      icon: const Icon(Icons.qr_code),

                      label: const Text('Download QR Codes'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),

                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tables Grid
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabaseService.client
                  .from('tables')
                  .stream(primaryKey: ['id'])
                  .eq('establishment_id', widget.establishmentId)
                  .order('table_number'),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF10B981),
                      ),
                    ),
                  );
                }

                final tables = snapshot.data!;

                if (tables.isEmpty) {
                  return _buildEmptyState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),

                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 800
                        ? 4
                        : 2,

                    crossAxisSpacing: 16,

                    mainAxisSpacing: 16,

                    childAspectRatio: 1.1,
                  ),

                  itemCount: tables.length,

                  itemBuilder: (context, index) {
                    final table = tables[index];

                    final isOccupied = table['is_available'] == false;

                    return _buildTableCard(table, isOccupied);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
            'Error Loading Tables',

            style: TextStyle(
              fontSize: 18,

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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 100,

            height: 100,

            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),

              borderRadius: BorderRadius.circular(20),
            ),

            child: Icon(
              Icons.table_restaurant,

              size: 50,

              color: const Color(0xFF10B981),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'No Tables Configured',

            style: TextStyle(
              fontSize: 18,

              fontWeight: FontWeight.bold,

              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Add tables to your establishment to get started',

            style: TextStyle(
              fontSize: 14,

              color: const Color(0xFF6B7280).withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,

          height: 28,

          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),

            borderRadius: BorderRadius.circular(8),
          ),

          child: Icon(icon, size: 16, color: color),
        ),

        const SizedBox(width: 10),

        Text(
          label,

          style: const TextStyle(
            fontSize: 14,

            fontWeight: FontWeight.w600,

            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table, bool isOccupied) {
    final tableNumber = table['table_number'] ?? 'N/A';

    final capacity = table['capacity'] ?? 0;

    return GestureDetector(
      onTap: () {
        // Future: show active orders / session details
      },

      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: isOccupied
                ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                : const Color(0xFF10B981).withValues(alpha: 0.2),

            width: 2,
          ),

          boxShadow: [
            BoxShadow(
              color: isOccupied
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                  : const Color(0xFF10B981).withValues(alpha: 0.1),

              blurRadius: 12,

              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            // Status Indicator Circle
            Container(
              width: 70,

              height: 70,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: LinearGradient(
                  colors: isOccupied
                      ? [
                          const Color(0xFFEF4444).withValues(alpha: 0.2),

                          const Color(0xFFEF4444).withValues(alpha: 0.05),
                        ]
                      : [
                          const Color(0xFF10B981).withValues(alpha: 0.2),

                          const Color(0xFF10B981).withValues(alpha: 0.05),
                        ],
                ),

                boxShadow: [
                  BoxShadow(
                    color: isOccupied
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.15),

                    blurRadius: 8,
                  ),
                ],
              ),

              child: Icon(
                isOccupied ? Icons.table_restaurant : Icons.table_restaurant,

                size: 36,

                color: isOccupied
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
            ),

            const SizedBox(height: 12),

            // Table Number
            Text(
              'Table $tableNumber',

              style: TextStyle(
                fontSize: 18,

                fontWeight: FontWeight.bold,

                color: const Color(0xFF1F2937),
              ),
            ),

            const SizedBox(height: 4),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

              decoration: BoxDecoration(
                color: isOccupied
                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                    : const Color(0xFF10B981).withValues(alpha: 0.1),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Text(
                isOccupied ? 'Occupied' : 'Available',

                style: TextStyle(
                  fontSize: 12,

                  fontWeight: FontWeight.w600,

                  color: isOccupied
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Capacity
            if (capacity > 0)
              Text(
                'Capacity: $capacity',

                style: TextStyle(
                  fontSize: 11,

                  color: const Color(0xFF6B7280).withValues(alpha: 0.8),

                  fontWeight: FontWeight.w500,
                ),
              ),

            // Upcoming Reservation
            if (_upcomingReservations.containsKey(table['id']))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,

                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      const Icon(
                        Icons.access_time,

                        size: 12,

                        color: Colors.blue,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        'Rsrvd: ${_upcomingReservations[table['id']]}',

                        style: const TextStyle(
                          fontSize: 11,

                          fontWeight: FontWeight.bold,

                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Mark Available Button
            if (isOccupied) ...[
              const SizedBox(height: 10),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,

                    vertical: 6,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),

                  elevation: 0,
                ),

                onPressed: () {
                  _markTableAvailable(table['id'] as String);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Table $tableNumber marked as available'),

                      backgroundColor: const Color(0xFF10B981),

                      duration: const Duration(seconds: 2),
                    ),
                  );
                },

                child: const Text(
                  'Mark Free',

                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
