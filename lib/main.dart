import 'package:dinetrack/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'core/services/supabase_service.dart';
import 'core/routing/role_router.dart';
import 'flavors/customer/screens/customer_navigation.dart';

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
        final session = authState?.session;

        // If user is not authenticated
        if (session == null) {
          return LandingPage(pendingEstablishmentId: _pendingEstablishmentId);
        }

        // User is authenticated - check for deep link
        if (_pendingEstablishmentId != null) {
          // Navigate to restaurant after a frame to avoid build-time navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => CustomerNavigation(
                    establishmentId: _pendingEstablishmentId!,
                  ),
                ),
              );
            }
          });
        }

        return RoleBasedRouter(userId: session.user.id);
      },
    );
  }
}
