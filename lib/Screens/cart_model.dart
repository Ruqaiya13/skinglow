import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final double originalPrice; // ✅ حفظ السعر الأصلي
  final Map<String, dynamic>? discount; // ✅ حفظ بيانات الخصم

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.originalPrice,
    this.discount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice, // ✅ حفظ السعر الأصلي
      'discount': discount, // ✅ حفظ بيانات الخصم
    };
  }

  static CartItem fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      name: map['name'],
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : map['price'],
      quantity: map['quantity'],
      imageUrl: map['imageUrl'],
      originalPrice: (map['originalPrice'] is int)
          ? (map['originalPrice'] as int).toDouble()
          : (map['originalPrice'] ?? map['price']), // ✅ fallback إذا لم يوجد
      discount: map['discount'] != null
          ? Map<String, dynamic>.from(map['discount'])
          : null, // ✅ تحميل بيانات الخصم
    );
  }

  // ✅ حساب السعر بعد الخصم
  double get discountedPrice {
    if (discount != null && discount!['discountValue'] != null) {
      double discountValue = discount!['discountValue'].toDouble();
      String discountType = discount!['discountType'] ?? 'percentage';

      if (discountType == 'percentage') {
        return originalPrice * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        double finalPrice = originalPrice - discountValue;
        return finalPrice < 0 ? 0 : finalPrice;
      }
    }
    return price;
  }

  // ✅ حساب قيمة الخصم
  double get discountAmount {
    return originalPrice - discountedPrice;
  }

  // ✅ التحقق من وجود خصم
  bool get hasDiscount {
    return discount != null && discount!['discountValue'] != null;
  }
}

class Cart with ChangeNotifier {
  Map<String, CartItem> _items = {};
  String? _currentUserId;

  // 🔥 جعل السلة تعتمد على اليوزر الحالي
  String? get currentUserId => _currentUserId;

  Map<String, CartItem> get items {
    return {..._items};
  }

  int get itemCount {
    int count = 0;
    _items.forEach((key, item) {
      count += item.quantity;
    });
    return count;
  }

  int get uniqueItemCount => _items.length;

