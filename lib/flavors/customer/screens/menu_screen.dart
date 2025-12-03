import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';
import 'item_detail_screen.dart';

class MenuScreen extends StatefulWidget {
  final String establishmentId;
  final Function(MenuItem, {int quantity}) onAddToCart;
  final int cartItemCount;

  const MenuScreen({
    super.key,
    required this.establishmentId,
    required this.onAddToCart,
    this.cartItemCount = 0,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final Color _primaryGreen = const Color(0xFF53B175);
  final Color _lightGrey = const Color(0xFFF2F3F2);
  final Color _darkGrey = const Color(0xFF7C7C7C);

  List<AppCategory> _categories = [];
  Map<String, List<MenuItem>> _menuItemsByCategory = {};
  String _selectedCategoryId = '';
  bool _loading = true;
  String _error = '';

  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    print('MenuScreen - Establishment ID: "${widget.establishmentId}"');
    print('Is empty? ${widget.establishmentId.isEmpty}');
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }
  Future<void> _refreshData() async {
    await _loadData();
  }


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    if (widget.establishmentId.isEmpty) {
      setState(() {
        _error = 'No establishment selected';
        _loading = false;
      });
      return;
    }

    try {
      // Load categories
      final categories = await _supabaseService.getCategories(establishmentId: widget.establishmentId);
      print('DEBUG: Categories loaded: ${categories.length}');

      // Load all menu items
      final allItems = await _supabaseService.getMenuItemsByEstablishment(widget.establishmentId);
      print('DEBUG: Menu items loaded: ${allItems.length}');

      if (allItems.isEmpty) {
        print('DEBUG: No menu items found');
        setState(() {
          _categories = [];
          _menuItemsByCategory = {};
          _selectedCategoryId = '';
          _loading = false;
        });
        return;
      }

      // If categories are empty but items exist, fetch categories from items
      if (categories.isEmpty && allItems.isNotEmpty) {
        print('DEBUG: No categories found, but items exist. Fetching categories from items...');

        // Get unique category IDs from items
        final categoryIds = allItems.map((item) => item.categoryId).toSet().toList();
        print('DEBUG: Unique category IDs from items: $categoryIds');

        // Fetch these categories directly - FIXED: Using manual OR query
        final orConditions = categoryIds.map((id) => 'id.eq.$id').join(',');
        final response = await _supabaseService.client
            .from('menu_categories')
            .select()
            .or(orConditions)
            .eq('is_active', true)
            .order('display_order');

        if (response.isNotEmpty) {
          final fetchedCategories = (response as List)
              .map((cat) => AppCategory.fromJson(cat))
              .toList();
          print('DEBUG: Fetched ${fetchedCategories.length} categories from items');
          _categories = fetchedCategories;
        } else {
          // Create dummy categories from item data
          print('DEBUG: Creating dummy categories from items');
          _categories = categoryIds.map((id) {
            // Find an item with this category
            final itemWithCategory = allItems.firstWhere((item) => item.categoryId == id);
            return AppCategory(
              id: id,
              name: 'Category $id',
              establishmentId: widget.establishmentId,
              isActive: true,
              displayOrder: 0,
            );
          }).toList();
        }
      } else {
        _categories = categories;
      }

      // Group items by category
      final Map<String, List<MenuItem>> groupedItems = {};

      // Initialize with all categories
      for (final category in _categories) {
        groupedItems[category.id] = [];
      }

      // Add items to their categories
      for (final item in allItems) {
        if (groupedItems.containsKey(item.categoryId)) {
          groupedItems[item.categoryId]!.add(item);
        } else {
          // Category not in our list, create it
          print('DEBUG: Item ${item.name} has unknown category ${item.categoryId}');
          if (!groupedItems.containsKey(item.categoryId)) {
            groupedItems[item.categoryId] = [];
          }
          groupedItems[item.categoryId]!.add(item);

          // Also add to categories list if not already there
          if (!_categories.any((cat) => cat.id == item.categoryId)) {
            _categories.add(AppCategory(
              id: item.categoryId,
              name: 'Category ${item.categoryId.substring(0, 8)}...',
              establishmentId: widget.establishmentId,
              isActive: true,
              displayOrder: 999, // Put at the end
            ));
          }
        }
      }

      // Log the grouping result
      print('DEBUG: Final categories: ${_categories.length}');
      print('DEBUG: Grouped items:');
      groupedItems.forEach((categoryId, items) {
        print('  Category $categoryId: ${items.length} items');
      });

      setState(() {
        _menuItemsByCategory = groupedItems;

        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
          print('DEBUG: Selected category ID: $_selectedCategoryId');
          print('DEBUG: Items in selected category: ${groupedItems[_selectedCategoryId]?.length ?? 0}');
        } else {
          _selectedCategoryId = '';
          print('DEBUG: No categories found');
        }

        _loading = false;
      });
    } catch (e) {
      print('ERROR in _loadData: $e');
      print('STACK TRACE: ${e.toString()}');
      setState(() {
        _error = 'Failed to load menu. Please try again.';
        _loading = false;
      });
    }
  }
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Search through all menu items
    final allItems = _menuItemsByCategory.values.expand((list) => list).toList();
    final results = allItems.where((item) =>
    item.name.toLowerCase().contains(query) ||
        (item.description?.toLowerCase().contains(query) ?? false)
    ).toList();

    setState(() {
      _searchResults = results;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _searchResults = [];
    });
  }


  List<MenuItem> get _currentItems {
    if (_isSearching) {
      return _searchResults;
    }
    return _menuItemsByCategory[_selectedCategoryId] ?? [];
  }

  // Helper method to adapt the function signature for ItemDetailScreen
  void _onAddToCartForDetail(MenuItem item, int quantity) {
    widget.onAddToCart(item, quantity: quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Menu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // TODO: Navigate to cart screen
                },
              ),
              if (widget.cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      widget.cartItemCount > 9 ? '9+' : widget.cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : _error.isNotEmpty
          ? _buildErrorState()
          : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading menu...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Failed to load menu',
            style: TextStyle(fontSize: 18, color: _darkGrey),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: TextStyle(fontSize: 14, color: _darkGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _isSearching
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _clearSearch,
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        if (_isSearching) ..._buildSearchContent(),
        if (!_isSearching) ..._buildCategoryContent(),
      ],
    );
  }

  List<Widget> _buildSearchContent() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search Results (${_searchResults.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
      Expanded(
        child: _searchResults.isEmpty
            ? _buildEmptySearchState()
            : _buildMenuItemsGrid(_searchResults),
      ),
    ];
  }

  List<Widget> _buildCategoryContent() {
    return [
      // Categories Row (Horizontal Scroll)
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _buildCategoryItem(category);
          },
        ),
      ),
      const SizedBox(height: 8),
      // Selected Category Title
