import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/menu_models.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(MenuItem, {int quantity}) onAddToCart;

  const FavoritesScreen({super.key, required this.onAddToCart});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final Color _primaryGreen = const Color(0xFF53B175);
  final Color _lightGrey = const Color(0xFFF2F3F2);
  final Color _darkGrey = const Color(0xFF7C7C7C);

  List<MenuItem> _favorites = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  List<MenuItem> _filteredFavorites = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _supabaseService.getUserFavorites();
      setState(() {
        _favorites = favorites;
        _filteredFavorites = favorites;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      // print('Error loading favorites: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFavorites = _favorites;
      } else {
        _filteredFavorites = _favorites
            .where(
              (item) =>
                  item.name.toLowerCase().contains(query) ||
                  (item.description?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filteredFavorites = _favorites;
    });
  }

  Future<void> _removeFromFavorites(MenuItem item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Favorites'),
        content: Text(
          'Are you sure you want to remove "${item.name}" from favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      try {
        await _supabaseService.removeFromFavorites(item.id);
        setState(() {
          _favorites.removeWhere((favorite) => favorite.id == item.id);
          _filteredFavorites = _searchQuery.isEmpty
              ? _favorites
              : _favorites
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(_searchQuery) ||
                          (item.description?.toLowerCase().contains(
                                _searchQuery,
                              ) ??
                              false),
                    )
                    .toList();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${item.name} from favorites'),
              backgroundColor: _primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // print('Error removing from favorites: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove from favorites'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _refreshFavorites() {
    setState(() {
      _loading = true;
    });
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Favorites',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _lightGrey,
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search favorites...",
                  hintStyle: TextStyle(color: _darkGrey),
                  prefixIcon: Icon(Icons.search, color: _darkGrey),
                  suffixIcon: _searchQuery.isNotEmpty
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
          ),

          // 📱 FAVORITES CONTENT
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF53B175)),
                  )
                : _filteredFavorites.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      _refreshFavorites();
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                      itemCount: _filteredFavorites.length,
                      itemBuilder: (context, index) {
                        final item = _filteredFavorites[index];
                        return _buildFavoriteCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.favorite_border,
            color: _darkGrey,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No results found' : 'No favorites yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Start adding items to your favorites!',
            style: TextStyle(color: _darkGrey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
              child: const Text(
                'Clear Search',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🛒 FAVORITE ITEM CARD
  Widget _buildFavoriteCard(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PRODUCT IMAGE
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
                      style: TextStyle(color: _darkGrey, fontSize: 12),
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
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.onAddToCart(item, quantity: 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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

          // FAVORITE BADGE AND REMOVE BUTTON
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 16),
            ),
          ),

          // REMOVE BUTTON
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: () => _removeFromFavorites(item),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.close, color: _darkGrey, size: 18),
              ),
            ),
          ),

          // BESTSELLER BADGE
          if (item.isBestseller)
            Positioned(
              top: 45,
              right: 8,
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
    );
  }
}
