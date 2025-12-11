import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for platform view registry on web if needed, but handled by plugin mostly.

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
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    // Initialize WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;

            debugPrint("PayChangu URL: $url");

            // Detect success
            if (url.contains("success") || url.contains("paid")) {
              widget.onSuccess();
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // Detect cancel
            if (url.contains("cancel") || url.contains("failed")) {
              widget.onCancel();
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // Detect error
            if (url.contains("error")) {
              widget.onError();
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
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
          WebViewWidget(controller: _controller),

          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
