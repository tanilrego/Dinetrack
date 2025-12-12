import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'core/services/auth_service.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _isScanning = true;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String? _parseIdFromCode(String code) {
    // Handle full URL: https://dinetrack.com/#/restaurant/123
    // Handle deep link strategy: #/restaurant/123
    // Handle raw ID: 123
    try {
      if (code.contains('/restaurant/')) {
        // If it's a URL, pathSegments might work depending on format
        // But often QR codes are just string dumps.
        // Let's use simple string splitting for robustness with hash routing
        final parts = code.split('/restaurant/');
        if (parts.length > 1) {
          // Take the part after /restaurant/ and clean it (remove ?query=...)
          String idPart = parts.last;
          if (idPart.contains('?')) {
            idPart = idPart.split('?').first;
          }
          if (idPart.contains('#')) {
            // unlikely if we split by /restaurant/ which usually comes after hash,
            // but strictly speaking, hash comes first in flutter web unless standard path strategy
          }
          return idPart;
        }
      }
      // Assuming it's just the ID if no URL structure found
      return code;
    } catch (e) {
      return null;
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        final String? establishmentId = _parseIdFromCode(code);

        if (establishmentId == null) continue;

        // Stop scanning
        setState(() => _isScanning = false);

        // STRICT AUTH FLOW:
        // Set ID in AuthService (backup)
        AuthService.pendingEstablishmentId = establishmentId;

        // Removed signOut here because it causes AuthGate to rebuild and might unmount LandingPage
        // before we can process the result.
        // LandingPage handles the auth state anyway (it is the unauthenticated view).

        // Pop with result so LandingPage can handle it

        // Pop with result so LandingPage can handle it
        if (mounted) {
          Navigator.of(context).pop(establishmentId);
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Moved correctly to Scaffold
      appBar: AppBar(
        title: const Text('Scan Restaurant QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Torch Button
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              if (state.torchState == TorchState.off) {
                return IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.flash_off, color: Colors.grey),
                  iconSize: 32.0,
                  onPressed: () => controller.toggleTorch(),
                );
              } else {
                return IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.flash_on, color: Colors.yellow),
                  iconSize: 32.0,
                  onPressed: () => controller.toggleTorch(),
                );
              }
            },
          ),
          // Camera Switch Button
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              if (state.cameraDirection == CameraFacing.front) {
                return IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.camera_front),
                  iconSize: 32.0,
                  onPressed: () => controller.switchCamera(),
                );
              } else {
                return IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.camera_rear),
                  iconSize: 32.0,
                  onPressed: () => controller.switchCamera(),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          // Overlay for the scan area
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: const Color(0xFF4F46E5),
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          // Instructions text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align QR code within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Overlay Shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    // Removed unused variables: width, borderWidthSize, height
    final borderOffset = borderWidth / 2;
    final userScreenWidth = rect.width;
    final userScreenHeight = rect.height;

    final double cutOutWidth = cutOutSize < userScreenWidth
        ? cutOutSize
        : userScreenWidth - borderOffset;
    final double cutOutHeight = cutOutSize < userScreenHeight
        ? cutOutSize
        : userScreenHeight - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Removed unused: boxPaint

    final cutOutRect = Rect.fromLTWH(
      rect.left + userScreenWidth / 2 - cutOutWidth / 2 + borderOffset,
      rect.top +
          userScreenHeight / 2 -
          cutOutHeight / 2 -
          cutOutBottomOffset +
          borderOffset,
      cutOutWidth - borderWidth,
      cutOutHeight - borderWidth,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final double x = cutOutRect.left - borderWidth / 2;
    final double y = cutOutRect.top - borderWidth / 2;
    final double w = cutOutRect.width + borderWidth;
    final double h = cutOutRect.height + borderWidth;

    // Top left
    canvas.drawPath(
      Path()
        ..moveTo(x, y + borderLength)
        ..lineTo(x, y + borderRadius)
        ..arcToPoint(
          Offset(x + borderRadius, y),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(x + borderLength, y),
      borderPaint,
    );

    // Top right
    canvas.drawPath(
      Path()
        ..moveTo(x + w - borderLength, y)
        ..lineTo(x + w - borderRadius, y)
        ..arcToPoint(
          Offset(x + w, y + borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(x + w, y + borderLength),
      borderPaint,
    );

    // Bottom right
    canvas.drawPath(
      Path()
        ..moveTo(x + w, y + h - borderLength)
        ..lineTo(x + w, y + h - borderRadius)
        ..arcToPoint(
          Offset(x + w - borderRadius, y + h),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(x + w - borderLength, y + h),
      borderPaint,
    );

    // Bottom left
    canvas.drawPath(
      Path()
        ..moveTo(x + borderLength, y + h)
        ..lineTo(x + borderRadius, y + h)
        ..arcToPoint(
          Offset(x, y + h - borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(x, y + h - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
