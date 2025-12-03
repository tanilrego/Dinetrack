//lib/core/models/menu_models.dart
class AppCategory {
  final String id;
  final String establishmentId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;

  AppCategory({
    required this.id,
    required this.establishmentId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] as String,
      establishmentId: json['establishment_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'establishment_id': establishmentId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String categoryId;
  final bool isAvailable;
  final bool isBestseller;
  final bool isRecommended;
  final double rating;
  final int? preparationTime;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    required this.categoryId,
    this.isAvailable = true,
    this.isBestseller = false,
    this.isRecommended = false,
    this.rating = 4.5,
    this.preparationTime,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      description: json['description'],
      imageUrl: json['image_url'],
      categoryId: json['category_id'] ?? '',
      isAvailable: json['is_available'] ?? true,
      isBestseller: json['is_bestseller'] ?? false,
      isRecommended: json['is_recommended'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      preparationTime: json['preparation_time'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'category_id': categoryId,
      'is_available': isAvailable,
      'is_bestseller': isBestseller,
      'is_recommended': isRecommended,
      'rating': rating,
      'preparation_time': preparationTime,
    };
  }

  String get formattedPrice {
    return '${price.toStringAsFixed(0)} MWK';
  }
}

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String userType;
  final double dineCoinsBalance;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    required this.userType,
    required this.dineCoinsBalance,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      userType: json['user_type'] as String,
      dineCoinsBalance: (json['dine_coins_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'user_type': userType,
      'dine_coins_balance': dineCoinsBalance,
    };
  }
}

class CartItem {
  final MenuItem menuItem;
  final int quantity;
  final String? specialInstructions;

  CartItem({
    required this.menuItem,
    required this.quantity,
    this.specialInstructions,
  });

  double get totalPrice => menuItem.price * quantity;

  // Enhanced copyWith method for better immutability
  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
    );
  }

  // Helper method to increase quantity
  CartItem increaseQuantity([int amount = 1]) {
    return copyWith(quantity: quantity + amount);
  }

  // Helper method to decrease quantity
  CartItem decreaseQuantity([int amount = 1]) {
    return copyWith(quantity: quantity - amount);
  }

  // Convert to JSON for potential persistence
  Map<String, dynamic> toJson() {
    return {
      'menu_item': menuItem.toJson(),
      'quantity': quantity,
    };
  }

  // Create from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      menuItem: MenuItem.fromJson(json['menu_item']),
      quantity: json['quantity'] as int,
    );
  }
}