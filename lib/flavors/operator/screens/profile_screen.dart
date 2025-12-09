import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/supabase_service.dart';

class OperatorProfileScreen extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;

  const OperatorProfileScreen({
    super.key,
    required this.establishmentId,
    required this.isDarkMode,
  });

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen> {
  final _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Restaurant Controllers
  final _restNameCtrl = TextEditingController();
  final _restAddressCtrl = TextEditingController();
  final _restPhoneCtrl = TextEditingController();
  final _restDescriptionCtrl = TextEditingController();

  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _restNameCtrl.dispose();
    _restAddressCtrl.dispose();
    _restPhoneCtrl.dispose();
    _restDescriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final client = _supabaseService.client;
      final user = client.auth.currentUser;

      if (user != null) {
        // 1. Get User Data
        final userData = await client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (userData != null) {
          _nameCtrl.text = userData['full_name'] ?? '';
          _emailCtrl.text = userData['email'] ?? user.email ?? '';
          _phoneCtrl.text = userData['phone'] ?? '';
          _profileImageUrl = userData['profile_image_url'];
        }

        // 2. Get Establishment Data
        if (widget.establishmentId.isNotEmpty) {
          final estData = await client
              .from('establishments')
              .select()
              .eq('id', widget.establishmentId)
              .maybeSingle();

          if (estData != null) {
            _restNameCtrl.text = estData['name'] ?? '';
            _restAddressCtrl.text = estData['address'] ?? '';
            _restPhoneCtrl.text = estData['phone'] ?? '';
            _restDescriptionCtrl.text = estData['description'] ?? '';
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final client = _supabaseService.client;
      final user = client.auth.currentUser;

      if (user != null) {
        // Update User
        await client
            .from('users')
            .update({
              'full_name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
            })
            .eq('id', user.id);

        // Update Establishment
        if (widget.establishmentId.isNotEmpty) {
          await client
              .from('establishments')
              .update({
                'name': _restNameCtrl.text.trim(),
                'address': _restAddressCtrl.text.trim(),
                'phone': _restPhoneCtrl.text.trim(),
                'description': _restDescriptionCtrl.text.trim(),
              })
              .eq('id', widget.establishmentId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));
      }

      // Read bytes from XFile (works on both web and mobile)
      final bytes = await pickedFile.readAsBytes();
      final uploadedUrl = await _supabaseService.uploadProfileImage(
        bytes,
        pickedFile.name,
      );
      if (uploadedUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to upload image. Check app logs for details.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Save the URL to the database so it persists
      final client = _supabaseService.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client
            .from('users')
            .update({'profile_image_url': uploadedUrl})
            .eq('id', user.id);
      }

      setState(() => _profileImageUrl = uploadedUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final inputBg = widget.isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text('Profile & Restaurant', style: TextStyle(color: textColor)),
        leading: BackButton(color: textColor),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              color: Colors.blue,
              onPressed: _isSaving ? null : _updateProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Image
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                _profileImageUrl != null &&
                                    _profileImageUrl!.isNotEmpty
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            child:
                                _profileImageUrl == null ||
                                    _profileImageUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Personal Details', textColor),
                    const SizedBox(height: 16),
                    _buildTextField('Full Name', _nameCtrl, inputBg, textColor),
                    _buildTextField(
                      'Email',
                      _emailCtrl,
                      inputBg,
                      textColor,
                      readOnly: true,
                    ),
                    _buildTextField('Phone', _phoneCtrl, inputBg, textColor),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Restaurant Details', textColor),
                    const SizedBox(height: 16),
                    if (widget.establishmentId.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Establishment ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              widget.establishmentId,
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    _buildTextField(
                      'Restaurant Name',
                      _restNameCtrl,
                      inputBg,
                      textColor,
                    ),
                    _buildTextField(
                      'Address',
                      _restAddressCtrl,
                      inputBg,
                      textColor,
                    ),
                    _buildTextField(
                      'Restaurant Phone',
                      _restPhoneCtrl,
                      inputBg,
                      textColor,
                    ),
                    _buildTextField(
                      'Description',
                      _restDescriptionCtrl,
                      inputBg,
                      textColor,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color bg,
    Color textColor, {
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
          filled: true,
          fillColor: bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (!readOnly && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}
