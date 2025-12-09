import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/supabase_service.dart';

class AddMenuItemPage extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;
  final VoidCallback? onMenuItemAdded;

  const AddMenuItemPage({
    super.key,
    required this.establishmentId,
    required this.isDarkMode,
    this.onMenuItemAdded,
  });

  @override
  State<AddMenuItemPage> createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  // final TextEditingController _imageUrlCtrl = TextEditingController(); // Replaced with picker
  final TextEditingController _prepTimeCtrl = TextEditingController();

  String? _categoryId;
  List<Map<String, dynamic>> _categories = [];

  bool _isAvailable = true;
  bool _isBestseller = false;
  bool _isRecommended = false;

  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    // _imageUrlCtrl.dispose();
    _prepTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      // Use the global query based on the new schema (no establishment_id on categories)
      final response = await _supabase
          .from('menu_categories')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          if (_categories.isNotEmpty) {
            _categoryId = _categories[0]['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await pickedFile.readAsBytes();
      final url = await SupabaseService().uploadMenuItemImage(
        bytes,
        pickedFile.name,
      );

      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingImage = false;
        });

        if (url == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final prepTime = int.tryParse(_prepTimeCtrl.text);

      await _supabase.from('menu_items').insert({
        'establishment_id': widget.establishmentId,
        'category_id': _categoryId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': price,
        'image_url':
            _uploadedImageUrl ??
            '', // Use uploaded URL, defaults to empty string if null
        'preparation_time': prepTime,
        'is_available': _isAvailable,
        'is_bestseller': _isBestseller,
        'is_recommended': _isRecommended,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Clear form
        _nameCtrl.clear();
        _descCtrl.clear();
        _priceCtrl.clear();
        _prepTimeCtrl.clear();
        setState(() {
          _uploadedImageUrl = null;
          _isAvailable = true;
          _isBestseller = false;
          _isRecommended = false;
        });

        widget.onMenuItemAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding menu item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final inputFill = widget.isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.grey.shade100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Menu Item',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),

            // 1. Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade400,
                    style: BorderStyle.solid,
                  ),
                  image: _uploadedImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_uploadedImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _isUploadingImage
                    ? const Center(child: CircularProgressIndicator())
                    : (_uploadedImageUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 48,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : null), // Image already shown in decoration
              ),
            ),
            const SizedBox(height: 24),

            // 2. Basic Info
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _nameCtrl,
                    label: 'Item Name',
                    icon: Icons.fastfood,
                    textColor: textColor,
                    fillColor: inputFill,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _priceCtrl,
                    label: 'Price (MWK)',
                    icon: Icons.attach_money,
                    textColor: textColor,
                    fillColor: inputFill,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid price';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // 3. Category Dropdown
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _categoryId,
                  hint: Text(
                    'Select Category',
                    style: TextStyle(color: textColor),
                  ),
                  isExpanded: true,
                  dropdownColor: widget.isDarkMode
                      ? const Color(0xFF333333)
                      : Colors.white,
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id'],
                      child: Text(
                        cat['name'],
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _categoryId = val),
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildTextField(
              controller: _descCtrl,
              label: 'Description',
              icon: Icons.description,
              textColor: textColor,
              fillColor: inputFill,
              maxLines: 3,
            ),

            const SizedBox(height: 16),
            _buildTextField(
              controller: _prepTimeCtrl,
              label: 'Prep Time (mins)',
              icon: Icons.timer,
              textColor: textColor,
              fillColor: inputFill,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),

            // 4. Switches
            _buildSwitch(
              'Available',
              _isAvailable,
              (val) => setState(() => _isAvailable = val),
              textColor,
            ),
            _buildSwitch(
              'Bestseller',
              _isBestseller,
              (val) => setState(() => _isBestseller = val),
              textColor,
            ),
            _buildSwitch(
              'Recommended',
              _isRecommended,
              (val) => setState(() => _isRecommended = val),
              textColor,
            ),

            const SizedBox(height: 32),

            // 5. Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addMenuItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Add Menu Item',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color fillColor,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}
