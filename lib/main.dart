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
    if (hash.isEmpty) return null;

    // Parse hash like #/restaurant/{establishment_id}
    // Handles simple ID or ID followed by query params (e.g. ?status=success)
    final regex = RegExp(r'#/restaurant/([a-f0-9-]+)', caseSensitive: false);
    final match = regex.firstMatch(hash);

    if (match != null && match.groupCount >= 1) {
      return match.group(1);
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

  @override
  void initState() {
    super.initState();
    // Check for deep link on initialization
    _pendingEstablishmentId = _getEstablishmentIdFromUrl();

    // Safety Net: Re-hydrate the static persistence if we found an ID in the URL
    // This ensures that deep down in the app, AuthService knows where we aim to be.
    if (_pendingEstablishmentId != null) {
      AuthService.pendingEstablishmentId = _pendingEstablishmentId;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        if (event == AuthChangeEvent.signedOut) {
          // We schedule this to avoid modifying state during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pendingEstablishmentId != null) {
              setState(() {
                _pendingEstablishmentId = null;
              });
            }
          });
        }

        if (session == null) {
          return LandingPage(pendingEstablishmentId: _pendingEstablishmentId);
        }

        return RoleBasedRouter(
          userId: session.user.id,
          pendingEstablishmentId: _pendingEstablishmentId,
        );
      },
    );
  }
}
