import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayChanguCheckout extends StatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final VoidCallback onError;

  const PayChanguCheckout({
    super.key,
    required this.checkoutUrl,
    required this.paymentId,
    required this.onSuccess,
    required this.onCancel,
    required this.onError,
  });

  @override
  State<PayChanguCheckout> createState() => _PayChanguCheckoutState();
}

class _PayChanguCheckoutState extends State<PayChanguCheckout> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _handleWebPayment();
    } else {
      _initializeWebView();
    }
  }

  void _handleWebPayment() async {
    // Navigate to payment in the same window instead of opening new tab
    if (await canLaunchUrl(Uri.parse(widget.checkoutUrl))) {
      await launchUrl(
        Uri.parse(widget.checkoutUrl),
        mode: LaunchMode.platformDefault, // Use same window/tab
      );
      // The payment page will redirect back to the restaurant via return URL
      // Close this checkout screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      widget.onError();
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _handleUrlChange(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _handleUrlChange(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            // Don't error immediately on resource errors mostly, but log it
          },
          onNavigationRequest: (NavigationRequest request) {
            _handleUrlChange(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handleUrlChange(String url) {
    debugPrint('URL changed: $url');

    // Check for success/cancel patterns in URL
    if (url.contains('payment/success') || url.contains('status=success')) {
      widget.onSuccess();
    } else if (url.contains('payment/cancel') ||
        url.contains('status=cancel')) {
      widget.onCancel();
    } else if (url.contains('payment/error') || url.contains('status=error')) {
      widget.onError();
    }
  }

  Future<void> _openInBrowser() async {
    if (await canLaunchUrl(Uri.parse(widget.checkoutUrl))) {
      await launchUrl(
        Uri.parse(widget.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, we navigate to payment in the same window
      // Show processing screen while navigation happens
      return Scaffold(
        appBar: AppBar(title: const Text('Processing Payment')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Redirecting to payment gateway...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
