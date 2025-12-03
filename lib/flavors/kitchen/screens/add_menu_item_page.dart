import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dinetrack/core/services/supabase_service.dart';

class AddMenuItemPage extends StatefulWidget {
  final String establishmentId;
  final bool isDarkMode;
  final VoidCallback? onMenuItemAdded;

  const AddMenuItemPage({
    Key? key,
    required this.establishmentId,
    required this.isDarkMode,
    this.onMenuItemAdded,
  }) : super(key: key);

  @override
  _AddMenuItemPageState createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _preparationTimeController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isAvailable = true;
  bool _isBestseller = false;
  bool _isRecommended = false;
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _preparationTimeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      // First, check if we have an establishment ID
      if (widget.establishmentId.isEmpty) {
        print('No establishment ID provided');
        setState(() {
          _isLoadingCategories = false;
        });
        return;
      }
      print('Loading categories for establishment: ${widget.establishmentId}');
      final response = await _supabase
          .from('menu_categories')
          .select('id, name')
          .eq('establishment_id', widget.establishmentId)
          .eq('is_active', true)
          .order('display_order');

      print('Categories loaded: ${response.length}');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories[0]['id'];
          print('Selected first category: ${_categories[0]['name']}');
        } else {
          print('No categories found for this establishment');
        }
        _isLoadingCategories = false;
      });
    } on PostgrestException catch (error) {
      print('Postgrest error loading categories: ${error.message}');
      print('Details: ${error.details}');
      setState(() {
        _isLoadingCategories = false;
      });

      // Show error to user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${error.message}'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (error) {
      print('Error loading categories: $error');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _addMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Adding menu item with category: $_selectedCategoryId');

      final response = await _supabase
          .from('menu_items')
          .insert({
        'category_id': _selectedCategoryId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'image_url': _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
        'is_available': _isAvailable,
        'preparation_time': int.tryParse(_preparationTimeController.text.trim()) ?? 10,
        'is_bestseller': _isBestseller,
        'is_recommended': _isRecommended,
        'rating': 0.0, // Default rating
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .select();

      if (response.isNotEmpty) {
        // Clear form
        _formKey.currentState!.reset();
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _preparationTimeController.clear();
        _imageUrlController.clear();

        // Reset toggles
        setState(() {
          _isAvailable = true;
          _isBestseller = false;
          _isRecommended = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu item added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback if provided
        if (widget.onMenuItemAdded != null) {
          widget.onMenuItemAdded!();
        }
      }
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add menu item: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'DINETRACK',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Add New Menu Item',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.black : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Add Menu Item Form
          Card(
            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu Item Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Selection
                    if (_isLoadingCategories)
                      const Center(child: CircularProgressIndicator())
                    else if (_categories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No categories found. Please create categories first.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategoryId,
                                  isExpanded: true,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                  dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCategoryId = newValue;
                                    });
                                  },
                                  items: _categories.map<DropdownMenuItem<String>>((category) {
                                    return DropdownMenuItem<String>(
                                      value: category['id'],
                                      child: Text(category['name'] ?? 'Unnamed Category'),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : null,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., Grilled Salmon, Chocolate Cake',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade500 : null,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : null,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'Describe the menu item...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade500 : null,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : null,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., 5000.00',
                        suffixText: 'MWK',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade500 : null,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Preparation Time
                    TextFormField(
                      controller: _preparationTimeController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Preparation Time',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : null,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., 15',
                        suffixText: 'minutes',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade500 : null,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter preparation time';
                        }
                        final time = int.tryParse(value);
                        if (time == null || time <= 0) {
                          return 'Please enter valid time in minutes';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Image URL (Optional)
                    TextFormField(
                      controller: _imageUrlController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Image URL (Optional)',
                        labelStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : null,
                        ),
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com/image.jpg',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey.shade500 : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle Switches
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item Settings',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Available
                        Row(
                          children: [
                            Switch(
                              value: _isAvailable,
                              onChanged: (value) {
                                setState(() {
                                  _isAvailable = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),

                        // Bestseller
                        Row(
                          children: [
                            Switch(
                              value: _isBestseller,
                              onChanged: (value) {
                                setState(() {
                                  _isBestseller = value;
                                });
                              },
                              activeColor: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mark as Bestseller',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),

                        // Recommended
                        Row(
                          children: [
                            Switch(
                              value: _isRecommended,
                              onChanged: (value) {
                                setState(() {
                                  _isRecommended = value;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mark as Recommended',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _addMenuItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.add),
                        label: Text(
                          _isLoading ? 'Adding...' : 'Add Menu Item',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    // Sample Image URLs for testing
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sample Image URLs:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Juice: https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '• Pasta: https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=400',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '• Cake: https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}