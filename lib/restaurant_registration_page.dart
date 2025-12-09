import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dinetrack/login_page.dart';
import 'package:dinetrack/core/routing/role_router.dart';

class RestaurantRegistrationPage extends StatefulWidget {
  const RestaurantRegistrationPage({super.key});

  @override
  State<RestaurantRegistrationPage> createState() =>
      _RestaurantRegistrationPageState();
}

class _RestaurantRegistrationPageState
    extends State<RestaurantRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Restaurant fields
  final TextEditingController restaurantNameCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController typeCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();

  // Admin fields
  final TextEditingController adminNameCtrl = TextEditingController();
  final TextEditingController adminEmailCtrl = TextEditingController();
  final TextEditingController adminPasswordCtrl = TextEditingController();
  final TextEditingController adminConfirmPasswordCtrl =
      TextEditingController();

  @override
  void dispose() {
    restaurantNameCtrl.dispose();
    locationCtrl.dispose();
    phoneCtrl.dispose();
    typeCtrl.dispose();
    descriptionCtrl.dispose();
    adminNameCtrl.dispose();
    adminEmailCtrl.dispose();
    adminPasswordCtrl.dispose();
    adminConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Restaurant Registration",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 800,
            ),
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            child: Column(
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          size: 40,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Join DineTrack',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Register your restaurant and start managing operations efficiently',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Form Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 24 : 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Restaurant Details Section
                        _buildSectionHeader(
                          icon: Icons.store,
                          title: "Restaurant Details",
                          color: const Color(0xFF4F46E5),
                        ),
                        const SizedBox(height: 24),

                        _buildTextField(
                          controller: restaurantNameCtrl,
                          label: "Restaurant Name",
                          hint: "e.g., The Golden Fork",
                          icon: Icons.restaurant_menu,
                          validatorMsg: "Enter restaurant name",
                        ),

                        _buildTextField(
                          controller: locationCtrl,
                          label: "Location",
                          hint: "Full address",
                          icon: Icons.location_on,
                          validatorMsg: "Enter location",
                        ),

                        _buildTextField(
                          controller: phoneCtrl,
                          label: "Phone Number",
                          hint: "+265 123 456 789",
                          icon: Icons.phone,
                          keyboard: TextInputType.phone,
                          validatorMsg: "Enter phone number",
                        ),

                        _buildTextField(
                          controller: typeCtrl,
                          label: "Restaurant Type",
                          hint: "e.g., Fast Food, Café, Fine Dining",
                          icon: Icons.category,
                          validatorMsg: "Enter restaurant type",
                        ),

                        _buildTextField(
                          controller: descriptionCtrl,
                          label: "Description",
                          hint: "Tell us about your restaurant...",
                          icon: Icons.description,
                          maxLines: 4,
                          validatorMsg: "Enter description",
                        ),

                        const SizedBox(height: 40),

                        // Admin Account Section
                        _buildSectionHeader(
                          icon: Icons.admin_panel_settings,
                          title: "Admin Account",
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 24),

                        _buildTextField(
                          controller: adminNameCtrl,
                          label: "Admin Full Name",
                          hint: "John Doe",
                          icon: Icons.person,
                          validatorMsg: "Enter admin name",
                        ),

                        _buildTextField(
                          controller: adminEmailCtrl,
                          label: "Admin Email",
                          hint: "admin@restaurant.com",
                          icon: Icons.email,
                          validatorMsg: "Enter admin email",
                          keyboard: TextInputType.emailAddress,
                        ),

                        _buildTextField(
                          controller: adminPasswordCtrl,
                          label: "Password",
                          hint: "At least 8 characters",
                          icon: Icons.lock,
                          isPassword: true,
                          showPassword: _showPassword,
                          onTogglePassword: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                          validatorMsg: "Enter password",
                          extraValidator: (value) {
                            if (value != null && value.length < 8) {
                              return "Password must be at least 8 characters";
                            }
                            return null;
                          },
                        ),

                        _buildTextField(
                          controller: adminConfirmPasswordCtrl,
                          label: "Confirm Password",
                          hint: "Re-enter your password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          showPassword: _showConfirmPassword,
                          onTogglePassword: () {
                            setState(
                              () =>
                                  _showConfirmPassword = !_showConfirmPassword,
                            );
                          },
                          validatorMsg: "Confirm password",
                          extraValidator: (value) {
                            if (value != adminPasswordCtrl.text) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 40),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: const Color(
                                0xFF4F46E5,
                              ).withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 22),
                                      SizedBox(width: 10),
                                      Text(
                                        "Register Restaurant",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Already have account
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Already have an account? Login',
                              style: TextStyle(
                                color: Color(0xFF4F46E5),
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? validatorMsg,
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
    int maxLines = 1,
    String? Function(String?)? extraValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword && !showPassword,
            keyboardType: keyboard,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.7),
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF6B7280),
                        size: 22,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4F46E5),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEF4444)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (validatorMsg != null && (value == null || value.isEmpty)) {
                return validatorMsg;
              }
              if (extraValidator != null) return extraValidator(value);
              return null;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create admin user account
      final authResponse = await _supabase.auth.signUp(
        email: adminEmailCtrl.text.trim(),
        password: adminPasswordCtrl.text.trim(),
        data: {
          'full_name': adminNameCtrl.text.trim(),
          'user_type': 'operator', // Changed from 'role' to 'user_type'
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create admin account');
      }

      final userId = authResponse.user!.id;

      // 1.5 Create user entry in public users table
      await _supabase.from('users').upsert({
        'id': userId,
        'email': adminEmailCtrl.text.trim(),
        'full_name': adminNameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'user_type': 'operator',
        'dine_coins_balance': 0.00,
      });

      // 2. Create restaurant (establishment) entry
      final restaurantResponse = await _supabase
          .from('establishments')
          .insert({
            'name': restaurantNameCtrl.text.trim(),
            'address': locationCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'type': typeCtrl.text.trim(),
            'description': descriptionCtrl.text.trim(),
            'owner_id': userId,
            'is_active': true,
            'supervisor_approved': false, // Explicitly set for pending approval
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final establishmentId = restaurantResponse['id'];

      // 3. Create staff entry for admin
      await _supabase.from('staff_assignments').insert({
        'establishment_id': establishmentId,
        'user_id': userId,
        'name': adminNameCtrl.text.trim(),
        'email': adminEmailCtrl.text.trim(),
        'role': 'manager',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Success!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Restaurant registered successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to dashboard via RoleBasedRouter
        await Future.delayed(
          const Duration(seconds: 1),
        ); // Short delay for snackbar
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RoleBasedRouter(userId: userId)),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Auth Error: ${e.message}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Database Error: ${e.message}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
