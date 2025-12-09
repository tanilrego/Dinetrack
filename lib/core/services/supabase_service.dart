import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../models/menu_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:typed_data';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /*Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }*/

  /// This is called AFTER Supabase.initialize() from main.dart
  Future<void> postInit() async {
    developer.log("Supabase  with: $supabaseUrl", name: 'SupabaseService');
  }

  SupabaseClient get client => Supabase.instance.client;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => client.auth.currentUser != null;

  // Auth methods
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String userType,
    String? fullName,
    String? phone,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'user_type': userType, 'full_name': fullName, 'phone': phone},
    );
  }

  // ==================== CATEGORY METHODS ====================

  Future<List<AppCategory>> getCategories() async {
    try {
      final response = await client
          .from('menu_categories')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return response.map((cat) => AppCategory.fromJson(cat)).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /*Future<List<AppCategory>> getCategories({String? establishmentId}) async {
    try {
      if (establishmentId == null || establishmentId.isEmpty) {
        return [];
      }

      // print('DEBUG: Using raw query approach...');

      // Use a raw query approach
      final response = await client
          .from('menu_categories')
          .select()
          .eq('establishment_id', establishmentId)
          .eq('is_active', true);

      // print('Raw query result: ${response.length} items');

      if (response.isEmpty) {
        // Try a different approach - maybe the UUID needs to be cast
        // print('Trying alternative approach...');

        // Get all categories and filter locally
        final allCategories = await client
            .from('menu_categories')
            .select('*')
            .eq('is_active', true);

        // print('All active categories: ${allCategories.length}');

        // Filter locally
        final filtered = allCategories.where((cat) {
          final catEstId = cat['establishment_id'].toString();
          // print('Comparing: $catEstId == $establishmentId');
          return catEstId == establishmentId;
        }).toList();

        // print('Locally filtered: ${filtered.length} items');

        return filtered.map((cat) => AppCategory.fromJson(cat)).toList();
      }

      return response.map((cat) => AppCategory.fromJson(cat)).toList();
    } catch (e) {
      // print('ERROR: $e');
      return [];
    }
  }*/
  // ==================== MENU ITEM METHODS ====================

  Future<List<MenuItem>> getMenuItemsByEstablishment(
    String establishmentId,
  ) async {
    try {
      final response = await client
          .from('menu_items')
          .select()
          .eq('establishment_id', establishmentId)
          .eq('is_available', true);

      return response.map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      print("Error fetching items: $e");
      return [];
    }
  }

  /*Future<List<MenuItem>> getMenuItemsByEstablishment(
    String establishmentId,
  ) async {
    try {
      // print('DEBUG: Getting items for establishment: $establishmentId');

      // Simple test query - get all items first
      // final testResponse = await client.from('menu_items').select('*').limit(5);

      // print('DEBUG: Test query result: ${testResponse.length} items');

      // Now try your actual query but with more logging
      final response = await client
          .from('menu_items')
          .select('*') // Remove the join temporarily
          .eq('is_available', true)
          .limit(10);

      // print('DEBUG: Actual query result: ${response.length} items');

      if (response.isEmpty) {
        // print('DEBUG: No items found');
        return [];
      }

      // print('DEBUG: First item data: ${response[0]}');

      final items = (response as List).map((item) {
        // print('DEBUG: Parsing item: ${item['name']}');
        return MenuItem.fromJson(item);
      }).toList();

      // print('DEBUG: Successfully parsed ${items.length} items');
      return items;
    } catch (e) {
      // print('FULL ERROR in getMenuItemsByEstablishment: $e');
      developer.log('Error fetching menu items: $e', name: 'SupabaseService');
      return [];
    }
  }*/

  Future<List<MenuItem>> searchMenuItems(
    String searchQuery, {
    String? establishmentId,
  }) async {
    try {
      // 1. Start Query - filtering on menu_items.establishment_id if provided
      var query = client
          .from('menu_items')
          .select(
            '*, menu_categories(id, name)',
          ) // select category details if needed, but not for filtering ID
          .eq('is_available', true)
          .ilike('name', '%$searchQuery%');

      // 2. Apply conditional filter directly on menu_items
      if (establishmentId != null) {
        query = query.eq('establishment_id', establishmentId);
      }

      // 3. Await response
      final response = await query;

      if (response.isEmpty) return [];

      return (response as List).map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log('Error searching menu items: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<MenuItem>> getBestsellers({String? establishmentId}) async {
    try {
      var query = client
          .from('menu_items')
          .select('*')
          .eq('is_bestseller', true)
          .eq('is_available', true);

      if (establishmentId != null) {
        query = query.eq('establishment_id', establishmentId);
      }

      final response = await query;

      if (response.isEmpty) return [];

      return (response as List).map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log('Error fetching bestsellers: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<List<MenuItem>> getRecommended({String? establishmentId}) async {
    try {
      // 1. Start Query
      var query = client
          .from('menu_items')
          .select('*')
          .eq('is_recommended', true)
          .eq('is_available', true);

      // 2. Apply Filter
      if (establishmentId != null) {
        query = query.eq('establishment_id', establishmentId);
      }

      // 3. Apply Limit (Modifier) last
      final response = await query.limit(8);

      if (response.isEmpty) return [];

      return (response as List).map((item) => MenuItem.fromJson(item)).toList();
    } catch (e) {
      developer.log(
        'Error fetching recommended items: $e',
        name: 'SupabaseService',
      );
      return [];
    }
  }

  Future<List<MenuItem>> getMenuItemsByCategory(String categoryId) async {
    try {
      final response = await client
          .from('menu_items')
          .select('*')
          .eq('category_id', categoryId)
          .eq('is_available', true)
          .order('name');

      return (response as List).map((json) => MenuItem.fromJson(json)).toList();
    } catch (e) {
      developer.log(
        'Error fetching menu items by category: $e',
        name: 'SupabaseService',
      );
      return [];
    }
  }

  Future<List<MenuItem>> getAllMenuItems() async {
    try {
      final response = await client
          .from('menu_items')
          .select('*')
          .eq('is_available', true)
          .order('name');

      return (response as List).map((json) => MenuItem.fromJson(json)).toList();
    } catch (e) {
      developer.log(
        'Error fetching all menu items: $e',
        name: 'SupabaseService',
      );
      return [];
    }
  }

  // ==================== ESTABLISHMENT METHODS ====================

  Future<Map<String, dynamic>?> getEstablishment(String establishmentId) async {
    try {
      final response = await client
          .from('establishments')
          .select()
          .eq('id', establishmentId)
          .eq('is_active', true)
          .single(); // Modifier goes last

      return response;
    } catch (e) {
      developer.log(
        'Error fetching establishment: $e',
        name: 'SupabaseService',
      );
      return null;
    }
  }

  // ==================== KITCHEN STAFF MANAGEMENT ====================

  /// Creates a new kitchen staff account.
  /// Uses a secondary SupabaseClient to perform the signup so the current
  /// operator session is not interrupted.
  Future<void> createKitchenStaffAccount({
    required String establishmentId,
    required String email,
    required String password,
    required String fullName,
    required String station,
  }) async {
    // 1. Create a secondary client for the new user registration
    // We provide a MemoryStorage to satisfy the PKCE requirement without persisting data
    final secondaryClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
    );

    try {
      // 2. Sign up the new user
      final authResponse = await secondaryClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'user_type': 'kitchen'},
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create account: User is null');
      }

      final newUserId = authResponse.user!.id;

      // 3. Use the MAIN client (Operator) to insert into public tables
      // Insert into users table
      await client.from('users').upsert({
        'id': newUserId,
        'email': email,
        'full_name': fullName,
        'phone': '',
        'user_type': 'kitchen',
        'dine_coins_balance': 0.00,
      });

      // Insert into kitchen_assignments table
      await client.from('kitchen_assignments').insert({
        'user_id': newUserId,
        'establishment_id': establishmentId,
        'assigned_station': station,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log(
        'Error creating kitchen staff: $e',
        name: 'SupabaseService',
      );
      rethrow;
    } finally {
      // Clean up secondary client
      await secondaryClient.dispose();
    }
  }

  Future<void> removeKitchenStaff(String assignmentId) async {
    try {
      // We perform a soft delete or hard delete on the assignment
      // For now, let's just delete the assignment record
      await client.from('kitchen_assignments').delete().eq('id', assignmentId);
    } catch (e) {
      developer.log(
        'Error removing kitchen staff: $e',
        name: 'SupabaseService',
      );
      rethrow;
    }
  }

  // ==================== OPERATOR HELPER METHODS ====================

  /// Gets the establishment ID for the current operator/staff.
  /// Priority:
  /// 1. Staff Assignments (Manager, Waiter, etc.) - Primary for staff
  /// 2. Establishments Table (Owner) - Fallback for owners
  /// 3. Kitchen Assignments - Fallback for kitchen staff
  Future<String?> getOperatorEstablishmentId() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      // 1. Check Staff Assignments (Managers, etc.)
      final staffAssignment = await client
          .from('staff_assignments')
          .select('establishment_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (staffAssignment != null) {
        return staffAssignment['establishment_id']?.toString();
      }

      // 2. Check Ownership (Establishments table)
      final ownedEstablishment = await client
          .from('establishments')
          .select('id')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (ownedEstablishment != null) {
        // Auto-create staff assignment for owner if missing
        try {
          await client.from('staff_assignments').upsert({
            'user_id': user.id,
            'establishment_id': ownedEstablishment['id'],
            'role': 'manager',
            'name': 'Owner',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
        return ownedEstablishment['id']?.toString();
      }

      // 3. Check Kitchen Assignments
      final kitchenAssignment = await client
          .from('kitchen_assignments')
          .select('establishment_id')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (kitchenAssignment != null) {
        return kitchenAssignment['establishment_id']?.toString();
      }

      return null;
    } catch (e) {
      developer.log(
        'Error getting operator establishment ID: $e',
        name: 'SupabaseService',
      );
      return null;
    }
  }

  // ==================== USER PROFILE METHODS ====================

  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final response = await client
          .from('users')
          .select('*')
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      developer.log('Error fetching user profile: $e', name: 'SupabaseService');
      return null;
    }
  }

  // ==================== FAVORITES METHODS ====================

  Future<List<MenuItem>> getUserFavorites() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return [];

      final response = await client
          .from('user_favorites')
          .select('menu_items(*)')
          .eq('user_id', user.id);

      return (response as List)
          .map((json) => MenuItem.fromJson(json['menu_items']))
          .toList();
    } catch (e) {
      developer.log('Error fetching favorites: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> addToFavorites(String menuItemId) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await client.from('user_favorites').insert({
        'user_id': user.id,
        'menu_item_id': menuItemId,
      });
    } catch (e) {
      developer.log('Error adding to favorites: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> removeFromFavorites(String menuItemId) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await client
          .from('user_favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('menu_item_id', menuItemId);
    } catch (e) {
      developer.log(
        'Error removing from favorites: $e',
        name: 'SupabaseService',
      );
      rethrow;
    }
  }

  // ==================== CART & ORDER METHODS ====================

  Future<void> addToCart(String menuItemId, int quantity) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check active orders
      var activeOrdersQuery = client
          .from('orders')
          .select('*')
          .eq('customer_id', user.id)
          .inFilter('status', ['pending', 'confirmed']);
      // Note: .limit(1) moved to the end if we were awaiting immediately,
      // but since we need the list to check isEmpty, we can just await the query.
      // Or strictly:
      final activeOrders = await activeOrdersQuery.limit(1);

      String orderId;

      if (activeOrders.isEmpty) {
        final newOrder = await client
            .from('orders')
            .insert({
              'customer_id': user.id,
              'establishment_id': await _getDefaultEstablishmentId(),
              'table_id': await _getDefaultTableId(),
              'status': 'pending',
              'total_amount': 0,
            })
            .select()
            .single();

        orderId = newOrder['id'] as String;
      } else {
        orderId = activeOrders.first['id'] as String;
      }

      // Get Item Price
      final menuItem = await client
          .from('menu_items')
          .select('price')
          .eq('id', menuItemId)
          .single();

      final price = (menuItem['price'] as num).toDouble();
      final lineTotal = price * quantity;

      // Check Existing Items
      final existingItems = await client
          .from('order_items')
          .select('*')
          .eq('order_id', orderId)
          .eq('menu_item_id', menuItemId);

      if (existingItems.isNotEmpty) {
        final existingItem = existingItems.first;
        final newQuantity = (existingItem['quantity'] as int) + quantity;
        final newLineTotal = price * newQuantity;

        await client
            .from('order_items')
            .update({'quantity': newQuantity, 'line_total': newLineTotal})
            .eq('id', existingItem['id']);
      } else {
        await client.from('order_items').insert({
          'order_id': orderId,
          'menu_item_id': menuItemId,
          'quantity': quantity,
          'unit_price': price,
          'line_total': lineTotal,
        });
      }

      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log('Error adding item to cart: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return [];

      final activeOrders = await client
          .from('orders')
          .select('*')
          .eq('customer_id', user.id)
          .inFilter('status', ['pending', 'confirmed'])
          .limit(1);

      if (activeOrders.isEmpty) return [];

      final orderId = activeOrders.first['id'] as String;

      final response = await client
          .from('order_items')
          .select('*, menu_items(id, name, description, image_url, price)')
          .eq('order_id', orderId);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('Error fetching cart items: $e', name: 'SupabaseService');
      return [];
    }
  }

  Future<void> updateCartItemQuantity(
    String orderItemId,
    int newQuantity,
  ) async {
    try {
      if (newQuantity <= 0) {
        await removeFromCart(orderItemId);
        return;
      }

      final orderItem = await client
          .from('order_items')
          .select('*, menu_items(price)')
          .eq('id', orderItemId)
          .single();

      final price = (orderItem['menu_items']['price'] as num).toDouble();
      final newLineTotal = price * newQuantity;

      await client
          .from('order_items')
          .update({'quantity': newQuantity, 'line_total': newLineTotal})
          .eq('id', orderItemId);

      final orderId = orderItem['order_id'] as String;
      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log(
        'Error updating cart item quantity: $e',
        name: 'SupabaseService',
      );
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await client
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      developer.log('Error updating order status: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<void> removeFromCart(String orderItemId) async {
    try {
      final orderItem = await client
          .from('order_items')
          .select('order_id')
          .eq('id', orderItemId)
          .single();

      final orderId = orderItem['order_id'] as String;

      await client.from('order_items').delete().eq('id', orderItemId);

      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log(
        'Error removing item from cart: $e',
        name: 'SupabaseService',
      );
      rethrow;
    }
  }

  Future<void> clearCart(String orderId) async {
    try {
      await client.from('order_items').delete().eq('order_id', orderId);

      await _updateOrderTotal(orderId);
    } catch (e) {
      developer.log('Error clearing cart: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getActiveOrder() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final activeOrders = await client
          .from('orders')
          .select('*')
          .eq('customer_id', user.id)
          .inFilter('status', ['pending', 'confirmed'])
          .limit(1);

      if (activeOrders.isEmpty) return null;

      return activeOrders.first;
    } catch (e) {
      developer.log('Error getting active order: $e', name: 'SupabaseService');
      return null;
    }
  }

  // ==================== PRIVATE HELPER METHODS ====================

  Future<void> _updateOrderTotal(String orderId) async {
    try {
      final orderItems = await client
          .from('order_items')
          .select('line_total')
          .eq('order_id', orderId);

      double total = 0;
      for (final item in orderItems) {
        total += (item['line_total'] as num).toDouble();
      }

      await client
          .from('orders')
          .update({'total_amount': total})
          .eq('id', orderId);
    } catch (e) {
      developer.log('Error updating order total: $e', name: 'SupabaseService');
    }
  }

  Future<String> _getDefaultEstablishmentId() async {
    try {
      final response = await client
          .from('establishments')
          .select('id')
          .eq('is_active', true)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['id'] as String;
      }
      return 'default-establishment-id';
    } catch (e) {
      developer.log(
        'Error getting default establishment: $e',
        name: 'SupabaseService',
      );
      return 'default-establishment-id';
    }
  }

  Future<String> _getDefaultTableId() async {
    try {
      final establishmentId = await _getDefaultEstablishmentId();
      final response = await client
          .from('tables')
          .select('id')
          .eq('establishment_id', establishmentId)
          .eq('is_available', true)
          .limit(1);

      if (response.isNotEmpty) {
        return response.first['id'] as String;
      }
      return 'default-table-id';
    } catch (e) {
      developer.log('Error getting default table: $e', name: 'SupabaseService');
      return 'default-table-id';
    }
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  Stream<List<MenuItem>> getMenuItemsStream() {
    return client
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .map((event) => event.map((json) => MenuItem.fromJson(json)).toList());
  }

  Stream<List<Map<String, dynamic>>> getOrderStream(String orderId) {
    return client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((event) => event.cast<Map<String, dynamic>>());
  }

  // Storage URL helper method
  /*String storagePublicUrl(String bucketName, String filePath) {
    return '$supabaseUrl/storage/v1/object/public/$bucketName/$filePath';
  }*/
  String storagePublicUrl(String bucket, String path) {
    return '${dotenv.env['SUPABASE_URL']}/storage/v1/object/public/$bucket/$path';
  }

  // Upload profile image to Supabase storage and return public URL
  Future<String?> uploadProfileImage(
    List<int> bytes,
    String originalFileName,
  ) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        developer.log('No authenticated user', name: 'SupabaseService');
        return null;
      }

      developer.log('Uploading ${bytes.length} bytes', name: 'SupabaseService');

      // Use simple filename extraction that works cross-platform
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalFileName.split('.').last;
      final fileName = '${user.id}/$timestamp.$extension';

      developer.log(
        'Uploading to profile_images/$fileName (${bytes.length} bytes)',
        name: 'SupabaseService',
      );

      // Upload bytes (works on both web and mobile)
      // Convert to Uint8List for uploadBinary
      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await client.storage
          .from('profile_images')
          .uploadBinary(fileName, uint8bytes);

      final publicUrl = client.storage
          .from('profile_images')
          .getPublicUrl(fileName);
      developer.log('Upload successful: $publicUrl', name: 'SupabaseService');
      return publicUrl;
    } catch (e) {
      developer.log(
        'Error uploading profile image: $e',
        name: 'SupabaseService',
        error: e,
      );
      return null;
    }
  }

  Future<String?> uploadRestaurantImage(
    dynamic file,
    String establishmentId,
  ) async {
    try {
      final fileName =
          'restaurant_${establishmentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'restaurants/$fileName';

      // Ensure we are using the correct file type
      // Using dynamic to handle both File (mobile) and XFile (web - though mostly File here)
      // but Supabase storage upload usually expects File or Uint8List
      // Assuming 'file' is of type File from dart:io for now as we are on Windows/Mobile

      if (file is! File) {
        throw Exception('Invalid file type. Expected File.');
      }

      await client.storage.from('images').upload(path, file);

      final publicUrl = storagePublicUrl('images', path);
      return publicUrl;
    } catch (e) {
      developer.log('Error uploading image: $e', name: 'SupabaseService');
      rethrow;
    }
  }

  // Upload menu item image
  Future<String?> uploadMenuItemImage(
    List<int> bytes,
    String originalFileName,
  ) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalFileName.split('.').last;
      final fileName = '${user.id}/menu_item_$timestamp.$extension';

      // Use 'images' bucket (or create 'menu_items' if you prefer, but sticking to valid buckets)
      // The user seems to use 'images' or 'profile_images'. Let's use 'images'.
      const bucketName = 'images';

      final uint8bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await client.storage.from(bucketName).uploadBinary(fileName, uint8bytes);

      final publicUrl = client.storage.from(bucketName).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      developer.log(
        'Error uploading menu item image: $e',
        name: 'SupabaseService',
      );
      return null;
    }
  }
}

class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async {
    return _storage[key];
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _storage.remove(key);
  }
}
