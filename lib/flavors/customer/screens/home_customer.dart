import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';
import './menu_screen.dart';

class HomeCustomer extends StatefulWidget {
  final String establishmentId;
  final Function(MenuItem, {int quantity}) onAddToCart;
  final int cartItemCount;

  const HomeCustomer({
    super.key,
    required this.establishmentId,
    required this.onAddToCart,
    required this.cartItemCount,
  });

  @override
  State<HomeCustomer> createState() => _HomeCustomerState();
}

class _HomeCustomerState extends State<HomeCustomer> {
  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);

    // DEBUG: Check the establishment ID
    print('🚨 HomeCustomer - Establishment ID: "${widget.establishmentId}"');
    print('🚨 HomeCustomer - ID Length: ${widget.establishmentId.length}');
    print('🚨 HomeCustomer - Is Empty: ${widget.establishmentId.isEmpty}');

    // If ID is empty, show an error immediately
    if (widget.establishmentId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEmptyEstablishmentError();
      });
    }

    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _showEmptyEstablishmentError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('No establishment selected. Please go back and select an establishment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  final SupabaseService _supabaseService = SupabaseService();
  final Color _primaryGreen = const Color(0xFF2196F3);
  final Color _lightGrey = const Color(0xFFF2F3F2);
  final Color _darkGrey = const Color(0xFF7C7C7C);

  Future<List<AppCategory>> _categoriesFuture = Future.value([]);
  Future<List<MenuItem>> _bestsellersFuture = Future.value([]);
  Future<List<MenuItem>> _recommendedFuture = Future.value([]);
  Future<UserProfile?> _userProfileFuture = Future.value(null);
  Future<Map<String, dynamic>?> _establishmentFuture = Future.value(null);

  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _categoriesFuture = _supabaseService.getCategories(establishmentId: widget.establishmentId);
      _bestsellersFuture = _supabaseService.getBestsellers(establishmentId: widget.establishmentId);
      _recommendedFuture = _supabaseService.getRecommended(establishmentId: widget.establishmentId);
      _userProfileFuture = _supabaseService.getCurrentUserProfile();
      _establishmentFuture = _supabaseService.getEstablishment(widget.establishmentId);
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _isSearching = query.isNotEmpty;
      });

      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults.clear();
        });
      }
    }
  }



  Future<void> _performSearch(String query) async {
    try {
      final results = await _supabaseService.searchMenuItems(query, establishmentId: widget.establishmentId);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _searchResults.clear();
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
    if (_isSearching && _searchQuery.isNotEmpty) {
      await _performSearch(_searchQuery);
    }
  }

  void _navigateToMenuScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuScreen(
          establishmentId: widget.establishmentId,
          onAddToCart: widget.onAddToCart,
          cartItemCount: widget.cartItemCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _establishmentFuture,
          builder: (context, snapshot) {
            // Handle error gracefully to prevent crash
            if (snapshot.hasError) return const Text('DineTrack');
            final establishmentName = snapshot.data?['name'] ?? 'DineTrack';
            return Text(
              establishmentName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        backgroundColor: _primaryGreen,
        actions: [],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 👤 USER HEADER
            _buildUserHeader(),

            // 📱 MAIN CONTENT
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: CustomScrollView(
                  slivers: [
                    // 🔍 SEARCH BAR
                    SliverToBoxAdapter(
                      child: _buildSearchBar(),
                    ),

                    // 🎯 HERO BANNER
                    SliverToBoxAdapter(
                      child: _buildHeroBanner(),
                    ),

                    // CONTENT BASED ON SEARCH STATE
                    if (_isSearching) ..._buildSearchContent(),
                    if (!_isSearching) ..._buildMainContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSearchContent() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Results for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_searchResults.length} items',
                style: TextStyle(color: _darkGrey),
              ),
            ],
          ),
        ),
      ),
      _buildProductGrid(_searchResults),
    ];
  }

  List<Widget> _buildMainContent() {
    return [
      // 🍽️ CATEGORIES SECTION
      SliverToBoxAdapter(
        child: _buildSectionHeader("Categories", "See All", onSeeAll: _navigateToMenuScreen),
      ),
      SliverToBoxAdapter(
        child: _buildCategoriesRow(),
      ),

      // 🔥 BEST SELLERS
      SliverToBoxAdapter(
        child: _buildSectionHeader("Best Sellers", "See All", onSeeAll: _navigateToMenuScreen),
      ),
      SliverToBoxAdapter(
        child: FutureBuilder<List<MenuItem>>(
          future: _bestsellersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            // Check errors
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptySection("No bestsellers available");
            }
            return _buildBestSellersGrid(snapshot.data!);
          },
        ),
      ),

      // 💚 RECOMMENDED FOR YOU
      SliverToBoxAdapter(
        child: _buildSectionHeader("Recommended for you", "See All", onSeeAll: _navigateToMenuScreen),
      ),
      _buildRecommendedGrid(), // Updated logic inside
    ];
  }

  // 👤 USER HEADER - SAFE SPLIT LOGIC
  // Update the _buildUserHeader method in home_customer.dart
  Widget _buildUserHeader() {
    return FutureBuilder<UserProfile?>(
      future: _userProfileFuture,
      builder: (context, snapshot) {
        String userName = 'Guest';
        double dineCoins = 0.0;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildUserHeaderShimmer();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final profile = snapshot.data!;
          if (profile.fullName != null && profile.fullName!.isNotEmpty) {
            final parts = profile.fullName!.split(' ');
            userName = parts.isNotEmpty ? parts.first : profile.fullName!;
          }
          dineCoins = profile.dineCoinsBalance;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Good ${_getTimeBasedGreeting()}!",
                      style: TextStyle(
                        fontSize: 14,
                        color: _darkGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hello, $userName 👋",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "DineCoins: ${dineCoins.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: _primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _primaryGreen.withOpacity(0.1),
                  child: Icon(Icons.person, color: _primaryGreen, size: 24),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Add shimmer loading for user header
  Widget _buildUserHeaderShimmer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 14,
                  color: _lightGrey,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 20,
                  color: _lightGrey,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 14,
                  color: _lightGrey,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primaryGreen.withOpacity(0.3)),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _lightGrey,
            ),
          ),
        ],
      ),
    );
  }

  // 🔍 SEARCH BAR
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _lightGrey,
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search store...",
            hintStyle: TextStyle(color: _darkGrey),
            prefixIcon: Icon(Icons.search, color: _darkGrey),
            suffixIcon: _isSearching
                ? IconButton(
              icon: Icon(Icons.close, color: _darkGrey),
              onPressed: _clearSearch,
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  // 🎯 HERO BANNER
  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Fresh",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Get Fresh Food",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Fresh and organic food delivered to your table",
                    style: TextStyle(
                      color: _darkGrey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Replaced with Icon as placeholder to avoid asset crash
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.restaurant, color: _primaryGreen, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  // 📌 SECTION HEADER
  Widget _buildSectionHeader(String title, String action, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              action,
              style: TextStyle(
                color: _primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🍽️ CATEGORIES ROW
  Widget _buildCategoriesRow() {
    return FutureBuilder<List<AppCategory>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(color: _primaryGreen)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptySection("No categories");
        }

        final categories = snapshot.data!;
        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryItem(category);
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(AppCategory category) {
    return GestureDetector(
      onTap: _navigateToMenuScreen,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _lightGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getIconForCategory(category.name),
              size: 32,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _darkGrey,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 🔥 BEST SELLERS GRID
  Widget _buildBestSellersGrid(List<MenuItem> bestsellers) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: bestsellers.length,
        itemBuilder: (context, index) {
          final item = bestsellers[index];
          return Container(
            width: 160,
            margin: EdgeInsets.only(right: index == bestsellers.length - 1 ? 0 : 15),
            child: _buildProductCard(item),
          );
        },
      ),
    );
  }

  // 💚 RECOMMENDED GRID - REFACTORED TO FIX "NO ELEMENT" ERROR
  Widget _buildRecommendedGrid() {
    return FutureBuilder<List<MenuItem>>(
      future: _recommendedFuture,
      builder: (context, snapshot) {
        // 1. Return a SliverToBoxAdapter with loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildProductCardShimmer(),
              )
          );
        }

        // 2. Return a SliverToBoxAdapter for error or empty state (Prevents crash)
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final items = snapshot.data!;

        // 3. Return the actual SliverGrid with valid data count
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildProductCard(items[index]),
              );
            },
            childCount: items.length > 4 ? 4 : items.length, // Limit to 4 or less
          ),
        );
      },
    );
  }

  // 🔍 SEARCH RESULTS GRID
  SliverGrid _buildProductGrid(List<MenuItem> items) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildProductCard(item),
          );
        },
        childCount: items.length,
      ),
    );
  }

  // 🛒 PRODUCT CARD
  Widget _buildProductCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRODUCT IMAGE
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _lightGrey,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
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
                      "BEST",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // PRODUCT DETAILS
          Padding(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedPrice,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primaryGreen,
                      ),
                    ),
                    InkWell(
                      onTap: () => widget.onAddToCart(item),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _primaryGreen,
                          borderRadius: BorderRadius.circular(10),
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
        ],
      ),
    );
  }

  Widget _buildProductCardShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _lightGrey,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                SizedBox(height: 4),
                SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: _darkGrey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 🕒 HELPER METHODS
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
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
      default:
        return Icons.restaurant_menu;
    }
  }
}