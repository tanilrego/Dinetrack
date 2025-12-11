import 'package:flutter/material.dart';
import 'package:dinetrack/login_page.dart';
import 'package:dinetrack/restaurant_registration_page.dart';
import 'package:dinetrack/qr_scanner_page.dart';
import 'package:dinetrack/flavors/customer/screens/registration.dart';
import 'package:dinetrack/flavors/customer/screens/customer_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_service.dart';
import 'core/services/auth_service.dart';
import 'core/widgets/restaurant_details_dialog.dart';
import 'core/widgets/sliding_image_animation.dart';

class LandingPage extends StatefulWidget {
  final String? pendingEstablishmentId;

  const LandingPage({super.key, this.pendingEstablishmentId});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _busy = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _restaurants = [];
  bool _loadingRestaurants = true;

  // Static variable to persist intended destination across auth rebuilds
  // Moved to AuthService.pendingEstablishmentId

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();

    // Check for pending navigation (from deep link OR internal redirect)
    final targetId =
        widget.pendingEstablishmentId ?? AuthService.pendingEstablishmentId;

    if (targetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait for restaurant data to be available if needed
        while (_loadingRestaurants) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (mounted) {
          final restaurant = _restaurants.firstWhere(
            (r) => r['id'] == targetId,
            orElse: () => {},
          );

          if (restaurant.isNotEmpty) {
            _openRestaurantDetails(restaurant);
          }
        }
      });
    }
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _loadingRestaurants = true);
    try {
      final response = await SupabaseService().client
          .from('establishments')
          .select('*, users!owner_id(email, profile_image_url)')
          .eq('is_active', true)
          .eq('supervisor_approved', true)
          .order('created_at', ascending: false);

      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(response).map((est) {
          final owner = est['users'];
          return {
            'id': est['id'],
            'name': est['name'],
            'type': est['type'],
            'address': est['address'],
            'phone': est['phone'],
            'description': est['description'],
            'email': owner != null ? owner['email'] : 'N/A',
            'image_url': owner != null ? owner['profile_image_url'] : null,
          };
        }).toList();
        _loadingRestaurants = false;
      });
    } catch (e) {
      setState(() {
        _loadingRestaurants = false;
        _errorMessage = 'Error loading restaurants: $e';
      });
    }
  }

  Future<void> _signInAsGuest(String? targetEstablishmentId) async {
    if (targetEstablishmentId != null) {
      AuthService.pendingEstablishmentId = targetEstablishmentId;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService().client.auth.signInWithPassword(
        email: 'guest@dinetrack.com',
        password: 'guest123456',
      );

      final user = response.user;

      if (user == null) {
        throw Exception("Guest login succeeded but user is null");
      }

      await SupabaseService().client.from("users").upsert({
        "id": user.id,
        "email": "guest@dinetrack.com",
        "full_name": "Guest User",
        "phone": "",
        "user_type": "customer",
        "dine_coins_balance": "0.00",
      });
    } catch (e) {
      setState(() => _errorMessage = "Guest login failed: $e");
      AuthService.pendingEstablishmentId = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavBar(context),
            _buildHeroSection(),
            _buildRestaurantsSection(),
            _buildFeaturesSection(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? _buildMobileNavBar(context)
          : _buildDesktopNavBar(context),
    );
  }

  Widget _buildDesktopNavBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'DT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'DineTrack',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Customer Sign Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RestaurantRegistrationPage(),
                  ),
                );
              },
              icon: const Icon(Icons.restaurant, size: 20),
              label: const Text('Restaurant Sign Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                _showLoginDialog(context, null);
              },
              icon: const Icon(Icons.login, size: 20),
              label: const Text('Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileNavBar(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'DT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DineTrack',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                _showMobileMenu(context);
              },
              icon: const Icon(Icons.menu, size: 28, color: Color(0xFF4F46E5)),
            ),
          ],
        ),
      ],
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Customer Sign Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestaurantRegistrationPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.restaurant),
                label: const Text('Restaurant Sign Up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showLoginDialog(context, null);
                },
                icon: const Icon(Icons.login),
                label: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context, String? targetEstablishmentId) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: isMobile ? double.infinity : 450,
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 60 : 70,
                  height: isMobile ? 60 : 70,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 24),
                Text(
                  'Login to DineTrack',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  'Choose your account type',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: const Color(0xFF6B7280).withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: isMobile ? 24 : 32),
                _buildLoginOption(
                  context,
                  title: 'Customer Login',
                  icon: Icons.person,
                  color: const Color(0xFF4F46E5),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildLoginOption(
                  context,
                  title: 'Restaurant Login',
                  icon: Icons.restaurant,
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildLoginOption(
                  context,
                  title: 'Guest Login',
                  icon: Icons.person_outline,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    _signInAsGuest(targetEstablishmentId);
                  },
                ),
                const SizedBox(height: 16),
                _buildLoginOption(
                  context,
                  title: 'Supervisor Login',
                  icon: Icons.admin_panel_settings,
                  color: const Color(0xFFEA580C), // Orange color for supervisor
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                ),
                SizedBox(height: isMobile ? 16 : 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccessDialog(BuildContext context, String establishmentId) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320), // Make it smaller
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Login Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please login to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to login - deep link handled by URL on web
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navigate to registration - deep link handled by URL on web
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                      ),
                      child: const Text('Register'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Guest Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () async {
                        // Sign in as guest
                        Navigator.pop(context);
                        await _signInAsGuest(establishmentId);
                      },
                      child: const Text('Continue as Guest'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: isMobile ? 24 : 28, color: color),
            SizedBox(width: isMobile ? 12 : 16),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 60 : 100,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4F46E5).withValues(alpha: 0.05),
                const Color(0xFF10B981).withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '✨ Start Your Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 20 : 28),
              Text(
                isMobile ? 'Welcome to\nDineTrack' : 'Welcome to DineTrack',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 32 : 48,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 650,
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                child: Text(
                  'Simplifying restaurant management for the modern dining experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    color: const Color(0xFF6B7280).withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 24 : 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerPage()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 40 : 60),
              if (!isMobile)
                Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  height: 550,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                        blurRadius: 60,
                        offset: const Offset(0, 30),
                      ),
                    ],
                  ),
                  child: const SlidingImageAnimation(
                    imagePath: 'assets/images/delicious_food_spread.png',
                    height: 550,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestaurantsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 60 : 100,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                const Color(0xFF10B981).withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '🍽️ Featured Restaurants',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 20 : 28),
              Text(
                'Discover Amazing Dining',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 28 : 46,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 650,
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                child: Text(
                  'Explore our curated selection of top-rated restaurants ready to serve you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 19,
                    color: const Color(0xFF6B7280).withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 40 : 60),
              _loadingRestaurants
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF10B981),
                        ),
                      ),
                    )
                  : _restaurants.isEmpty
                  ? Container(
                      padding: EdgeInsets.all(isMobile ? 40 : 60),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: isMobile ? 60 : 80,
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.3),
                          ),
                          SizedBox(height: isMobile ? 16 : 20),
                          Text(
                            'No Restaurants Yet',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          Text(
                            'Be the first to register your restaurant!',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: const Color(
                                0xFF6B7280,
                              ).withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 3),
                          crossAxisSpacing: isMobile ? 0 : 24,
                          mainAxisSpacing: isMobile ? 16 : 24,
                          childAspectRatio: isMobile ? 0.9 : 0.85,
                        ),
                        itemCount: _restaurants.length,
                        itemBuilder: (context, index) {
                          return _buildRestaurantCard(
                            _restaurants[index],
                            isMobile,
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  void _openRestaurantDetails(Map<String, dynamic> restaurant) {
    showDialog(
      context: context,
      builder: (context) => RestaurantDetailsDialog(
        restaurant: restaurant,
        onVisitPressed: () {
          final establishmentId = restaurant['id'];
          // Set persistent ID so Router knows where to go after login
          AuthService.pendingEstablishmentId = establishmentId;

          Navigator.pop(context); // Close details dialog

          final user = Supabase.instance.client.auth.currentUser;

          if (user != null) {
            // If already logged in (unlikely due to Router auto-logout, but possible)
            // Go direct
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerNavigation(establishmentId: establishmentId),
              ),
            );
          } else {
            // Unauthenticated -> Show Dialog
            _showAccessDialog(context, establishmentId);
          }
        },
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant, bool isMobile) {
    final name = restaurant['name'] ?? 'Unknown Restaurant';
    final type = restaurant['type'] ?? 'Restaurant';
    final address = restaurant['address'] ?? 'No address provided';
    final description = restaurant['description'] ?? 'No description available';
    final imageUrl = restaurant['image_url'];
    // final establishmentId = restaurant['id'] ?? ''; // used internally by helper now

    return GestureDetector(
      onTap: () => _openRestaurantDetails(restaurant),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: isMobile ? 180 : 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: isMobile ? 180 : 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                                const Color(0xFF059669).withValues(alpha: 0.2),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            size: isMobile ? 50 : 60,
                            color: const Color(0xFF10B981),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: double.infinity,
                      height: isMobile ? 180 : 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.2),
                            const Color(0xFF059669).withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        size: isMobile ? 50 : 60,
                        color: const Color(0xFF10B981),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: const Color(0xFF10B981),
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1, // Prevent overflow
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: const Color(0xFF6B7280).withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(height: isMobile ? 12 : 16),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: isMobile ? 14 : 16,
                          color: const Color(0xFF10B981),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: const Color(
                                0xFF6B7280,
                              ).withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 8 : 10),
                    SizedBox(
                      width: double.infinity,
                      height: isMobile
                          ? 40
                          : 48, // Fixed height for button to match design
                      child: ElevatedButton(
                        onPressed: () => _openRestaurantDetails(restaurant),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            const Color(0xFF4F46E5).withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Everything You Need in One Platform',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 650,
            child: Text(
              'From reservations to staff management, DineTrack handles it all with precision and ease.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                color: const Color(0xFF6B7280).withValues(alpha: 0.9),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 70),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: const Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [
                _FeatureCard(
                  icon: Icons.calendar_today,
                  title: 'Smart Reservations',
                  description:
                      'Manage bookings, waitlists, and table assignments seamlessly.',
                  color: Color(0xFF4F46E5),
                ),
                _FeatureCard(
                  icon: Icons.schedule,
                  title: 'Staff Scheduling',
                  description:
                      'Automate staff shifts, track hours, and optimize labor costs.',
                  color: Color(0xFF10B981),
                ),
                _FeatureCard(
                  icon: Icons.analytics,
                  title: 'Real-time Analytics',
                  description:
                      'Get insights into customer behavior and business performance.',
                  color: Color(0xFFF59E0B),
                ),
                _FeatureCard(
                  icon: Icons.table_chart,
                  title: 'Table Management',
                  description:
                      'Visual floor plans and dynamic table status tracking.',
                  color: Color(0xFFEF4444),
                ),
                _FeatureCard(
                  icon: Icons.people,
                  title: 'Customer Management',
                  description:
                      'Build customer profiles and personalize dining experiences.',
                  color: Color(0xFF8B5CF6),
                ),
                _FeatureCard(
                  icon: Icons.monetization_on,
                  title: 'Revenue Optimization',
                  description:
                      'Maximize table turnover and increase average check size.',
                  color: Color(0xFF06B6D4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF111827), const Color(0xFF0F172A)],
        ),
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DineTrack',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Simplifying restaurant management\nfor the modern dining experience.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    _FooterLink('Features'),
                    _FooterLink('Pricing'),
                    _FooterLink('API'),
                    _FooterLink('Documentation'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    _FooterLink('About'),
                    _FooterLink('Blog'),
                    _FooterLink('Careers'),
                    _FooterLink('Press'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    _FooterLink('Support'),
                    _FooterLink('Sales'),
                    _FooterLink('Partnership'),
                    _FooterLink('Feedback'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          const Divider(color: Color(0xFF374151)),
          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2024 DineTrack. All rights reserved.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              Row(
                children: [
                  Text(
                    'Privacy Policy',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                  SizedBox(width: 32),
                  Text(
                    'Terms of Service',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                  SizedBox(width: 32),
                  Text(
                    'Cookie Policy',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 32)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: const Color(0xFF6B7280).withValues(alpha: 0.9),
              height: 1.7,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;

  const _FooterLink(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
    );
  }
}
