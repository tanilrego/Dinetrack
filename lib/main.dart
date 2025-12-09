import 'package:dinetrack/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_service.dart';

import 'core/routing/role_router.dart';

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

/// AUTH GATE — checks Supabase session changes
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        if (session == null) {
          return const LandingPage();
        }

        return RoleBasedRouter(userId: session.user.id);
      },
    );
  }
}
