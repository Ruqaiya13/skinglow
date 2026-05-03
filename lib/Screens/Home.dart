import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/cart.dart';
import 'package:skinglow/Screens/favorite.dart';
import 'package:skinglow/Screens/product_detail_screen.dart';
import 'package:skinglow/Screens/profile.dart';
import 'package:skinglow/Screens/search.dart';
import 'package:skinglow/Screens/userNotification.dart';
import 'package:skinglow/SkinAnalysis/skinAnalysis.dart';
import 'package:skinglow/SkinAnalysis/skin_type_provider.dart';
import 'package:skinglow/Screens/barcodeScanner.dart';
import 'package:skinglow/Screens/cart_model.dart';
import 'package:skinglow/Screens/favorites_model.dart';
import '../AdminManagement/EditProductScreen.dart';
import '../AdminManagement/add_product_screen.dart';
import '../SkinAnalysis/skinAnalysisAi/skin_analysis_py.dart';
import 'NotificationHistoryScreen.dart';


class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  bool hasError = false;
  bool _isAdmin = false;
  bool _isInitialLoad = true;
  List<Map<String, dynamic>> activeCoupons = [];
  List<Map<String, dynamic>> _bestSellers = [];
  List<Map<String, dynamic>> _discountedProducts = [];
  List<Map<String, dynamic>> _recommendedProducts = [];
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;
  late StreamSubscription? _notificationListener;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus().then((_) {
      _loadProductsFromFirebase();
      _loadActiveCoupons();
      // ✅ تحميل عدد الإشعارات غير المقروءة
      _loadUnreadNotificationsCount();
      // ✅ إعداد مستمع للإشعارات
      _setupNotificationListener();
    });

    // ✅ تحميل نوع البشرة من Firebase عند بدء التطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final skinProvider = context.read<SkinTypeProvider>();
      skinProvider.loadForCurrentUser().then((_) {
        final currentUser = FirebaseAuth.instance.currentUser;
        print('🔄 Skin type loaded for user: ${currentUser?.uid} - ${skinProvider.skinType}');
      });
    });

    Future.delayed(Duration(seconds: 2), () {
      if (products.isNotEmpty && _bestSellers.isEmpty) {
        _loadBestSellers().then((bestSellers) {
          if (mounted) {
            setState(() {
              _bestSellers = bestSellers;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // ✅ تنظيف المستمع عند إغلاق الصفحة
    _notificationListener?.cancel();
    super.dispose();
  }

  // ✅ دالة إعداد مستمع للإشعارات في الوقت الحقيقي
  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationListener = FirebaseDatabase.instance
        .ref('users/${user.uid}/notifications')
        .onValue
        .listen((event) {
      if (mounted) {
        _loadUnreadNotificationsCount();
      }
    });
  }

  // ✅ دالة لتحميل عدد الإشعارات غير المقروءة للمستخدم
  Future<void> _loadUnreadNotificationsCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}/notifications')
          .orderByChild('isRead')
          .equalTo(false)
          .get();

      if (snapshot.exists) {
        final count = snapshot.children.length;
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = count;
          });
        }
        print('📊 User has $count unread notifications');
      } else {
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = 0;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading unread notifications count: $e');
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      isLoading = true;
    });
    await _loadProductsFromFirebase();
    await _loadActiveCoupons();

    // تحميل Best Sellers بعد تحميل المنتجات
    if (products.isNotEmpty) {
      final bestSellers = await _loadBestSellers();
      setState(() {
        _bestSellers = bestSellers;
        _discountedProducts = _getDiscountedProducts();
      });
    }

    print("🔄 Refresh completed - Total products: ${products.length}");
  }

  // دالة للتحقق من حالة الأدمن
  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
        DatabaseEvent snapshot = await userRef.once();

        if (snapshot.snapshot.value != null) {
          Map<dynamic, dynamic> userData = snapshot.snapshot.value as Map<dynamic, dynamic>;
          String role = userData['role'] ?? 'user';
          if (mounted) {
            setState(() {
              _isAdmin = role == 'admin';
            });
          }
          print('User role: $role, isAdmin: $_isAdmin');
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  // دالة لتحميل الكوبونات النشطة
  Future<void> _loadActiveCoupons() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref().child("discountCoupons");
      final snapshot = await dbRef.get();

      print("🔍 Checking for coupons in Firebase Realtime Database...");

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        final now = DateTime.now();

        print("✅ Found ${values.length} coupons in database");

        List<Map<String, dynamic>> loadedCoupons = [];

        values.forEach((key, value) {
          try {
            final coupon = Map<String, dynamic>.from(value);
            coupon['id'] = key;

            print("🎫 Processing coupon: ${coupon['code']}");

            // ✅ الفلترة الجديدة: نعرض فقط الكوبونات العامة وليس خصومات المنتجات
            final String? couponType = coupon['type'];
            final bool isProductDiscount = couponType == 'product_boost' ||
                coupon['targetProduct'] != null;

            if (isProductDiscount) {
              print("   ⏩ Skipping - This is a product-specific discount");
              return; // نتخطى خصومات المنتجات
            }

            // Convert timestamp to DateTime
            DateTime startDate;
            DateTime endDate;

            if (coupon['startDate'] is int) {
              startDate = DateTime.fromMillisecondsSinceEpoch(coupon['startDate']);
              endDate = DateTime.fromMillisecondsSinceEpoch(coupon['endDate']);
            } else {
              // Fallback if dates are stored differently
              startDate = DateTime.now().subtract(Duration(days: 1));
              endDate = DateTime.now().add(Duration(days: 30));
            }

            coupon['startDate'] = startDate;
            coupon['endDate'] = endDate;

            // Check if coupon is active and valid
            final bool isActive = coupon['isActive'] == true;
            final bool isValidDate = now.isAfter(startDate) && now.isBefore(endDate);
            final bool isActiveResult = isActive && isValidDate;

            print("   Code: ${coupon['code']}, Active: $isActiveResult, Type: ${couponType ?? 'general'}");

            if (isActiveResult) {
              loadedCoupons.add(coupon);
            }
          } catch (e) {
            print("❌ Error processing coupon $key: $e");
          }
        });

        if (mounted) {
          setState(() {
            activeCoupons = loadedCoupons;
          });
        }

        print("✅ Active COUPONS (not product discounts) loaded: ${activeCoupons.length}");

        // Print active coupons for verification
        for (var coupon in activeCoupons) {
          print("📋 ACTIVE COUPON - Code: ${coupon['code']}, Discount: ${coupon['discountValue']}%");
        }
      } else {
        print("⚠️ No coupons found in Firebase");
        if (mounted) {
          setState(() {
            activeCoupons = [];
          });
        }
      }
    } catch (e) {
      print("❌ Error loading coupons: $e");
      if (mounted) {
        setState(() {
          activeCoupons = [];
        });
      }
    }
  }

  Future<void> _loadProductsFromFirebase() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref().child("products");
      final snapshot = await dbRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        final loadedProducts = values.entries.map((entry) {
          final product = Map<String, dynamic>.from(entry.value);
          product['id'] = entry.key;
          product['barcode'] = product['id'];

          // ✅ التحقق من وجود خصم
          if (product['discount'] != null) {
            print("🎯 Product with discount: ${product['name']}");
          }

          return product;
        }).toList();

        if (mounted) {
          setState(() {
            products = loadedProducts;
            isLoading = false;
            hasError = false;
            _discountedProducts = _getDiscountedProducts();
          });
        }

        // تحميل Best Sellers بعد تحميل المنتجات
        if (products.isNotEmpty) {
          final bestSellers = await _loadBestSellers();
          if (mounted) {
            setState(() {
              _bestSellers = bestSellers;
            });
          }
        }

        print("✅ Products loaded from Firebase: ${products.length} items");
        print("🔥 Best sellers loaded: ${_bestSellers.length} items");
        print("🎯 Discounted products: ${_discountedProducts.length} items");

        // ✅ طباعة عدد المنتجات المخفضة
        int discountedCount = products.where((p) => p['discount'] != null).length;
        print("💰 Products with discount: $discountedCount");
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
          });
        }
        print("⚠️ No products found in Firebase");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
      print("❌ Error loading from Firebase: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkinTypeProvider>(
      builder: (context, skinProvider, child) {
        // ✅ تحديث المنتجات الموصى بها عندما يتغير نوع البشرة أو عند التحميل الأول
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (skinProvider.skinType != null &&
              skinProvider.skinType!.isNotEmpty &&
              products.isNotEmpty &&
              _recommendedProducts.isEmpty &&
              _shouldUpdateRecommendations(skinProvider.skinType!)) {
            _updateRecommendedProducts(skinProvider.skinType!);
          }
        });

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Color(0xFFFFE4F3),
            elevation: 0,
            leading: Row(
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.shopping_cart, color: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CartScreen()),
                        );
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Consumer<Cart>(
                        builder: (_, cart, child) => Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // ✅ أيقونة الإشعارات المعدلة - تعمل لكل المستخدمين
              IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.notifications, color: Colors.blue),
                    if (_unreadNotificationsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                            style: TextStyle(
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
                onPressed: () {
                  // ✅ إذا كان أدمن → NotificationHistoryScreen
                  // ✅ إذا كان مستخدم عادي → UserNotificationsScreen
                  if (_isAdmin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NotificationHistoryScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserNotificationsScreen()),
                    ).then((_) {
                      // ✅ تحديث عدد الإشعارات بعد العودة
                      if (mounted) {
                        _loadUnreadNotificationsCount();
                      }
                    });
                  }
                },
                tooltip: _isAdmin ? "System Notifications" : "My Notifications",
              ),

              // Barcode Scanner
              IconButton(
                icon: Icon(Icons.qr_code, color: Colors.black),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
                  );
                },
              ),

              // Test Coupons Button
              if (_isAdmin)
                IconButton(
                  icon: Icon(Icons.local_offer, color: Colors.orange),
                  onPressed: () {
                    print("🔄 Manually loading coupons...");
                    _loadActiveCoupons();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Found ${activeCoupons.length} active coupons'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  tooltip: "Test Coupons",
                ),
              if (_isAdmin)
                IconButton(
                  icon: Icon(Icons.add, color: Colors.green),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddProductScreen()),
                    );
                    await _refreshProducts();
                  },
                  tooltip: "Add Product",
                ),

              // Search
              IconButton(
                icon: Icon(Icons.search, color: Colors.grey[700]),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchPage(products: products, searchQuery: '',)),
                  );
                },
              ),

              // Refresh
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _refreshProducts,
                tooltip: "Refresh products",
              ),
            ],
          ),
          body: _buildBody(skinProvider.skinType),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildBody(String? userSkinType) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 50, color: Colors.red),
            SizedBox(height: 16),
            Text("Failed to load products"),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProductsFromFirebase,
              child: Text("Try Again"),
            ),
            if (_isAdmin) ...[
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProductScreen()),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('Add First Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No products available",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (_isAdmin) ...[
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddProductScreen()),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('Add First Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ✅ شرط مهم: لا يظهر قسم Recommended إلا إذا كان هناك نوع بشرة محدد
    bool hasValidSkinType = userSkinType != null &&
        userSkinType.isNotEmpty &&
        userSkinType != 'Not analyzed yet' &&
        userSkinType != 'Not analyzed' &&
        userSkinType != 'No skin type' &&
        userSkinType != 'Error loading';

    bool showRecommendedSection = hasValidSkinType && _recommendedProducts.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _refreshProducts,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDiscountsSection(),

            // ✅ قسم المنتجات الموصى بها بناءً على نوع البشرة
            if (showRecommendedSection)
              _buildRecommendedSection(userSkinType!)
            else if (hasValidSkinType && _recommendedProducts.isEmpty)
              _buildAnalyzeSkinSection() // ✅ قسم تشجيعي للتحليل إذا لم توجد توصيات
            else if (!hasValidSkinType)
                _buildAnalyzeSkinSection(),

            // قسم المنتجات المخفضة
            _buildDiscountedProductsSection(),

            // قسم Best Sellers
            _buildBestSellersSection(),

            // قسم All Products
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'All Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF914D74),
                ),
              ),
            ),
            _buildProductGrid(),
          ],
        ),
      ),
    );
  }

  // ✅ دالة للتحقق إذا كان يجب تحديث الـ Recommendations
  bool _shouldUpdateRecommendations(String newSkinType) {
    // إذا كان الـ Recommendations فارغاً أو نوع البشرة تغير
    if (_recommendedProducts.isEmpty) return true;

    // يمكن إضافة منطق إضافي هنا إذا لزم
    return true;
  }

  // ✅ دالة لتحديث المنتجات الموصى بها
  void _updateRecommendedProducts(String skinType) {
    if (products.isEmpty) return;

    print('🔄 Home: Updating recommended products for: $skinType');

    try {
      List<Map<String, dynamic>> filteredProducts = [];

      // دالة لتحليل نوع البشرة وترتيبها حسب الأولوية
      List<String> getSkinTypePriority(String skinType) {
        final Map<String, List<String>> skinTypeMap = {
          'Dry': ['Dry', 'Normal', 'Sensitive'],
          'Oily': ['Oily', 'Combination', 'Normal'],
          'Combination': ['Combination', 'Normal', 'Oily'],
          'Normal': ['Normal', 'All', 'Sensitive'],
          'Sensitive': ['Sensitive', 'Dry', 'Normal'],
        };

        return skinTypeMap[skinType] ?? ['All'];
      }

      final priorityList = getSkinTypePriority(skinType);
      List<Map<String, dynamic>> allMatches = [];

      for (var priority in priorityList) {
        List<Map<String, dynamic>> matches = products.where((product) {
          final skinTypesData = product['skinTypes'];
          if (skinTypesData == null) return false;

          List<String> productSkinTypes = [];

          if (skinTypesData is Map) {
            productSkinTypes = skinTypesData.keys.where((key) {
              final value = skinTypesData[key];
              return value == true || value == 'true' || value == 1;
            }).map((e) => e.toString()).toList();
          } else if (skinTypesData is List) {
            productSkinTypes = skinTypesData.map((e) => e.toString()).toList();
          } else if (skinTypesData is String) {
            productSkinTypes = [skinTypesData];
          }

          // حساب درجة المطابقة
          int matchScore = 0;
          for (var p in priorityList) {
            for (var productType in productSkinTypes) {
              if (productType.toLowerCase() == p.toLowerCase()) {
                matchScore += (priorityList.length - priorityList.indexOf(p));
              } else if (productType.toLowerCase().contains(p.toLowerCase()) ||
                  p.toLowerCase().contains(productType.toLowerCase())) {
                matchScore += 1;
              }
            }
          }

          return matchScore > 0;
        }).map((product) {
          // حساب درجة المطابقة للمنتجات المطابقة
          final skinTypesData = product['skinTypes'];
          List<String> productSkinTypes = [];

          if (skinTypesData is Map) {
            productSkinTypes = skinTypesData.keys.where((key) {
              final value = skinTypesData[key];
              return value == true || value == 'true' || value == 1;
            }).map((e) => e.toString()).toList();
          } else if (skinTypesData is List) {
            productSkinTypes = skinTypesData.map((e) => e.toString()).toList();
          } else if (skinTypesData is String) {
            productSkinTypes = [skinTypesData];
          }

          int matchScore = 0;
          for (var priority in priorityList) {
            for (var productType in productSkinTypes) {
              if (productType.toLowerCase() == priority.toLowerCase()) {
                matchScore += (priorityList.length - priorityList.indexOf(priority));
              } else if (productType.toLowerCase().contains(priority.toLowerCase()) ||
                  priority.toLowerCase().contains(productType.toLowerCase())) {
                matchScore += 1;
              }
            }
          }

          return {
            ...product,
            'matchScore': matchScore,
          };
        }).toList();

        allMatches.addAll(matches);
      }

      // ترتيب المنتجات حسب درجة المطابقة (من الأعلى للأقل)
      allMatches.sort((a, b) => (b['matchScore'] ?? 0).compareTo(a['matchScore'] ?? 0));

      // أخذ أفضل 5 منتجات
      filteredProducts = allMatches.take(5).toList();

      // إذا لم نجد منتجات مطابقة، نأخذ أفضل المبيعات
      if (filteredProducts.isEmpty && _bestSellers.isNotEmpty) {
        filteredProducts = _bestSellers.take(3).toList();
        print('⚠️ No skin-specific products found, using best sellers instead');
      }

      // إزالة التكرارات
      final seenIds = <String>{};
      filteredProducts = filteredProducts.where((product) {
        final id = product['id']?.toString();
        if (id == null || seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      print('✅ Home: Found ${filteredProducts.length} recommended products for $skinType skin');

      if (mounted) {
        setState(() {
          _recommendedProducts = filteredProducts;
        });
      }
    } catch (e) {
      print('❌ Home: Error updating recommended products: $e');
      if (mounted) {
        setState(() {
          _recommendedProducts = [];
        });
      }
    }
  }

  // ✅ قسم لتشجيع المستخدم على تحليل البشرة
  Widget _buildAnalyzeSkinSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF8F0F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF914D74).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.spa,
              size: 50,
              color: Color(0xFF914D74),
            ),
            SizedBox(height: 12),
            Text(
              'Discover Your Perfect Skincare',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF914D74),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Take our skin analysis test to get personalized product recommendations tailored specifically for your skin type',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SkinAnalysisPy()),
                );
              },
              icon: Icon(Icons.camera_alt),
              label: Text('Analyze Your Skin Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF914D74),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ قسم المنتجات الموصى بها بناءً على نوع البشرة
  Widget _buildRecommendedSection(String userSkinType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.spa, color: Color(0xFF914D74), size: 24),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended For You',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF914D74),
                        ),
                      ),
                      Text(
                        'Perfect for $userSkinType skin',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF914D74).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.face, size: 14, color: Color(0xFF914D74)),
                    SizedBox(width: 4),
                    Text(
                      userSkinType,
                      style: TextStyle(
                        color: Color(0xFF914D74),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 8),

        Container(
          height: 260,
          child: _recommendedProducts.isNotEmpty
              ? ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recommendedProducts.length,
            itemBuilder: (context, index) {
              return _buildRecommendedProductCard(_recommendedProducts[index]);
            },
          )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'No recommended products found',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // ✅ كارت خاص للمنتجات الموصى بها
  Widget _buildRecommendedProductCard(Map<String, dynamic> product) {
    double price = (product['price'] != null) ? double.parse(product['price'].toString()) : 0.0;

    // ✅ التحقق من وجود خصم
    bool hasDiscount = product['discount'] != null;
    Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(product['discount'])
        : null;

    double? discountValue = discountData?['discountValue']?.toDouble();
    String? discountType = discountData?['discountType'];

    // حساب السعر بعد الخصم
    double finalPrice = price;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = price * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = price - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Consumer<Cart>(
      builder: (context, cart, child) {
        return Container(
          width: 180,
          margin: EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شارة "Recommended" مميزة
                      Container(
                        height: 30,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF914D74),
                              Color(0xFFD4A5C8),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spa, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Recommended',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // صورة المنتج
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          child: _buildProductImage(product['image'], product['name']),
                        ),
                      ),

                      // معلومات المنتج
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['brand'] ?? 'Unknown Brand',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),

                            // ✅ عرض أنواع البشرة المناسبة
                            _buildSkinTypeBadges(product),

                            SizedBox(height: 4),

                            // ✅ عرض السعر مع الخصم
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    'OMR ${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  'OMR ${finalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: hasDiscount ? Colors.red : Color(0xFF914D74),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // زر إضافة إلى السلة
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        _addToCart(context, product, cart);
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFF914D74),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ دالة لعرض أنواع البشرة المناسبة للمنتج
  Widget _buildSkinTypeBadges(Map<String, dynamic> product) {
    final skinTypesData = product['skinTypes'];
    List<String> skinTypes = [];

    if (skinTypesData != null) {
      if (skinTypesData is Map) {
        skinTypes = skinTypesData.keys.where((key) {
          final value = skinTypesData[key];
          return value == true || value == 'true' || value == 1;
        }).map((e) => e.toString()).toList();
      } else if (skinTypesData is List) {
        skinTypes = skinTypesData.map((e) => e.toString()).toList();
      } else if (skinTypesData is String) {
        skinTypes = [skinTypesData];
      }
    }

    // عرض أول نوعين فقط للحفاظ على المساحة
    if (skinTypes.isEmpty) return SizedBox();

    final displayTypes = skinTypes.length > 2 ? skinTypes.sublist(0, 2) : skinTypes;

    return Wrap(
      spacing: 4,
      children: displayTypes.map((type) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Color(0xFF914D74).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: Color(0xFF914D74),
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // دالة لجلب إحصائيات المبيعات من Firebase
  Future<Map<String, int>> _getProductSalesData() async {
    try {
      final ordersRef = FirebaseDatabase.instance.ref().child("all_orders");
      final snapshot = await ordersRef.get();

      Map<String, int> productSales = {};

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> orders = snapshot.value as Map;

        orders.forEach((orderKey, orderValue) {
          try {
            final order = Map<String, dynamic>.from(orderValue);
            dynamic items = order['items'] ?? order['products'] ?? order['cartItems'];

            if (items != null) {
              if (items is Map) {
                items.forEach((key, item) {
                  if (item is Map) {
                    final productId = item['productId'] ?? item['id'] ?? key.toString();
                    final quantity = item['quantity'] ?? 1;
                    final normalizedProductId = productId.toString().trim();
                    productSales[normalizedProductId] = (productSales[normalizedProductId] ?? 0) + (quantity is int ? quantity : 1);
                  }
                });
              } else if (items is List) {
                for (var item in items) {
                  if (item is Map) {
                    final productId = item['productId'] ?? item['id'] ?? 'unknown';
                    final quantity = item['quantity'] ?? 1;
                    final normalizedProductId = productId.toString().trim();
                    productSales[normalizedProductId] = (productSales[normalizedProductId] ?? 0) + (quantity is int ? quantity : 1);
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Error processing order $orderKey: $e');
          }
        });
      }

      print('📊 Product sales data loaded: ${productSales.length} products');

      if (productSales.isNotEmpty) {
        print('🔥 Top 5 products by sales:');
        productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(5).forEach((entry) {
            print('   ${entry.key}: ${entry.value} sales');
          });
      }

      return productSales;
    } catch (e) {
      print('❌ Error loading product sales: $e');
      return {};
    }
  }

  // دالة لترتيب المنتجات حسب المبيعات
  List<Map<String, dynamic>> _getBestSellersProducts(List<Map<String, dynamic>> allProducts, Map<String, int> salesData) {
    List<Map<String, dynamic>> productsWithSales = allProducts.map((product) {
      final productId = product['id']?.toString().trim() ?? '';
      final salesCount = salesData[productId] ?? 0;
      return {
        ...product,
        'salesCount': salesCount,
      };
    }).toList();

    productsWithSales.sort((a, b) => (b['salesCount'] ?? 0).compareTo(a['salesCount'] ?? 0));

    print('🏆 Best Sellers Ranking:');
    productsWithSales.take(5).forEach((product) {
      print('   ${product['name']}: ${product['salesCount']} sales');
    });

    return productsWithSales.take(5).toList();
  }

  // دالة لتحميل بيانات Best Sellers
  Future<List<Map<String, dynamic>>> _loadBestSellers() async {
    try {
      final salesData = await _getProductSalesData();
      return _getBestSellersProducts(products, salesData);
    } catch (e) {
      print('❌ Error loading best sellers: $e');
      return products.take(5).toList();
    }
  }

  // دالة لإنشاء قسم العروض والخصومات
  Widget _buildDiscountsSection() {
    if (activeCoupons.isEmpty) {
      return SizedBox();
    }

    return Container(
      width: double.infinity,
      height: 200,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: AssetImage('assets/images/Discount_background.jpg'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.withOpacity(0.8),
              Color(0xFF914D74).withOpacity(0.7),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Special Offers 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemCount: activeCoupons.length,
                  itemBuilder: (context, index) {
                    return _buildCouponItem(activeCoupons[index]);
                  },
                ),
              ),

              Text(
                'Use these codes at checkout!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة لإنشاء عنصر الكوبون
  Widget _buildCouponItem(Map<String, dynamic> coupon) {
    final String code = coupon['code'] ?? 'N/A';
    final String discountType = coupon['discountType'] ?? 'percentage';
    final double discountValue = (coupon['discountValue'] ?? 0).toDouble();
    final DateTime startDate = coupon['startDate'];
    final DateTime endDate = coupon['endDate'];

    final startDateStr = '${startDate.day}/${startDate.month}/${startDate.year}';
    final endDateStr = '${endDate.day}/${endDate.month}/${endDate.year}';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFF914D74),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.discount,
              color: Colors.white,
              size: 18,
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Code: ',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      code,
                      style: TextStyle(
                        color: Color(0xFF914D74),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Text(
                      discountType == 'percentage'
                          ? '${discountValue.toInt()}% OFF'
                          : 'OMR ${discountValue.toStringAsFixed(2)} OFF',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4),

                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'Valid until: $endDateStr',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: 8),

          GestureDetector(
            onTap: () {
              _copyCouponCode(code);
            },
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF914D74),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.content_copy,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة نسخ كود الخصم
  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon code "$code" copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  // قسم المنتجات المخفضة
  Widget _buildDiscountedProductsSection() {
    if (_discountedProducts.isEmpty) {
      return SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Hot Deals ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Icon(Icons.discount, color: Colors.red, size: 24),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Limited Time',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Container(
          height: null,
          constraints: BoxConstraints(
            maxHeight: 260,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _discountedProducts.length,
            itemBuilder: (context, index) {
              return _buildDiscountedProductCard(_discountedProducts[index]);
            },
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // دالة مساعدة لجلب المنتجات المخفضة
  List<Map<String, dynamic>> _getDiscountedProducts() {
    // ✅ الآن نبحث عن المنتجات التي لديها خصم حقيقي
    List<Map<String, dynamic>> discountedProducts = products.where((product) {
      return product['discount'] != null;
    }).toList();

    // ✅ إذا لم نجد منتجات مخفضة، نستخدم المنتجات الأقل مبيعاً كبديل
    if (discountedProducts.isEmpty && _bestSellers.isNotEmpty) {
      discountedProducts = _bestSellers.where((product) {
        return (product['salesCount'] ?? 0) <= 5;
      }).toList();

      // إذا لم نجد أي منتجات، نأخذ آخر 3 منتجات
      if (discountedProducts.isEmpty && _bestSellers.length >= 3) {
        discountedProducts = _bestSellers.sublist(_bestSellers.length - 3);
      }
    }

    print("🎯 Found ${discountedProducts.length} discounted products");

    // طباعة المنتجات المخفضة للتحقق
    for (var product in discountedProducts) {
      bool hasDiscount = product['discount'] != null;
      print("   ${product['name']} - Has discount: $hasDiscount");
    }

    return discountedProducts;
  }

  // كارت للمنتجات المخفضة
  Widget _buildDiscountedProductCard(Map<String, dynamic> product) {
    double price = (product['price'] != null) ? double.parse(product['price'].toString()) : 0.0;
    int salesCount = product['salesCount'] ?? 0;

    // ✅ التحقق من وجود خصم
    bool hasDiscount = product['discount'] != null;
    Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(product['discount'])
        : null;

    double? discountValue = discountData?['discountValue']?.toDouble();
    String? discountType = discountData?['discountType'];

    // حساب السعر بعد الخصم
    double finalPrice = price;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = price * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = price - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Consumer<Cart>(
      builder: (context, cart, child) {
        return Container(
          width: 180,
          margin: EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شارة الخصم
                      Container(
                        height: 30,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.discount, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                hasDiscount && discountValue != null
                                    ? discountType == 'percentage'
                                    ? '${discountValue.toInt()}% OFF'
                                    : 'HOT DEAL'
                                    : 'HOT DEAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // صورة المنتج
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          child: _buildProductImage(product['image'], product['name']),
                        ),
                      ),

                      // معلومات المنتج
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['brand'] ?? 'Unknown Brand',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),

                            // ✅ عرض السعر مع الخصم
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    'OMR ${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  'OMR ${finalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (hasDiscount && discountValue != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      'You save OMR ${(price - finalPrice).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // عرض عدد المبيعات
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.trending_down, size: 10, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    '$salesCount sold',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // زر إضافة إلى السلة
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        _addToCart(context, product, cart);
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // دالة لإنشاء قسم Best Sellers
  Widget _buildBestSellersSection() {
    if (_bestSellers.isEmpty) {
      List<Map<String, dynamic>> fallbackBestSellers = products.take(5).toList();
      if (fallbackBestSellers.isEmpty) return SizedBox();
      return _buildBestSellersContent(fallbackBestSellers, isFallback: true);
    }

    return _buildBestSellersContent(_bestSellers, isFallback: false);
  }

  // دالة منفصلة لعرض محتوى Best Sellers
  Widget _buildBestSellersContent(List<Map<String, dynamic>> bestSellers, {bool isFallback = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Best Sellers ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF914D74),
                    ),
                  ),
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 24,
                  ),
                  if (isFallback)
                    Tooltip(
                      message: 'Based on available products (real sales data loading...)',
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 8),

        Container(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: bestSellers.length,
            itemBuilder: (context, index) {
              return _buildBestSellerCard(bestSellers[index], index + 1, isFallback);
            },
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // كارت مخصص لـ Best Sellers
  Widget _buildBestSellerCard(Map<String, dynamic> product, int rank, bool isFallback) {
    double price = (product['price'] != null) ? double.parse(product['price'].toString()) : 0.0;
    int salesCount = product['salesCount'] ?? 0;

    // ✅ التحقق من وجود خصم
    bool hasDiscount = product['discount'] != null;
    Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(product['discount'])
        : null;

    double? discountValue = discountData?['discountValue']?.toDouble();
    String? discountType = discountData?['discountType'];

    // حساب السعر بعد الخصم
    double finalPrice = price;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = price * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = price - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Consumer<Cart>(
      builder: (context, cart, child) {
        return Container(
          width: 180,
          margin: EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شارة الترتيب مع شارة الخصم
                      Stack(
                        children: [
                          Container(
                            height: 30,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _getRankColor(rank),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Center(
                              child: Text(
                                '#$rank Best Seller',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // ✅ شارة الخصم للـ Best Seller
                          if (hasDiscount)
                            Positioned(
                              top: 4,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'OFF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // صورة المنتج
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          child: _buildProductImage(product['image'], product['name']),
                        ),
                      ),

                      // معلومات المنتج
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Unknown Product',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['brand'] ?? 'Unknown Brand',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),

                            // ✅ عرض السعر مع الخصم
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasDiscount)
                                  Text(
                                    'OMR ${price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  'OMR ${finalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: hasDiscount ? Colors.red : Color(0xFF914D74),
                                    fontWeight: FontWeight.bold,
                                    fontSize: hasDiscount ? 12 : 14,
                                  ),
                                ),
                                if (hasDiscount && discountValue != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      discountType == 'percentage'
                                          ? '${discountValue.toInt()}% OFF'
                                          : 'Save OMR ${discountValue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            if (!isFallback && salesCount > 0)
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.shopping_cart_checkout, size: 10, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      '$salesCount sold',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // زر إضافة إلى السلة
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        _addToCart(context, product, cart);
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFF914D74),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // دالة للحصول على لون الشارة حسب الترتيب
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber[700]!;
      case 2: return Colors.grey[600]!;
      case 3: return Colors.brown[700]!;
      default: return Color(0xFF914D74);
    }
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: products.length,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return _buildProductCard(products[index]);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    double price = (product['price'] != null) ? double.parse(product['price'].toString()) : 0.0;

    // ✅ التحقق من وجود خصم على المنتج
    bool hasDiscount = product['discount'] != null;
    Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(product['discount'])
        : null;

    double? discountValue = discountData?['discountValue']?.toDouble();
    String? discountType = discountData?['discountType'];

    // حساب السعر بعد الخصم
    double finalPrice = price;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = price * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = price - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Consumer2<Cart, Favorites>(
      builder: (context, cart, favorites, child) {
        bool isFavorite = favorites.containsKey(product['id'] ?? '');

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ صورة المنتج مع شارة الخصم
                    Stack(
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            color: Colors.grey[200],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            child: _buildProductImage(product['image'], product['name']),
                          ),
                        ),

                        // ✅ شارة الخصم
                        if (hasDiscount)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                discountType == 'percentage'
                                    ? '${discountValue!.toInt()}% OFF'
                                    : 'SALE',
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

                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Unknown Product',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            product['brand'] ?? 'Unknown Brand',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),

                          // ✅ عرض السعر مع الخصم
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasDiscount)
                                Text(
                                  'OMR ${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                'OMR ${finalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: hasDiscount ? Colors.red : Color(0xFF914D74),
                                  fontWeight: FontWeight.bold,
                                  fontSize: hasDiscount ? 14 : 16,
                                ),
                              ),
                              if (hasDiscount && discountValue != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    discountType == 'percentage'
                                        ? 'Save ${discountValue.toInt()}%'
                                        : 'Save OMR ${discountValue.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),

                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAdmin)
                        GestureDetector(
                          onTap: () {
                            _showDeleteDialog(product);
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      if (_isAdmin)
                        GestureDetector(
                          onTap: () {
                            _editProduct(product);
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _addToCart(context, product, cart);
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFF914D74),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_shopping_cart,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editProduct(Map<String, dynamic> product) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProductScreen(product: product),
        ),
      );
      await _refreshProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing product: $e')),
      );
    }
  }

  void _showDeleteDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteProduct(product);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(Map<String, dynamic> product) async {
    try {
      final productId = product['id'];
      if (productId != null) {
        final dbRef = FirebaseDatabase.instance.ref().child("products/$productId");
        await dbRef.remove();

        setState(() {
          products.removeWhere((p) => p['id'] == productId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCart(BuildContext context, Map<String, dynamic> product, Cart cart) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must log in first.')),
      );
      return;
    }

    final String productId = product['id'] ?? 'unknown_product';
    final String productName = product['name'] ?? 'Unknown Product';
    final double originalPrice = (product['price'] != null) ? double.parse(product['price'].toString()) : 0.0;
    final String productImage = product['image'] ?? '';

    // ✅ جلب بيانات الخصم
    Map<String, dynamic>? discountData;
    if (product['discount'] != null) {
      discountData = Map<String, dynamic>.from(product['discount']);
    }

    // ✅ إضافة المنتج مع بيانات الخصم
    cart.addItem(
      productId,
      productName,
      originalPrice, // السعر الأصلي
      productImage,
      originalPrice: originalPrice,
      discount: discountData,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $productName to the cart ${discountData != null ? 'with discount!' : ''}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl, String productName) {
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderImage(loading: true),
        errorWidget: (context, url, error) {
          print("Error loading main image: $error, URL: $url");
          return _buildPlaceholderImage();
        },
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage({bool loading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: loading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "Image not available",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      selectedItemColor: Color(0xFF914D74),
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedIndex,
      onTap: (index) async {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Home()),
          );
        } else if (index == 1) {
          final result = await Navigator.push(
            context,
            //----------------------------------------------------
            MaterialPageRoute(builder: (context) => SkinAnalysisPy()),
          );

          if (result != null) {
            _showSkinResultDialog(result);

            // ✅ حفظ في الـ Provider
            final skinProvider = Provider.of<SkinTypeProvider>(context, listen: false);
            await skinProvider.setSkinType(
              result['skinType'],
              problems: List<String>.from(result['problems'] ?? []),
              confidence: (result['confidence'] ?? 0.0).toDouble(),
            );

            print('🎯 Skin analysis completed and saved: ${result['skinType']}');
          }
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FavoritesScreen()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage()),
          );
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Analyze',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'Favorite',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  void _showSkinResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('🎉 Analysis Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your Skin Type:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text(
              result['skinType'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF914D74),
              ),
            ),
            SizedBox(height: 10),
            if (result['problems'] != null && (result['problems'] as List).isNotEmpty)
              Text(
                'Issues: ${(result['problems'] as List).join(', ')}',
                style: TextStyle(color: Colors.orange),
              ),
            SizedBox(height: 10),
            Text(
              'Confidence: ${((result['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: Color(0xFF914D74))),
          ),
        ],
      ),
    );
  }

  // دالة لإرسال إشعار عند إضافة كوبون جديد
  Future<void> _sendCouponNotification(Map<String, dynamic> coupon) async {
    try {
      final String couponCode = coupon['code'] ?? 'NEW_COUPON';
      final double discountValue = (coupon['discountValue'] ?? 0).toDouble();
      final String discountType = coupon['discountType'] ?? 'percentage';

      _showLocalCouponNotification(couponCode, discountValue, discountType);

      print('📢 Coupon notification sent for: $couponCode');
    } catch (e) {
      print('❌ Error sending coupon notification: $e');
    }
  }

  // عرض إشعار محلي للكوبون
  void _showLocalCouponNotification(String code, double value, String type) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'coupon_channel',
      'Coupon Notifications',
      channelDescription: 'Notifications for new coupons and discounts',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF914D74),
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
    DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    FlutterLocalNotificationsPlugin().show(
      0,
      '🎉 New Discount Available!',
      type == 'percentage'
          ? 'Use code $code for $value% OFF'
          : 'Use code $code for OMR $value OFF',
      platformChannelSpecifics,
    );
  }
}