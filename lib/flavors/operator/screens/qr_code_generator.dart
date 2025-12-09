import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

class QRCodeGeneratorPage extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onQRCodeGenerated;

  const QRCodeGeneratorPage({
    super.key,
    required this.establishmentId,
    required this.isDarkMode,
    this.onBackToDashboard,
    this.onQRCodeGenerated,
  });

  @override
  State<QRCodeGeneratorPage> createState() => _QRCodeGeneratorPageState();
}

class _QRCodeGeneratorPageState extends State<QRCodeGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _tableLabelController = TextEditingController();
  final _capacityController = TextEditingController();

  int _tableNumber = 1;
  bool _isLoading = false;
  List<Map<String, dynamic>> _generatedQRCodes = [];
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadNextTableNumber();
    _loadExistingQRCodes();
  }

  @override
  void dispose() {
    _tableLabelController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadNextTableNumber() async {
    try {
      final response = await _supabase
          .from('tables')
          .select('table_number')
          .eq('establishment_id', widget.establishmentId)
          .order('table_number', ascending: true);

      if (response.isNotEmpty) {
        final maxNumber = (response.last['table_number'] as int);
        setState(() {
          _tableNumber = maxNumber + 1;
        });
      }
    } catch (error) {
      // print('Error loading table number: $error');
    }
  }

  Future<void> _loadExistingQRCodes() async {
    if (widget.establishmentId.isEmpty) {
      // print('Cannot load QR codes: establishmentId is empty');
      return;
    }

    try {
      final response = await _supabase
          .from('tables')
          .select('*')
          .eq('establishment_id', widget.establishmentId)
          .order('created_at', ascending: false);

      setState(() {
        _generatedQRCodes = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (e) {
      // print('Error loading QR codes (Postgrest): ${e.message}');
      _showErrorDialog('Failed to load existing QR codes: ${e.message}');
    } catch (error) {
      // print('Error loading QR codes: $error');
    }
  }

  String _generateUniqueQRCode() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final uniqueCode = List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();

    return 'table-$_tableNumber-$uniqueCode';
  }

  String _generateQRCodeData(String qrCodeId) {
    // Production URL for deployed app
    return 'https://dinetrack-3hhc.onrender.com/#/restaurant/${widget.establishmentId}';
  }

  Future<void> _generateQRCode() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate establishment ID
    if (widget.establishmentId.isEmpty) {
      _showErrorDialog('Establishment ID is missing. Please try again.');
      return;
    }

    // Check if establishment ID looks like a UUID
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (!uuidRegex.hasMatch(widget.establishmentId)) {
      _showErrorDialog(
        'Invalid establishment ID format. Please contact support.',
      );
      // print('Invalid establishment ID format: ${widget.establishmentId}');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final qrCodeId = _generateUniqueQRCode();
      final qrCodeData = _generateQRCodeData(qrCodeId);

      // Insert into Supabase
      final response = await _supabase.from('tables').insert({
        'establishment_id': widget.establishmentId,
        'label': _tableLabelController.text.trim(),
        'table_number': _tableNumber,
        'qr_code': qrCodeId,
        'qr_code_data': qrCodeData,
        'capacity': int.tryParse(_capacityController.text) ?? 4,
        'is_available': true,
      }).select();

      if (response.isNotEmpty) {
        // Add to local list
        setState(() {
          _generatedQRCodes.insert(0, response[0]);
        });

        // Reset form
        _tableLabelController.clear();
        _capacityController.clear();

        // Increment table number for next
        setState(() {
          _tableNumber++;
        });

        // Call refresh callback if provided
        if (widget.onQRCodeGenerated != null) {
          widget.onQRCodeGenerated!();
        }

        // Show success message
        _showSuccessDialog(qrCodeId); // Now using the function!
      }
    } on PostgrestException catch (e) {
      // Handle Supabase-specific errors
      // print('PostgrestException: ${e.message}');
      // print('Details: ${e.details}');
      // print('Hint: ${e.hint}');
      _showErrorDialog('Database error: ${e.message}');
    } catch (error) {
      _showErrorDialog('Failed to generate QR code: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String qrCodeId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('QR code has been generated successfully!'),
            const SizedBox(height: 10),
            Text(
              'QR Code ID: $qrCodeId',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              'Table #${_tableNumber - 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(Map<String, dynamic> qrCode) async {
    // Implement QR code download/saving functionality
    // You can use packages like image_gallery_saver or share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download functionality coming soon!')),
    );
  }

  Widget _buildQRCodeCard(Map<String, dynamic> qrCode, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _showQRCodeDetails(qrCode, isDarkMode),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: qrCode['qr_code_data'] ?? '',
                version: QrVersions.auto,
                size: 104,
                backgroundColor: isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              qrCode['label'] ?? 'Table',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Text(
              'Table #${qrCode['table_number']}',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            Text(
              'Capacity: ${qrCode['capacity'] ?? 0}',
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (qrCode['is_available'] ?? false)
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (qrCode['is_available'] ?? false) ? 'Available' : 'Occupied',
                style: TextStyle(
                  fontSize: 10,
                  color: (qrCode['is_available'] ?? false)
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCodeDetails(Map<String, dynamic> qrCode, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'QR Code Details',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: qrCode['qr_code_data'] ?? '',
                    version: QrVersions.auto,
                    size: 150,
                    backgroundColor: isDarkMode
                        ? const Color(0xFF2A2A2A)
                        : Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Table Label:',
                qrCode['label'] ?? '',
                isDarkMode,
              ),
              _buildDetailRow(
                'Table Number:',
                '${qrCode['table_number']}',
                isDarkMode,
              ),
              _buildDetailRow(
                'QR Code ID:',
                qrCode['qr_code'] ?? '',
                isDarkMode,
              ),
              _buildDetailRow('Capacity:', '${qrCode['capacity']}', isDarkMode),
              _buildDetailRow(
                'Status:',
                (qrCode['is_available'] ?? false) ? 'Available' : 'Occupied',
                isDarkMode,
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR code to access the menu',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => _downloadQRCode(qrCode),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQRCodesState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No QR Codes Generated Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create QR codes for your tables to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateQRCode,
              icon: const Icon(Icons.add),
              label: const Text('Generate First QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button if needed
            Row(
              children: [
                if (widget.onBackToDashboard != null)
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    onPressed: widget.onBackToDashboard,
                  ),
                Expanded(
                  child: Center(
                    child: Text(
                      'DINETRACK',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                if (widget.onBackToDashboard != null)
                  const SizedBox(width: 48), // For spacing
              ],
            ),
            const SizedBox(height: 32),

            // Title
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'QR Code Generator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.black : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generation Form
            Card(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate New QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Table Label
                      TextFormField(
                        controller: _tableLabelController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Table Label',
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.grey.shade400 : null,
                          ),
                          border: const OutlineInputBorder(),
                          hintText: 'e.g., Table by Window, VIP Table',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey.shade500 : null,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a table label';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Capacity
                      TextFormField(
                        controller: _capacityController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Capacity',
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.grey.shade400 : null,
                          ),
                          border: const OutlineInputBorder(),
                          hintText: 'e.g., 4',
                          suffixText: 'people',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey.shade500 : null,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter capacity';
                          }
                          final capacity = int.tryParse(value);
                          if (capacity == null || capacity <= 0) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Next Table Number
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Next Table Number:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? Colors.black
                                    : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_tableNumber',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _generateQRCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.qr_code_2),
                          label: Text(
                            _isLoading ? 'Generating...' : 'Generate QR Code',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generated QR Codes List
            Text(
              'Generated QR Codes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            if (_generatedQRCodes.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: _generatedQRCodes.length,
                itemBuilder: (context, index) {
                  return _buildQRCodeCard(_generatedQRCodes[index], isDarkMode);
                },
              )
            else
              _buildEmptyQRCodesState(isDarkMode),
          ],
        ),
      ),
    );
  }
}
