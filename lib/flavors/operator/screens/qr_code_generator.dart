// lib/flavors/operator/screens/qr_code_generator.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/supabase_service.dart';
import 'dart:io';

class QrCodeGeneratorScreen extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onQRCodeGenerated;

  const QrCodeGeneratorScreen({
    Key? key,
    required this.establishmentId,
    this.isDarkMode = false,
    this.onBackToDashboard,
    this.onQRCodeGenerated,
  }) : super(key: key);

  @override
  _QrCodeGeneratorScreenState createState() => _QrCodeGeneratorScreenState();
}

class _QrCodeGeneratorScreenState extends State<QrCodeGeneratorScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _tables = [];
  Map<String, dynamic>? _selectedTable;
  Map<String, dynamic>? _selectedEstablishment;
  bool _isLoading = true;
  bool _generatingQr = false;
  String? _generatedQrData;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadEstablishmentAndTables();
  }

  Future<void> _loadEstablishmentAndTables() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user != null) {
        final establishments = await _supabaseService.client
            .from('establishments')
            .select()
            .eq('id', widget.establishmentId)
            .eq('is_active', true);

        if (establishments.isNotEmpty && establishments[0] != null) {
          _selectedEstablishment = establishments.first as Map<String, dynamic>;

          final tables = await _supabaseService.client
              .from('tables')
              .select()
              .eq('establishment_id', widget.establishmentId)
              .order('table_number');

          setState(() {
            _tables = List<Map<String, dynamic>>.from(tables);
            _isLoading = false;
          });
        } else {
          final operatorEstablishments = await _supabaseService.client
              .from('establishments')
              .select()
              .eq('owner_id', user.id)
              .eq('is_active', true);

          if (operatorEstablishments.isNotEmpty && operatorEstablishments[0] != null) {
            _selectedEstablishment = operatorEstablishments.first as Map<String, dynamic>;

            final establishmentId = _selectedEstablishment?['id'];
            if (establishmentId != null) {
              final tables = await _supabaseService.client
                  .from('tables')
                  .select()
                  .eq('establishment_id', establishmentId)
                  .order('table_number');

              setState(() {
                _tables = List<Map<String, dynamic>>.from(tables);
                _isLoading = false;
              });
            } else {
              _setEmptyState();
            }
          } else {
            _setEmptyState();
          }
        }
      } else {
        _setEmptyState();
      }
    } catch (e) {
      print('Error loading data: $e');
      _setEmptyState();
    }
  }

  void _setEmptyState() {
    setState(() {
      _selectedEstablishment = null;
      _tables = [];
      _isLoading = false;
    });
  }

  Future<void> _generateAndSaveQrCode() async {
    if (_selectedTable == null || _selectedEstablishment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a table first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _generatingQr = true;
    });

    try {
      final establishmentId = _selectedEstablishment?['id'];
      final tableId = _selectedTable?['id'];
      final tableNumber = _selectedTable?['table_number'];
      final establishmentName = _selectedEstablishment?['name'];

      if (establishmentId == null || tableId == null) {
        throw Exception('Missing required data');
      }

      final qrData = {
        'establishmentId': establishmentId,
        'tableId': tableId,
        'tableNumber': tableNumber,
        'establishmentName': establishmentName,
      };

      final jsonString = jsonEncode(qrData);
      final encodedData = base64Encode(utf8.encode(jsonString));

      await _supabaseService.client
          .from('tables')
          .update({
        'qr_code': encodedData,
        'qr_code_data': jsonString,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', tableId);

      setState(() {
        _generatedQrData = encodedData;
        _generatingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code generated and saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onQRCodeGenerated?.call();
    } catch (e) {
      print('Error generating QR code: $e');
      setState(() {
        _generatingQr = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAsImage() async {
    if (_generatedQrData == null || _selectedTable == null) return;

    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData?.buffer.asUint8List();

      if (buffer != null) {
        final time = DateTime.now().millisecondsSinceEpoch;
        final tableNumber = _selectedTable?['table_number'] ?? 'unknown';
        final name = 'qr_table_${tableNumber}_$time.png';

        final result = await ImageGallerySaver.saveImage(buffer, name: name);

        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR Code saved to gallery!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_generatedQrData == null || _selectedTable == null || _selectedEstablishment == null) return;

    try {
      final pdf = pw.Document();

      final establishmentName = _selectedEstablishment?['name'] ?? 'Unknown Establishment';
      final tableNumber = _selectedTable?['table_number']?.toString() ?? 'Unknown';
      final tableLabel = _selectedTable?['label']?.toString() ?? '';
      final capacity = _selectedTable?['capacity']?.toString() ?? '0';
      final establishmentType = _selectedEstablishment?['type']?.toString() ?? '';
      final establishmentAddress = _selectedEstablishment?['address']?.toString() ?? '';

      // Add QR Code page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Table QR Code',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Establishment: $establishmentName'),
                if (establishmentType.isNotEmpty) pw.Text('Type: $establishmentType'),
                if (establishmentAddress.isNotEmpty) pw.Text('Address: $establishmentAddress'),
                pw.Text('Table Number: $tableNumber'),
                if (tableLabel.isNotEmpty) pw.Text('Table Label: $tableLabel'),
                pw.Text('Capacity: $capacity people'),
                pw.SizedBox(height: 20),
                pw.Text('Scan this QR code to order:'),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'QR Code Image Placeholder',
                    style: pw.TextStyle(fontSize: 16),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Instructions:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('1. Open DineConnect app'),
                pw.Text('2. Tap "Scan QR"'),
                pw.Text('3. Point camera at this code'),
                pw.Text('4. Start ordering!'),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/table_${tableNumber}_qr.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code for Table $tableNumber - $establishmentName',
      );
    } catch (e) {
      print('Error generating PDF: $e');
    }
  }

  Future<void> _shareQrCode() async {
    if (_generatedQrData == null || _selectedTable == null || _selectedEstablishment == null) return;

    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData?.buffer.asUint8List();

      if (buffer != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/qr_code.png');
        await file.writeAsBytes(buffer);

        final tableNumber = _selectedTable?['table_number']?.toString() ?? 'Unknown';
        final establishmentName = _selectedEstablishment?['name'] ?? 'Unknown Establishment';

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Scan this QR code for Table $tableNumber at $establishmentName',
        );
      }
    } catch (e) {
      print('Error sharing QR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Table QR Codes'),
        leading: widget.onBackToDashboard != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToDashboard,
        )
            : null,
        backgroundColor: widget.isDarkMode ? Colors.grey[900] : null,
        actions: [
          if (_generatedQrData != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareQrCode,
              tooltip: 'Share QR Code',
            ),
        ],
      ),
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedEstablishment == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(height: 20),
            Text(
              'No establishment found',
              style: TextStyle(
                fontSize: 18,
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadEstablishmentAndTables,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53B175),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedEstablishment?['name']?.toString() ?? 'No Name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type: ${_selectedEstablishment?['type']?.toString() ?? 'Not specified'}',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (_selectedEstablishment?['address'] != null)
                      Text(
                        'Address: ${_selectedEstablishment?['address']?.toString() ?? ''}',
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Table',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedTable,
                      decoration: InputDecoration(
                        labelText: 'Choose a table',
                        labelStyle: TextStyle(
                          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        filled: widget.isDarkMode,
                        fillColor: widget.isDarkMode ? const Color(0xFF333333) : null,
                      ),
                      dropdownColor: widget.isDarkMode ? const Color(0xFF333333) : Colors.white,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      items: _tables.map((table) {
                        return DropdownMenuItem(
                          value: table,
                          child: Text(
                            'Table ${table['table_number']} - ${table['label']} (${table['capacity']} seats)',
                            style: TextStyle(
                              color: widget.isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTable = value;
                          _generatedQrData = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _generatingQr ? null : _generateAndSaveQrCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF53B175),
              ),
              child: _generatingQr
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : const Text(
                'Generate QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (_generatedQrData != null && _selectedTable != null && _selectedEstablishment != null) ...[
              const SizedBox(height: 30),
              Text(
                'Generated QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),

              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                            data: _generatedQrData!,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Table ${_selectedTable?['table_number']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      if (_selectedTable?['label'] != null)
                        Text(
                          _selectedTable?['label']?.toString() ?? '',
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        'Scan to order at ${_selectedEstablishment?['name']}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveAsImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Save as Image'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: widget.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generateAndSharePdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Save as PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: widget.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _printQrCode,
                icon: const Icon(Icons.print),
                label: const Text('Print QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: widget.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                  foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],

            const SizedBox(height: 40),

            if (_tables.isNotEmpty) ...[
              Text(
                'Existing Table QR Codes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              ..._tables.where((table) => table['qr_code'] != null).map((table) {
                final qrCode = table['qr_code']?.toString() ?? '';
                final displayCode = qrCode.length > 20 ? '${qrCode.substring(0, 20)}...' : qrCode;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      Icons.table_restaurant,
                      color: widget.isDarkMode ? const Color(0xFF53B175) : const Color(0xFF53B175),
                    ),
                    title: Text(
                      'Table ${table['table_number']} - ${table['label']}',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'QR Code: $displayCode',
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: const Icon(Icons.qr_code),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _printQrCode() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print QR Code'),
        content: const Text('Connect to a printer to print this QR code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printing feature requires printer setup'),
                ),
              );
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }
}