import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FavoriteItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String brand;
  final String description;

  FavoriteItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.brand = 'Unknown Brand',
    this.description = 'No description available',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'brand': brand,
      'description': description,
    };
  }

  static FavoriteItem fromMap(Map<String, dynamic> map) {
    return FavoriteItem(
      id: map['id'],
      name: map['name'],
      price: map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
      imageUrl: map['imageUrl'],
      brand: map['brand'] ?? 'Unknown Brand',
      description: map['description'] ?? 'No description available',
    );
  }
}

class Favorites with ChangeNotifier {
  Map<String, FavoriteItem> _items = {};
  String? _userId;

  Map<String, FavoriteItem> get items {
    return {..._items};
  }

  bool containsKey(String productId) {
    return _items.containsKey(productId);
  }

  void addItem(String productId, String name, double price, String imageUrl,
      {String brand = 'Unknown Brand', String description = 'No description available'}) {
    if (!_items.containsKey(productId)) {
      _items.putIfAbsent(
        productId,
            () => FavoriteItem(
          id: productId,
          name: name,
          price: price,
          imageUrl: imageUrl,
          brand: brand,
          description: description,
        ),
      );
      notifyListeners();
      _saveFavorites();
    }
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _saveFavorites();
  }

// في favorites_model.dart
  void setUserId(String userId) {
    print("Setting user ID in Favorites: $userId");
    _userId = userId;
    if (_userId != null) {
      _loadFavorites(); // تحميل المفضلة للمستخدم
    } else {
      _items = {}; // مسح المفضلة إذا لم يكن هناك مستخدم
      notifyListeners();
    }
  }

  // استبدال دالة _loadFavorites
  Future<void> _loadFavorites() async {
    if (_userId == null) return;

    try {
      final dbRef = FirebaseDatabase.instance.ref().child(
          'users/$_userId/favorites');
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        _items = values.map((key, value) {
          final item = FavoriteItem.fromMap(Map<String, dynamic>.from(value));
          return MapEntry(key, item);
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

// استبدال دالة _saveFavorites
  Future<void> _saveFavorites() async {
    if (_userId == null) {
      print("❌ Cannot save favorites: No user ID");
      return;
    }

    try {
      final dbRef = FirebaseDatabase.instance.ref().child(
          'users/$_userId/favorites');
      await dbRef.set(_items.map((key, value) => MapEntry(key, value.toMap())));
      print("✅ Favorites saved successfully for user: $_userId");
    } catch (e) {
      print('❌ Error saving favorites: $e');
    }
  }
}