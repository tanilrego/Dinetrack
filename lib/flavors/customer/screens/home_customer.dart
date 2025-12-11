import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';
import './menu_screen.dart';
import './waiter_call_button.dart';

class HomeCustomer extends StatefulWidget {
  final String establishmentId;
  final String? tableId;
  final Function(MenuItem, {int quantity}) onAddToCart;
  final int cartItemCount;
  final Map<String, CartItem> cartItems;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemoveFromCart;
  final Function() onClearCart;
  final double cartTotal;
  final Function() onCheckout;

  const HomeCustomer({
    super.key,
    required this.establishmentId,
    this.tableId,
    required this.onAddToCart,
    required this.cartItemCount,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onRemoveFromCart,
    required this.onClearCart,
    required this.cartTotal,
    required this.onCheckout,
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

    if (widget.establishmentId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEmptyEstablishmentError();
      });
    }
  }

  void _showEmptyEstablishmentError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text(
          'No establishment selected. Please go back and select an establishment.',
        ),
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
  final Color _primaryColor = const Color(0xFF4F46E5); // Premium Blue/Indigo
  final Color _lightGrey = const Color(0xFFF9FAFB);
  final Color _darkGrey = const Color(0xFF6B7280);

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
      _categoriesFuture = _supabaseService.getCategories();
      _bestsellersFuture = _supabaseService.getBestsellers(
        establishmentId: widget.establishmentId,
      );
      _recommendedFuture = _supabaseService.getRecommended(
        establishmentId: widget.establishmentId,
      );
      _userProfileFuture = _supabaseService.getCurrentUserProfile();
      _establishmentFuture = _supabaseService.getEstablishment(
        widget.establishmentId,
      );
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
      final results = await _supabaseService.searchMenuItems(
        query,
        establishmentId: widget.establishmentId,
      );
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      // Handle error silently
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
          cartItems: widget.cartItems,
          onUpdateQuantity: widget.onUpdateQuantity,
          onRemoveFromCart: widget.onRemoveFromCart,
          onClearCart: widget.onClearCart,
          cartTotal: widget.cartTotal,
          onCheckout: widget.onCheckout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _establishmentFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DineTrack'),
                  Text(
                    'Error: ${widget.establishmentId}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }
            final establishmentName = snapshot.data?['name'] ?? 'DineTrack';
            return Text(
              establishmentName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            );
          },
        ),
        backgroundColor: _primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Badge(
                label: Text('${widget.cartItemCount}'),
                child: Icon(Icons.shopping_bag_outlined, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: _primaryColor,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildUserHeader()),
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    SliverToBoxAdapter(child: _buildHeroBanner()),
                    if (_isSearching) ..._buildSearchContent(),
                    if (!_isSearching) ..._buildMainContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.tableId != null
          ? WaiterCallButton(
              establishmentId: widget.establishmentId,
              tableId: widget.tableId!,
            )
          : null,
    );
  }

  List<Widget> _buildSearchContent() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Results for "$_searchQuery"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_searchResults.length}',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
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
      SliverToBoxAdapter(
        child: _buildSectionHeader(
          "Categories",
          "See All",
          onSeeAll: _navigateToMenuScreen,
        ),
      ),
      SliverToBoxAdapter(child: _buildCategoriesRow()),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverToBoxAdapter(
        child: _buildSectionHeader(
          "🔥 Best Sellers",
          "See All",
          onSeeAll: _navigateToMenuScreen,
        ),
      ),
      SliverToBoxAdapter(
        child: FutureBuilder<List<MenuItem>>(
          future: _bestsellersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return _buildEmptySection("No bestsellers available");
            }
            return _buildBestSellersGrid(snapshot.data!);
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverToBoxAdapter(
        child: _buildSectionHeader(
          "💚 Recommended for you",
          "See All",
          onSeeAll: _navigateToMenuScreen,
        ),
      ),
      _buildRecommendedGrid(),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _primaryColor.withValues(alpha: 0.03)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Good ${_getTimeBasedGreeting()}! 👋",
                      style: TextStyle(
                        fontSize: 14,
                        color: _darkGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Welcome, $userName",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: _primaryColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "DineCoins: ${dineCoins.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 13,
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor,
                      _primaryColor.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserHeaderShimmer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 14, color: _lightGrey),
                const SizedBox(height: 12),
                Container(width: 160, height: 24, color: _lightGrey),
                const SizedBox(height: 12),
                Container(width: 140, height: 14, color: _lightGrey),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lightGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _lightGrey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search menu items...",
            hintStyle: TextStyle(color: _darkGrey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: _darkGrey, size: 20),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(Icons.close, color: _darkGrey, size: 20),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "🍽️ Fresh Daily",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Discover Fresh Dishes",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Freshly prepared meals served right to your table",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.restaurant, color: Colors.white, size: 45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action, {
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              action,
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRow() {
    return FutureBuilder<List<AppCategory>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(color: _primaryColor),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptySection("No categories");
        }

        final categories = snapshot.data!;
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha: 0.15),
                  _primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
            ),
            child: Icon(
              _getIconForCategory(category.name),
              size: 32,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 75,
            child: Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellersGrid(List<MenuItem> bestsellers) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: bestsellers.length,
        itemBuilder: (context, index) {
          final item = bestsellers[index];
          return Container(
            width: 160,
            margin: EdgeInsets.only(
              right: index == bestsellers.length - 1 ? 0 : 12,
            ),
            child: _buildProductCard(item),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedGrid() {
    return FutureBuilder<List<MenuItem>>(
      future: _recommendedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildProductCardShimmer(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final items = snapshot.data!;

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildProductCard(items[index]),
            );
          }, childCount: items.length > 4 ? 4 : items.length),
        );
      },
    );
  }

  SliverGrid _buildProductGrid(List<MenuItem> items) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildProductCard(item),
        );
      }, childCount: items.length),
    );
  }

  Widget _buildProductCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _lightGrey,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.fastfood,
                                color: _darkGrey,
                                size: 40,
                              ),
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
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      "⭐ Best",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description ?? "Delicious",
                    style: TextStyle(color: _darkGrey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.formattedPrice,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => widget.onAddToCart(item),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _primaryColor,
                                _primaryColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
    );
  }

  Widget _buildProductCardShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lightGrey),
      ),
      child: Column(
        children: [
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _lightGrey,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 14, color: _lightGrey),
                const SizedBox(height: 8),
                Container(width: 100, height: 12, color: _lightGrey),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.restaurant,
              size: 60,
              color: _primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: _darkGrey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