  // ✅ المجموع الكلي بعد الخصم
  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.discountedPrice * cartItem.quantity;
    });
    return total;
  }

  // ✅ المجموع الكلي بدون خصم
  double get totalAmountWithoutDiscount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.originalPrice * cartItem.quantity;
    });
    return total;
  }

  // ✅ إجمالي الخصم
  double get totalDiscount {
    double discount = 0.0;
    _items.forEach((key, cartItem) {
      if (cartItem.hasDiscount) {
        discount += cartItem.discountAmount * cartItem.quantity;
      }
    });
    return discount;
  }

  // 🔥 تغيير اليوزر وتحميل سلته
  void setUserId(String userId) {
    print("🔄 Switching cart to user: $userId");

    if (_currentUserId != userId) {
      // حفظ السلة الحالية قبل التبديل
      if (_currentUserId != null) {
        _saveCartItems();
      }

      _currentUserId = userId;
      _items.clear(); // تنظيف السلة القديمة
      _loadCartItems(); // تحميل سلة اليوزر الجديد
    }
  }

  // 🔥 تسجيل الخروج - تنظيف السلة
  void clearUser() {
    print("🚪 Clearing cart for logout");
    _currentUserId = null;
    _items.clear();
    notifyListeners();
  }

  Future<void> _loadCartItems() async {
    if (_currentUserId == null) {
      print("❌ Cannot load cart: No user ID");
      return;
    }

    try {
      final dbRef = FirebaseDatabase.instance.ref().child('users/$_currentUserId/cart');
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _items = data.map((key, value) {
          final item = CartItem.fromMap(Map<String, dynamic>.from(value));
          return MapEntry(key.toString(), item);
        });
        notifyListeners();
        print("✅ Cart loaded for user $_currentUserId: ${_items.length} items");

        // ✅ طباعة تفاصيل الخصومات
        _items.forEach((key, item) {
          if (item.hasDiscount) {
            print("🎯 Discounted item: ${item.name} - Original: ${item.originalPrice}, Discounted: ${item.discountedPrice}");
          }
        });
      } else {
        _items = {};
        notifyListeners();
        print("ℹ️ No cart items found for user $_currentUserId");
      }
    } catch (e) {
      print('❌ Error loading cart items: $e');
    }
  }

  Future<void> _saveCartItems() async {
    if (_currentUserId == null) {
      print("❌ Cannot save cart: No user ID");
      return;
    }

    try {
      final dbRef = FirebaseDatabase.instance.ref().child('users/$_currentUserId/cart');

      if (_items.isEmpty) {
        await dbRef.remove();
        print("🗑️ Cart cleared from Firebase for user $_currentUserId");
      } else {
        await dbRef.set(_items.map((key, value) => MapEntry(key, value.toMap())));
        print("💾 Cart saved for user $_currentUserId: ${_items.length} items");

        // ✅ طباعة تفاصيل الخصومات المحفوظة
        _items.forEach((key, item) {
          if (item.hasDiscount) {
            print("💾 Saved discounted item: ${item.name} - Discount: ${item.discount}");
          }
        });
      }
    } catch (e) {
      print('❌ Error saving cart items: $e');
    }
  }

  // ✅ دالة معدلة لتطبيق الخصم
  void addItem(
      String productId,
      String name,
      double price,
      String imageUrl, {
        double? originalPrice,
        Map<String, dynamic>? discount,
      }) {
    if (_currentUserId == null) {
      print("❌ Cannot add item: No user logged in");
      return;
    }

    if (productId.isEmpty || productId == 'unknown_product') {
      print("❌ Cannot add item: Invalid product ID");
      return;
    }

    // ✅ حساب السعر النهائي مع الخصم
    double finalPrice = price;
    double finalOriginalPrice = originalPrice ?? price;

    if (discount != null && discount['discountValue'] != null) {
      double discountValue = discount['discountValue'].toDouble();
      String discountType = discount['discountType'] ?? 'percentage';

      if (discountType == 'percentage') {
        finalPrice = finalOriginalPrice * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = finalOriginalPrice - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }

      print("🎯 Applying discount: $name - Original: $finalOriginalPrice, Discounted: $finalPrice");
    }

    if (_items.containsKey(productId)) {
      _items[productId]!.quantity += 1;
      print("➕ Increased quantity for user $_currentUserId: $name");
    } else {
      _items[productId] = CartItem(
        id: productId,
        name: name,
        price: finalPrice, // ✅ استخدم السعر بعد الخصم
        quantity: 1,
        imageUrl: imageUrl,
        originalPrice: finalOriginalPrice, // ✅ حفظ السعر الأصلي
        discount: discount, // ✅ حفظ بيانات الخصم
      );
      print("🛒 Added new product for user $_currentUserId: $name");

      if (discount != null) {
        print("🎯 With discount: ${discount['discountValue']}% - Price: $finalPrice");
      }
    }
    notifyListeners();
    _saveCartItems();
  }

  void removeItem(String productId) {
    if (_currentUserId == null) return;

    if (_items.containsKey(productId)) {
      final productName = _items[productId]!.name;
      _items.remove(productId);
      notifyListeners();
      _saveCartItems();
      print("🗑️ Removed product for user $_currentUserId: $productName");
    }
  }

  void updateQuantity(String productId, int newQuantity) {
    if (_currentUserId == null) return;

    if (_items.containsKey(productId)) {
      if (newQuantity <= 0) {
        removeItem(productId);
      } else {
        _items[productId]!.quantity = newQuantity;
        notifyListeners();
        _saveCartItems();
        print("🔄 Updated quantity for user $_currentUserId: ${_items[productId]!.name}");
      }
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _saveCartItems();
    print("🧹 Cart cleared for user $_currentUserId");
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  int getItemQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  // ✅ الحصول على تفاصيل المنتج مع الخصم
  CartItem? getItem(String productId) {
    return _items[productId];
  }

  // ✅ التحقق من وجود خصم على منتج معين
  bool hasDiscountOnProduct(String productId) {
    return _items[productId]?.hasDiscount ?? false;
  }

  // ✅ الحصول على قيمة الخصم لمنتج معين
  double getDiscountForProduct(String productId) {
    return _items[productId]?.discountAmount ?? 0.0;
  }
}