// product_detail.dart
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/cart_model.dart';
import 'package:skinglow/Screens/favorites_model.dart';
import 'package:firebase_database/firebase_database.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? userSkinType;
  const ProductDetailScreen({
    Key? key,
    required this.product,
    this.userSkinType, // أضف هذا
  }) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _selectedImageIndex = 0;
  List<String> _allImages = [];
  final PageController _pageController = PageController();
// دالة للتحقق من ملاءمة المنتج
  Map<String, dynamic> _checkProductSuitability() {
    if (widget.userSkinType == null || widget.userSkinType!.isEmpty) {
      return {
        'isSuitable': false,
        'message': 'Check your skin first to see product compatibility',
        'color': Colors.orange,
        'icon': Icons.help_outline,
      };
    }

    final skinTypes = (widget.product['skinTypes'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase())
        .toList();

    final userSkinType = widget.userSkinType!.toLowerCase();

    // تحقق إذا كان المنتج مناسب لجميع أنواع البشرة
    if (skinTypes.contains('all') || skinTypes.contains('all-skin-type')) {
      return {
        'isSuitable': true,
        'message': 'Perfect for all skin types',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    }

    // تحقق إذا كان المنتج مناسب لنوع البشرة المحدد
    if (skinTypes.contains(userSkinType)) {
      return {
        'isSuitable': true,
        'message': 'Perfect for your ${userSkinType} skin',
        'color': Colors.green,
        'icon': Icons.check_circle,
      };
    }

    // تحقق من التوافق
    final Map<String, List<String>> compatibilityMap = {
      'oily': ['combination', 'normal'],
      'dry': ['normal', 'sensitive'],
      'combination': ['oily', 'normal'],
      'sensitive': ['dry', 'normal'],
      'normal': ['all', 'all-skin-type'],
    };

    if (skinTypes.any((type) =>
    compatibilityMap[userSkinType]?.contains(type) ?? false)) {
      return {
        'isSuitable': true,
        'message': 'Compatible with your ${userSkinType} skin',
        'color': Colors.blue,
        'icon': Icons.info,
      };
    }

    return {
      'isSuitable': false,
      'message': 'May not be ideal for ${userSkinType} skin',
      'color': Colors.orange,
      'icon': Icons.warning,
    };
  }
  @override
  void initState() {
    super.initState();

    // تجميع جميع الصور بطريقة آمنة
    final mainImage = widget.product['image']?.toString() ?? '';
    final additionalImages = widget.product['images'] as List<dynamic>? ?? [];

    // تحويل جميع العناصر إلى String
    final imageList = <String>[];

    // إضافة الصورة الرئيسية
    if (mainImage.isNotEmpty) {
      imageList.add(mainImage);
    }

    // إضافة الصور الإضافية
    for (final img in additionalImages) {
      if (img != null) {
        final imgStr = img.toString();
        if (imgStr.isNotEmpty) {
          imageList.add(imgStr);
        }
      }
    }

    _allImages = imageList;

    //_pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeImage(int direction) {
    setState(() {
      _selectedImageIndex += direction;
      if (_selectedImageIndex < 0) {
        _selectedImageIndex = _allImages.length - 1;
      } else if (_selectedImageIndex >= _allImages.length) {
        _selectedImageIndex = 0;
      }
      _pageController.animateToPage(
        _selectedImageIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedImageIndex = index;
    });
  }

  void _showFullScreenImage(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // معرض الصور بالحجم الكامل
              PageView.builder(
                itemCount: images.length,
                controller: PageController(initialPage: initialIndex),
                onPageChanged: (index) {
                  setState(() {
                    _selectedImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  );
                },
              ),

              // زر الإغلاق
              Positioned(
                top: 40,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // عداد الصور
              if (images.length > 1)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedImageIndex + 1}/${images.length}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String productId = widget.product['id'] ?? 'unknown';
    final String productName = widget.product['name'] ?? 'Unknown Product';
    final String productBrand = widget.product['brand'] ?? 'Unknown Brand';
    final double productPrice = (widget.product['price'] != null && widget.product['price'].toString().isNotEmpty)
        ? double.tryParse(widget.product['price'].toString())?? 0.0
        : 0.0;
    final String productImage = widget.product['image'] ?? '';
    final String productDescription = widget.product['description'] ?? 'No description available.';
    final String detailedDescription = widget.product['detailedDescription'] ?? '';
    final List<dynamic> keyBenefits = widget.product['keyBenefits'] ?? [];
    final List<dynamic> ingredients = widget.product['ingredients'] ?? [];
    final String ingredientsDescription = widget.product['ingredientsDescription'] ?? '';
    final List<dynamic> howToUse = widget.product['howToUse'] ?? [];
    final String volume = widget.product['volume'] ?? '';
    final String texture = widget.product['texture'] ?? '';
    final String scent = widget.product['scent'] ?? '';
    final List<dynamic> skinTypes = widget.product['skinTypes'] ?? [];
    final List<dynamic> skinProblems = widget.product['skinProblems'] ?? [];
    final bool crueltyFree = widget.product['crueltyFree'] ?? false;
    final bool vegan = widget.product['vegan'] ?? false;
    final bool allergenFree = widget.product['allergenFree'] ?? false;
    final bool dermatologistTested = widget.product['dermatologistTested'] ?? false;
    final String countryOfOrigin = widget.product['countryOfOrigin'] ?? '';
    final String availability = widget.product['availability'] ?? '';
    final double rating = (widget.product['rating'] != null)
        ? double.parse(widget.product['rating'].toString())
        : 0.0;
    final int reviewCount = (widget.product['reviewCount'] != null)
        ? int.parse(widget.product['reviewCount'].toString())
        : 0;

    // ✅ التحقق من وجود خصم
    final bool hasDiscount = widget.product['discount'] != null;
    final Map<String, dynamic>? discountData = hasDiscount
        ? Map<String, dynamic>.from(widget.product['discount'])
        : null;
    final double? discountValue = discountData?['discountValue']?.toDouble();
    final String? discountType = discountData?['discountType'];
    final double originalPrice = widget.product['originalPrice'] != null
        ? double.parse(widget.product['originalPrice'].toString())
        : productPrice;

    // ✅ حساب السعر بعد الخصم
    double finalPrice = productPrice;
    if (hasDiscount && discountValue != null) {
      if (discountType == 'percentage') {
        finalPrice = originalPrice * (1 - discountValue / 100);
      } else if (discountType == 'fixed') {
        finalPrice = originalPrice - discountValue;
        if (finalPrice < 0) finalPrice = 0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            _buildImageGallery(_allImages),
// ✅ قسم توافق المنتج مع بشرة المستخدم
            if (widget.userSkinType != null && widget.userSkinType!.isNotEmpty)
              _buildSkinCompatibilitySection(),
            // Product Info Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productBrand,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    productName,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),

                  // ✅ قسم الخصم والسعر
                  _buildPriceSection(
                    hasDiscount: hasDiscount,
                    originalPrice: originalPrice,
                    finalPrice: finalPrice,
                    discountValue: discountValue,
                    discountType: discountType,
                  ),

                  SizedBox(height: 16),

                  // Availability
                  _buildAvailabilitySection(availability),
                  SizedBox(height: 16),

                  // Description
                  _buildDescriptionSection(productDescription, detailedDescription),
                  SizedBox(height: 16),

                  // Key Benefits
                  if (keyBenefits.isNotEmpty) _buildKeyBenefitsSection(keyBenefits),

                  // How to Use
                  if (howToUse.isNotEmpty) _buildHowToUseSection(howToUse),

                  // Ingredients
                  if (ingredients.isNotEmpty) _buildIngredientsSection(ingredients, ingredientsDescription),

                  // Product Details
                  _buildProductDetailsSection(
                      volume, texture, scent, skinTypes, skinProblems,
                      crueltyFree, vegan, allergenFree, dermatologistTested,
                      countryOfOrigin
                  ),

                  // Ratings & Reviews Section
                  _buildRatingsReviewsSection(context, productId),

                  SizedBox(height: 80), // Extra space at the bottom
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Consumer2<Cart, Favorites>(
        builder: (context, cart, favorites, child) {
          bool isFavorite = favorites.containsKey(productId);

          return Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Favorite Button
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                      if (isFavorite) {
                        favorites.removeItem(productId);
                      } else {
                        favorites.addItem(productId, productName, productPrice, productImage);
                      }
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Add to Cart Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF914D74),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      // ✅ إضافة المنتج مع بيانات الخصم
                      cart.addItem(
                        productId,
                        productName,
                        originalPrice,
                        productImage,
                        originalPrice: originalPrice,
                        discount: discountData,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Added to cart${hasDiscount ? ' with discount! 🎉' : ''}'
                          ),
                        ),
                      );
                    },
                    child: Text(
                        'Add to Cart',
                        style: TextStyle(fontSize: 16, color: Colors.white)
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
// ✅ قسم توافق المنتج مع بشرة المستخدم
  Widget _buildSkinCompatibilitySection() {
    final suitabilityInfo = _checkProductSuitability();

    return Container(
      padding: EdgeInsets.all(16),
      color: suitabilityInfo['color'].withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            suitabilityInfo['icon'],
            color: suitabilityInfo['color'],
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skin Compatibility',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: suitabilityInfo['color'],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  suitabilityInfo['message'],
                  style: TextStyle(
                    fontSize: 14,
                    color: suitabilityInfo['color'],
                  ),
                ),
                SizedBox(height: 4),
                if (widget.userSkinType != null)
                  Text(
                    'Your skin type: ${widget.userSkinType!.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ✅ دالة جديدة لعرض قسم السعر والخصم
  Widget _buildPriceSection({
    required bool hasDiscount,
    required double originalPrice,
    required double finalPrice,
    required double? discountValue,
    required String? discountType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDiscount) ...[
          // شارة الخصم
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.discount, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  discountType == 'percentage'
                      ? '${discountValue!.toInt()}% OFF'
                      : 'OMR ${discountValue!.toStringAsFixed(2)} OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),

          // السعر الأصلي مشطوب
          Row(
            children: [
              Text(
                'OMR ${originalPrice.toStringAsFixed(3)}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              SizedBox(width: 8),
              // نسبة التوفير
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  'Save OMR ${(originalPrice - finalPrice).toStringAsFixed(3)}',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
        ],

        // السعر النهائي
        Text(
          'OMR ${finalPrice.toStringAsFixed(3)}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: hasDiscount ? Colors.red : Color(0xFF914D74),
          ),
        ),

        if (hasDiscount)
          Text(
            'Special price with discount!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  // Image Gallery Widget
  Widget _buildImageGallery(List<String> allImages) {
    return Column(
      children: [
        // الصورة الرئيسية مع PageView
        GestureDetector(
          onTap: () {
            if (allImages.isNotEmpty) {
              _showFullScreenImage(context, allImages, _selectedImageIndex);
            }
          },
          child: Container(
            height: 300,
            width: double.infinity,
            child: Stack(
              children: [
                // PageView للتنقل بين الصور
                if (allImages.isNotEmpty)
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: allImages.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: allImages[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),

                // ✅ شارة الخصم على الصورة
                if (widget.product['discount'] != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'SALE',
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

                // أزرار التنقل بين الصور
                if (allImages.length > 1) ...[
                  Positioned(
                    left: 10,
                    top: 130,
                    child: FloatingActionButton.small(
                      heroTag: 'prev_btn',
                      onPressed: _selectedImageIndex > 0
                          ? () => _changeImage(-1)
                          : null,
                      child: Icon(Icons.chevron_left),
                      backgroundColor: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 130,
                    child: FloatingActionButton.small(
                      heroTag: 'next_btn',
                      onPressed: _selectedImageIndex < allImages.length - 1
                          ? () => _changeImage(1)
                          : null,
                      child: Icon(Icons.chevron_right),
                      backgroundColor: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],

                // عداد الصور
                if (allImages.length > 1)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedImageIndex + 1}/${allImages.length}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // معرض الصور المصغرة
        if (allImages.length > 1)
          Container(
            height: 80,
            margin: EdgeInsets.only(top: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                    _pageController.animateToPage(
                      index,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedImageIndex == index
                            ? Color(0xFF914D74)
                            : Colors.grey[300]!,
                        width: _selectedImageIndex == index ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: allImages[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // باقي الدوال بدون تغيير...
  // Availability Section Widget
  Widget _buildAvailabilitySection(String availability) {
    Color statusColor = availability == 'In Stock' ? Colors.green : Colors.red;

    return Row(
      children: [
        Icon(
          Icons.inventory_2,
          color: statusColor,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          availability,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Description Section Widget
  Widget _buildDescriptionSection(String description, String detailedDescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 12),
        if (detailedDescription.isNotEmpty)
          Text(
            detailedDescription,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
      ],
    );
  }

  // Key Benefits Section Widget
  Widget _buildKeyBenefitsSection(List<dynamic> benefits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Key Benefits',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: benefits.map((benefit) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit.toString(),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // How to Use Section Widget
  Widget _buildHowToUseSection(List<dynamic> usage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'How to Use',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: usage.map((step) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.toString(),
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Ingredients Section Widget
  Widget _buildIngredientsSection(List<dynamic> ingredients, String ingredientsDescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Ingredients',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        if (ingredientsDescription.isNotEmpty)
          Text(
            ingredientsDescription,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ingredients.map((ingredient) {
            return Chip(
              label: Text(
                ingredient.toString(),
                style: TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.grey[100],
            );
          }).toList(),
        ),
      ],
    );
  }

  // Product Details Section Widget
  Widget _buildProductDetailsSection(
      String volume, String texture, String scent,
      List<dynamic> skinTypes, List<dynamic> skinProblems,
      bool crueltyFree, bool vegan, bool allergenFree,
      bool dermatologistTested, String countryOfOrigin
      ) {
    bool hasUserSkinType = widget.userSkinType != null && widget.userSkinType!.isNotEmpty;
    String userSkinTypeFormatted = hasUserSkinType ? widget.userSkinType!.toLowerCase() : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          'Product Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),

        // ✅ عرض أنواع البشرة مع تمييز نوع بشرة المستخدم
        if (skinTypes.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Suitable for: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: skinTypes.map((type) {
                        final typeStr = type.toString();
                        final isUserType = hasUserSkinType &&
                            typeStr.toLowerCase() == userSkinTypeFormatted;

                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUserType ? Color(0xFF914D74) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUserType ? Color(0xFF914D74) : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            typeStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: isUserType ? Colors.white : Colors.black,
                              fontWeight: isUserType ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
          ),
        SizedBox(height: 8),
        _buildDetailRow('Volume', volume),
        _buildDetailRow('Texture', texture),
        _buildDetailRow('Scent', scent),
        _buildDetailRow('Suitable Skin Types', skinTypes.join(', ')),
        _buildDetailRow('Targeted Skin Concerns', skinProblems.join(', ')),
        _buildDetailRow('Country of Origin', countryOfOrigin),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (crueltyFree) _buildCertificationChip('Cruelty Free', Icons.pets),
            if (vegan) _buildCertificationChip('Vegan', Icons.eco),
            if (allergenFree) _buildCertificationChip('Allergen Free', Icons.health_and_safety),
            if (dermatologistTested) _buildCertificationChip('Dermatologist Tested', Icons.medical_services),
          ],
        ),
      ],
    );
  }

  // Helper for detail rows
  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for certification chips
  Widget _buildCertificationChip(String label, IconData icon) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      backgroundColor: Colors.green[50],
    );
  }

  // Ratings & Reviews Section Widget
  Widget _buildRatingsReviewsSection(BuildContext context, String productId) {
    return FutureBuilder(
      future: _getProductRatings(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error loading reviews');
        }

        final ratings = snapshot.data as Map<String, dynamic>? ?? {};

        if (ratings.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text(
                'Reviews',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No reviews yet. Be the first to review this product!',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }

        // حساب متوسط التقييم
        double averageRating = 0;
        if (ratings.isNotEmpty) {
          double total = 0;
          ratings.forEach((key, value) {
            total += (value['rating'] ?? 0).toDouble();
          });
          averageRating = total / ratings.length;
        }

        // عرض أول 3 تقييمات فقط
        final limitedRatings = ratings.entries.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // متوسط التقييم
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF914D74),
                        ),
                      ),
                      SizedBox(height: 4),
                      _buildRatingStars(averageRating.round()),
                      SizedBox(height: 4),
                      Text(
                        '${ratings.length} reviews',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What customers say:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        if (ratings.isNotEmpty)
                          Text(
                            _getRandomReviewComment(ratings),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // قائمة التقييمات
            Column(
              children: limitedRatings.map((entry) {
                final ratingData = entry.value;
                return _buildReviewItem(ratingData);
              }).toList(),
            ),

            // زر عرض المزيد
            if (ratings.length > 3)
              Center(
                child: TextButton(
                  onPressed: () {
                    _showAllReviews(context, productId);
                  },
                  child: Text(
                    'View All ${ratings.length} Reviews',
                    style: TextStyle(
                      color: Color(0xFF914D74),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // بناء عنصر التقييم
  Widget _buildReviewItem(Map<dynamic, dynamic> ratingData) {
    final dynamic ratingValue = ratingData['rating'];
    final int rating = (ratingValue is int) ? ratingValue :
    (ratingValue is double) ? ratingValue.round() :
    (ratingValue is String) ? int.tryParse(ratingValue) ?? 0 : 0;

    final String comment = ratingData['comment']?.toString() ?? '';
    final String userName = ratingData['userName']?.toString() ?? 'User';
    final dynamic timestamp = ratingData['ratedAt'];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              _buildRatingStars(rating),
            ],
          ),
          SizedBox(height: 8),
          if (comment.isNotEmpty)
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          SizedBox(height: 8),
          Text(
            _formatTimestamp(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // بناء نجوم التقييم
  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  // الحصول على تقييمات المنتج من Firebase
  Future<Map<String, dynamic>> _getProductRatings(String productId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('products/$productId/ratings');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final ratingsMap = Map<dynamic, dynamic>.from(snapshot.value as Map);

        // تحويل إلى Map<String, dynamic> وترتيب من الأحدث للأقدم
        Map<String, dynamic> ratings = {};
        ratingsMap.forEach((key, value) {
          ratings[key.toString()] = Map<dynamic, dynamic>.from(value);
        });

        // ترتيب التقييمات من الأحدث للأقدم
        final sortedEntries = ratings.entries.toList()
          ..sort((a, b) {
            final timeA = a.value['ratedAt'] ?? 0;
            final timeB = b.value['ratedAt'] ?? 0;
            return (timeB as num).compareTo(timeA as num);
          });

        return Map.fromEntries(sortedEntries);
      }
      return {};
    } catch (e) {
      print('Error getting product ratings: $e');
      return {};
    }
  }

  // عرض جميع التقييمات
  void _showAllReviews(BuildContext context, String productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Reviews',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: FutureBuilder(
                  future: _getProductRatings(productId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(child: Text('Error loading reviews'));
                    }

                    final ratings = snapshot.data as Map<String, dynamic>;

                    if (ratings.isEmpty) {
                      return Center(
                        child: Text(
                          'No reviews yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView(
                      children: ratings.entries.map((entry) {
                        final ratingData = entry.value;
                        return _buildReviewItem(ratingData);
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // الحصول على تعليق عشوائي من التقييمات
  String _getRandomReviewComment(Map<String, dynamic> ratings) {
    if (ratings.isEmpty) return '';

    final comments = ratings.values
        .where((rating) => rating['comment'] != null && rating['comment'].toString().isNotEmpty)
        .map((rating) => rating['comment'].toString())
        .toList();

    if (comments.isEmpty) return 'Customers love this product!';

    // عرض تعليق عشوائي
    final random = Random();
    return comments[random.nextInt(comments.length)];
  }

  // تنسيق التاريخ
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is String) {
        return timestamp;
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}