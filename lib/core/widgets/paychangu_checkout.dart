import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PayChanguCheckout extends StatefulWidget {
  final String checkoutUrl;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final VoidCallback onError;

  const PayChanguCheckout({
    super.key,
    required this.checkoutUrl,
    required this.onSuccess,
    required this.onCancel,
    required this.onError,
  });

  @override
  State<PayChanguCheckout> createState() => _PayChanguCheckoutState();
}

class _PayChanguCheckoutState extends State<PayChanguCheckout> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // WEB: Use redirect (Same Tab) because payment gateways often block iframes (X-Frame-Options)
      _launchWebPayment();
    } else {
      // MOBILE: Use in-app WebView
      _initializeMobileWebView();
    }
  }

  Future<void> _launchWebPayment() async {
    final uri = Uri.parse(widget.checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode
            .platformDefault, // Opens in same tab (replaces current page)
        webOnlyWindowName: '_self', // Explicitly target same window
      );
      // We don't pop here because the page will unload.
      // When the user returns, the App/Router state handles the result.
    } else {
      widget.onError();
      if (mounted) Navigator.pop(context);
    }
  }

  void _initializeMobileWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint("PayChangu URL: $url");

            // Detect success
            if (url.contains("success") || url.contains("paid")) {
              debugPrint("DEBUG: PayChangu success URL detected: $url");
              widget.onSuccess();
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // Detect cancel
            if (url.contains("cancel") || url.contains("failed")) {
              widget.onCancel();
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // Detect error
            if (url.contains("error")) {
              widget.onError();
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    // Web Layout
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Redirecting to PayChangu..."),
            ],
          ),
        ),
      );
    }

    // Mobile Layout
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Payment"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
