import 'package:dinetrack/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'core/services/supabase_service.dart';
import 'core/services/auth_service.dart';
import 'core/routing/role_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect environment
  const env = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'production');

  // Load correct env file
  await dotenv.load(fileName: "assets/env/.env.$env");

  // Initialize Supabase using ENV values
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize WebView for Web
  if (kIsWeb) {
    WebViewPlatform.instance = WebWebViewPlatform();
  }

  // Initialize DineTrack services
  await SupabaseService().postInit();

  runApp(const DineTrackApp());
}

class DineTrackApp extends StatelessWidget {
  const DineTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineTrack',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Extract establishment ID from URL hash (e.g., #/restaurant/{id})
String? _getEstablishmentIdFromUrl() {
  if (!kIsWeb) return null;

  try {
    final hash = html.window.location.hash;
    debugPrint('DEBUG: Current URL Hash: $hash');

    if (hash.isEmpty) return null;

    // Parse hash like #/restaurant/{establishment_id}
    final regex = RegExp(r'#/restaurant/([a-f0-9-]+)', caseSensitive: false);
    final match = regex.firstMatch(hash);

    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      debugPrint('DEBUG: Extracted Establishment ID: $id');

      // If we successfully got an ID from URL, clear any stale pending payment ID
      // from storage to avoid confusion later.
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('pending_payment_restaurant_id');
      });

      return id;
    } else {
      debugPrint('DEBUG: No ID match found in hash');
    }
  } catch (e) {
    debugPrint('Error parsing URL: $e');
  }

  return null;
}

/// AUTH GATE — checks Supabase session changes and handles deep links
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _pendingEstablishmentId;
  bool _isRestoringSession =
      kIsWeb; // Only block on Web where storage check is needed

  @override
  void initState() {
    super.initState();
    _initApp();

    // Listen for URL changes (e.g. scanning a new QR code while app is open)
    if (kIsWeb) {
      html.window.onHashChange.listen((_) {
        _handleUrlChange();
      });
    }
  }

  void _handleUrlChange() {
    final newId = _getEstablishmentIdFromUrl();
    if (newId != null && newId != _pendingEstablishmentId) {
      debugPrint('DEBUG: Detected URL change to establishment: $newId');
      setState(() {
        _pendingEstablishmentId = newId;
        AuthService.pendingEstablishmentId = newId;
      });

      // If user is already logged in, we must force sign out so they land on
      // the LandingPage which handles the "View Details / Login" popup for the new restaurant.
      if (newId != null) {
        Supabase.instance.client.auth.signOut();
      }
    }
  }

  Future<void> _initApp() async {
    // 1. Try to get ID from URL first
    String? id = _getEstablishmentIdFromUrl();

    // 2. If URL failed (e.g. hash stripped by PayChangu), check Storage (Web only)
    if (id == null && kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('pending_payment_restaurant_id');
    }

    // 3. Set state and unblock
    if (mounted) {
      setState(() {
        if (id != null) {
          AuthService.pendingEstablishmentId = id;
          _pendingEstablishmentId = id;
        }
        _isRestoringSession = false; // Done checking
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block rendering until we've checked storage to prevent RoleBasedRouter
    // from seeing "No ID" and auto-logging out the user prematurely.
    if (_isRestoringSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final authState = snapshot.data;
        final event = authState?.event;
        final session = authState?.session;

        // CRITICAL FIX: If user signs out, we must clear the pending ID
        // to prevent LandingPage from auto-opening the restaurant dialog again.
        // CHECK: Only clear if logic wasn't the one setting it (Manual Logout vs QR Scan)
        if (event == AuthChangeEvent.signedOut) {
          // We schedule this to avoid modifying state during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // If AuthService says it's null, it was a manual logout.
            if (AuthService.pendingEstablishmentId == null &&
                _pendingEstablishmentId != null) {
              setState(() {
                _pendingEstablishmentId = null;
              });
            }
          });
        }

        if (session == null) {
          return LandingPage(
            key: ValueKey(
              _pendingEstablishmentId,
            ), // Rebuild if ID changes to trigger popup
            pendingEstablishmentId: _pendingEstablishmentId,
          );
        }

        return RoleBasedRouter(
          userId: session.user.id,
          pendingEstablishmentId: _pendingEstablishmentId,
        );
      },
    );
  }
}
