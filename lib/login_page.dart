import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dinetrack/flavors/customer/screens/registration.dart';

import 'core/services/supabase_service.dart';
import 'core/routing/role_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  Future<void> _loginWithEmailPassword() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      // 1. Login user
      final response = await SupabaseService().client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;

      if (user == null) {
        setState(() => _errorMessage = "Login failed: no user returned.");
        return;
      }

      // print("LOGGED IN USER: ${user.id}");

      // 2. Check if user metadata already exists
      final existing = await SupabaseService().client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // print("User metadata does NOT exist — inserting new row...");

        // 3. Insert metadata on first login after email verification
        await SupabaseService().client
            .from('users')
            .insert({
              'id': user.id,
              'email': user.email,
              'full_name': '', // optional: fill using saved controllers
              'phone': '',
              'user_type': 'customer',
              'dine_coins_balance': 0,
            })
            .select()
            .single();

        // print("USER METADATA INSERTED: $insertResponse");
      } else {
        // print("User metadata already exists — skipping insert.");
      }

      // 🟢 Navigate to RoleBasedRouter to handle direction based on user type
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => RoleBasedRouter(userId: user.id)),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Guest login removed from here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// LOGO
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    Image.asset('assets/images/logo.png', height: 160),
                    const SizedBox(height: 8),
                    const Text(
                      "DINETRACK",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              /// LOGIN CARD
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Welcome",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 25),

                      /// EMAIL FIELD
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),

                      /// PASSWORD FIELD
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 15),

                      /// LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _loginWithEmailPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _busy
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      /// REGISTER TEXT LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                            child: const Text("Register"),
                          ),
                        ],
                      ),

                      /// ERROR MESSAGE
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              /// ADDITIONAL INFO
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  "Contact administrator for operator/supervisor accounts",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