// Selected Category Title
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              _categories.isEmpty
                  ? 'Menu'
                  : _categories.firstWhere(
                    (cat) => cat.id == _selectedCategoryId,
                orElse: () => _categories.first,
              ).name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_currentItems.length} items',
              style: TextStyle(color: _darkGrey),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      // Menu Items Grid
      Expanded(
        child: _currentItems.isEmpty
            ? _buildEmptyCategoryState()
            : RefreshIndicator(
          onRefresh: _refreshData,
          child: _buildMenuItemsGrid(_currentItems),
        ),
      ),
    ];
  }

  Widget _buildCategoryItem(AppCategory category) {
    final isSelected = _selectedCategoryId == category.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = category.id;
        });
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : _lightGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryGreen : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForCategory(category.name),
              color: isSelected ? Colors.white : _darkGrey,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : _darkGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsGrid(List<MenuItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMenuItemCard(item);
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return GestureDetector(
      onTap: () => _navigateToItemDetail(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image with bestseller badge
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _lightGrey,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.fastfood, color: _darkGrey, size: 40),
                        );
                      },
                    ),
                  )
                      : Center(
                    child: Icon(Icons.fastfood, color: _darkGrey, size: 40),
                  ),
                ),
                if (item.isBestseller)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Item details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description ?? "Fresh and delicious",
                      style: TextStyle(
                        color: _darkGrey,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.formattedPrice,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryGreen,
                          ),
                        ),
                        InkWell(
                          onTap: () => widget.onAddToCart(item, quantity: 1),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No items found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 14, color: _darkGrey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCategoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No items in this category',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new items',
            style: TextStyle(fontSize: 14, color: _darkGrey),
          ),
        ],
      ),
    );
  }

  void _navigateToItemDetail(BuildContext context, MenuItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          item: item,
          onAddToCart: _onAddToCartForDetail, // Use the adapted function
        ),
      ),
    );
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'meals':
        return Icons.lunch_dining;
      case 'drinks':
        return Icons.local_drink;
      case 'desserts':
        return Icons.cake;
      case 'snacks':
        return Icons.fastfood;
      case 'appetizers':
        return Icons.restaurant;
      case 'main course':
        return Icons.dinner_dining;
      case 'beverages':
        return Icons.coffee;
      case 'soups':
        return Icons.soup_kitchen;
      case 'salads':
        return Icons.eco;
      default:
        return Icons.restaurant_menu;
    }
  }
}