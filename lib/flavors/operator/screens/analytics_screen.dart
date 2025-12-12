import 'package:flutter/material.dart';
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

  // All Time Stats
  double _totalSales = 0;
  int _totalOrders = 0;
  double _averageOrderValue = 0;

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

      // 1. Fetch ALL paid orders for sales calculation
      final ordersResponse = await _supabaseService.client
          .from('orders')
          .select('total_amount, id')
          .eq('establishment_id', widget.establishmentId)
          .eq('payment_status', 'paid');

      double sales = 0;
      int count = 0;

      for (var order in ordersResponse) {
        sales += ((order['total_amount'] ?? 0) as num).toDouble();
        count++;
      }

      if (mounted) {
        setState(() {
          _totalSales = sales;
          _totalOrders = count;
          _averageOrderValue = count > 0 ? sales / count : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Analytics (All Time)',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 32),

          // KPIs Row
          Row(
            children: [
              _buildStatCard(
                'Total Revenue',
                'MK${_totalSales.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Total Orders',
                _totalOrders.toString(),
                Icons.shopping_bag,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Avg. Order Value',
                'MK${_averageOrderValue.toStringAsFixed(2)}',
                Icons.analytics,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 48),

          Center(
            child: Text(
              'More detailed charts coming soon...',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
