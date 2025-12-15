import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;

  const AnalyticsScreen({
    super.key,
    required this.establishmentId,
    required this.isDarkMode,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;

  // Stats
  double _totalSales = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;
  int _totalItems = 0;

  // Orders data
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      if (widget.establishmentId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch all paid orders with their items
      final ordersResponse = await _supabaseService.client
          .from('orders')
          .select(
            'id, total_amount, payment_status, created_at, table_no, status, order_items(quantity, unit_price, menu_items(name))',
          )
          .eq('establishment_id', widget.establishmentId)
          .eq('payment_status', 'paid')
          .neq('table_no', 0)
          .order('created_at', ascending: false);

      double sales = 0;
      int count = 0;
      int itemCount = 0;
      List<Map<String, dynamic>> parsedOrders = [];

      for (var order in ordersResponse) {
        sales += ((order['total_amount'] ?? 0) as num).toDouble();
        count++;

        // Count items
        final items = order['order_items'] as List<dynamic>? ?? [];
        for (var item in items) {
          itemCount += (item['quantity'] ?? 0) as int;
        }

        parsedOrders.add({
          'id': order['id'],
          'total_amount': order['total_amount'],
          'created_at': order['created_at'],
          'table_no': order['table_no'],
          'status': order['status'],
          'items': items,
        });
      }

      if (mounted) {
        setState(() {
          _totalSales = sales;
          _totalOrders = count;
          _averageOrderValue = count > 0 ? sales / count : 0;
          _totalItems = itemCount;
          _orders = parsedOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Business Analytics',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode
                    ? Colors.white
                    : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All Time Performance',
              style: TextStyle(
                fontSize: 14,
                color: widget.isDarkMode
                    ? Colors.grey[400]
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 28),

            // KPIs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard(
                    'Total Revenue',
                    'MK${_totalSales.toStringAsFixed(2)}',
                    Icons.attach_money,
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Total Orders',
                    _totalOrders.toString(),
                    Icons.shopping_bag,
                    const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Items Sold',
                    _totalItems.toString(),
                    Icons.inventory_2,
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Avg Order',
                    'MK${_averageOrderValue.toStringAsFixed(2)}',
                    Icons.analytics,
                    const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Orders Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF1F2937),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadPDF,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Orders Table/List
            if (_orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 60,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(_orders[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: widget.isDarkMode
                      ? Colors.grey[400]
                      : const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final tableNo = order['table_no'] ?? 'N/A';
    final totalAmount = order['total_amount'] ?? 0;
    final createdAt = _formatDate(order['created_at'] as String?);
    final status = order['status'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table $tableNo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode
                            ? Colors.grey[400]
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MK${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.isEmpty
                  ? [
                      Text(
                        'No items',
                        style: TextStyle(
                          color: widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ]
                  : List.generate(items.length, (index) {
                      final item = items[index];
                      final itemName = item['menu_items'] != null
                          ? item['menu_items']['name'] ?? 'Unknown'
                          : 'Unknown Item';
                      final quantity = item['quantity'] ?? 0;
                      final unitPrice = item['unit_price'] ?? 0;
                      final lineTotal = (quantity * unitPrice).toDouble();

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < items.length - 1 ? 12 : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$quantity x MK${unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'MK${lineTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download feature coming soon!'),
        backgroundColor: Color(0xFF4F46E5),
        duration: Duration(seconds: 2),
      ),
    );

    // TODO: Implement PDF generation using pdf package
    // Example: Use pdf package to generate PDF with orders data
    // Then use share_plus or downloads package to save/share the PDF
  }
}
