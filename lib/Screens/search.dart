import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinglow/Screens/Home.dart';
import 'package:skinglow/Screens/cart_model.dart';
import 'package:skinglow/Screens/favorites_model.dart';
import 'package:skinglow/Screens/product_detail_screen.dart';
import '../SkinAnalysis/skin_type_provider.dart';

class SearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String searchQuery;
  final bool isFromBarcode;
  final String? userSkinType;

  const SearchPage({
    Key? key,
    required this.products,
    required this.searchQuery,
    this.isFromBarcode = false,
    this.userSkinType,
  }) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _alternativeProducts = [];
  String _selectedCategory = 'all';
  bool _isLoading = false;
  String? _currentUserSkinType;
  bool _showingAlternatives = false;

  final List<Map<String, dynamic>> _skinCategories = [
    {'id': 'all', 'name': 'All Products', 'icon': Icons.all_inclusive},
    {'id': 'oily', 'name': 'Oily Skin', 'icon': Icons.water_drop},
    {'id': 'dry', 'name': 'Dry Skin', 'icon': Icons.ac_unit},
    {'id': 'combination', 'name': 'Combination', 'icon': Icons.merge},
    {'id': 'sensitive', 'name': 'Sensitive', 'icon': Icons.health_and_safety},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _getUserSkinType();

    if (widget.isFromBarcode && widget.products.isNotEmpty) {
      setState(() {
        _searchResults = widget.products;
      });

      // التحقق من ملاءمة المنتج الممسوح
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScannedProductSuitability();
      });
    } else if (widget.isFromBarcode && widget.products.isEmpty && widget.searchQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchProducts(widget.searchQuery);
      });
    } else if (widget.searchQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchProducts(widget.searchQuery);
      });
    }
  }

  void _getUserSkinType() {
    final skinTypeProvider = context.read<SkinTypeProvider>();

    if (widget.userSkinType != null && widget.userSkinType!.isNotEmpty) {
      setState(() {
        _currentUserSkinType = widget.userSkinType!.toLowerCase();
      });
    } else if (skinTypeProvider.skinType != null && skinTypeProvider.skinType!.isNotEmpty) {
      setState(() {
        _currentUserSkinType = skinTypeProvider.skinType!.toLowerCase();
      });
    }
  }

  void _checkScannedProductSuitability() {
    if (_searchResults.isEmpty || _currentUserSkinType == null) return;

    Map<String, dynamic> product = _searchResults[0];
    Map<String, dynamic> suitability = _checkProductSuitability(product);

    if (suitability['shouldShowAlternatives'] == true) {
      // عرض رسالة تلقائياً للمنتج غير المناسب
      _showUnsuitableProductAlert(product, suitability);
    }
  }

  void _showUnsuitableProductAlert(Map<String, dynamic> product, Map<String, dynamic> suitability) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(suitability['icon'], color: suitability['color']),
              SizedBox(width: 10),
              Text('Product Not Suitable'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['name'] ?? 'Product',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                suitability['recommendation'],
                style: TextStyle(
                  color: suitability['color'],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'This product is designed for: ${product['skinTypes']?.join(", ") ?? "Unknown"} skin types.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Continue Anyway'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _findAlternativeProducts(product);
              },
              child: Text('Show Alternatives'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      );
    });
  }

  Map<String, dynamic> _checkProductSuitability(Map<String, dynamic> product) {
    final skinTypes = (product['skinTypes'] as List<dynamic>? ?? [])
        .map((e) => e.toString().toLowerCase())
        .toList();

    bool isSuitable = false;
    bool isPerfectMatch = false;
    bool isCompatible = false;
    String recommendation = "";
    Color color = Colors.grey;
    IconData icon = Icons.help_outline;
    bool shouldShowAlternatives = false;

    // التحقق 1: إذا لم يكن لدى المستخدم نوع بشرة محددة
    if (_currentUserSkinType == null || _currentUserSkinType!.isEmpty) {
      return {
        'isSuitable': false,
        'isPerfectMatch': false,
        'isCompatible': false,
        'recommendation': '⚠️ Set your skin type first',
        'color': Colors.orange,
        'icon': Icons.help_outline,
        'shouldShowAlternatives': false,
      };
    }

    // التحقق 2: إذا كان المنتج مناسب لجميع أنواع البشرة
    if (skinTypes.contains('all') || skinTypes.contains('all-skin-type')) {
      isSuitable = true;
      recommendation = '✅ Suitable for all skin types';
      color = Colors.green;
      icon = Icons.check_circle;
    }
    // التحقق 3: إذا كان المنتج مناسب لنوع بشرة المستخدم بالتحديد
    else if (skinTypes.contains(_currentUserSkinType)) {
      isSuitable = true;
      isPerfectMatch = true;
      recommendation = '✅ Perfect for ${_currentUserSkinType} skin';
      color = Colors.green;
      icon = Icons.check_circle;
    }
    // التحقق 4: إذا كان المنتج غير مناسب إطلاقاً
    else {
      isSuitable = false;
      shouldShowAlternatives = true;
      recommendation = '⚠️ May not be suitable for ${_currentUserSkinType} skin';
      color = Colors.orange;
      icon = Icons.warning;
    }

    return {
      'isSuitable': isSuitable,
      'isPerfectMatch': isPerfectMatch,
      'isCompatible': isCompatible,
      'recommendation': recommendation,
      'color': color,
      'icon': icon,
      'shouldShowAlternatives': shouldShowAlternatives,
    };
  }

  bool _isCompatibleSkinType(String userSkinType, List<String> productSkinTypes) {
    final Map<String, List<String>> compatibilityMap = {
      'oily': ['combination', 'normal', 'all', 'all-skin-type'],
      'dry': ['normal', 'sensitive', 'all', 'all-skin-type'],
      'combination': ['oily', 'normal', 'all', 'all-skin-type'],
      'sensitive': ['dry', 'normal', 'all', 'all-skin-type'],
      'normal': ['all', 'all-skin-type', 'dry', 'sensitive', 'combination'],
    };

    return productSkinTypes.any((productType) {
      return compatibilityMap[userSkinType]?.contains(productType) ?? false;
    });
  }

  Future<void> _findAlternativeProducts(Map<String, dynamic> unsuitableProduct) async {
    if (_currentUserSkinType == null) return;

    setState(() {
      _isLoading = true;
      _showingAlternatives = true;
    });

    try {
      // استيراد جميع المنتجات من Firebase
      final allProducts = await _getAllProductsFromFirebase();

      final String? category = unsuitableProduct['category']?.toString();
      final String? brand = unsuitableProduct['brand']?.toString();

      // البحث عن منتجات من نفس الفئة تناسب بشرة المستخدم
      List<Map<String, dynamic>> alternatives = allProducts.where((product) {
        if (product['id'] == unsuitableProduct['id']) return false;

        final suitability = _checkProductSuitability(product);
        final String? productCategory = product['category']?.toString();

        return (suitability['isSuitable'] == true || suitability['isCompatible'] == true) &&
            productCategory == category;
      }).toList();

      // إذا لم نجد منتجات من نفس الفئة، نبحث عن منتجات من نفس الماركة
      if (alternatives.isEmpty) {
        alternatives = allProducts.where((product) {
          if (product['id'] == unsuitableProduct['id']) return false;

          final suitability = _checkProductSuitability(product);
          final String? productBrand = product['brand']?.toString();

          return (suitability['isSuitable'] == true || suitability['isCompatible'] == true) &&
              productBrand == brand;
        }).toList();
      }

      // إذا لم نجد أي بدائل، نبحث عن أي منتج يناسب بشرة المستخدم
      if (alternatives.isEmpty) {
        alternatives = allProducts.where((product) {
          if (product['id'] == unsuitableProduct['id']) return false;

          final suitability = _checkProductSuitability(product);
          return (suitability['isSuitable'] == true || suitability['isCompatible'] == true);
        }).take(10).toList();
      }

      setState(() {
        _alternativeProducts = alternatives;
        _isLoading = false;
      });

    } catch (e) {
      print('Error finding alternatives: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getAllProductsFromFirebase() async {
    List<Map<String, dynamic>> allProducts = [];

    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('products');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> products = snapshot.value as Map;

        products.forEach((key, value) {
          try {
            Map<String, dynamic> product = Map<String, dynamic>.from(value);
            product['firebaseKey'] = key.toString();
            allProducts.add(product);
          } catch (e) {
            print("Error processing product: $e");
          }
        });
      }
    } catch (e) {
      print("Firebase error: $e");
    }

    return allProducts;
  }

  void _backToOriginalResults() {
    setState(() {
      _showingAlternatives = false;
      _alternativeProducts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);
    final favorites = Provider.of<Favorites>(context);

    return Scaffold(
      appBar: AppBar(
        title: widget.isFromBarcode
            ? Text('Barcode Scan Result')
            : TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.black54),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _selectedCategory = 'all';
                  _showingAlternatives = false;
                  _alternativeProducts.clear();
                });
              },
            ),
          ),
          style: TextStyle(color: Colors.black),
          onChanged: _searchProducts,
        ),
        actions: [
          // زر للعودة إلى Home دائماً (مهم في حالة عرض البدائل)
          if (_showingAlternatives)
            IconButton(
              icon: Icon(Icons.home), // أو استخدم Icons.arrow_back
              onPressed: () {
                Navigator.pushReplacement(  // ✅ استخدام pushReplacement
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              },
              tooltip: 'Go to Home',
            ),
          // يمكنك إضافة أزرار إضافية هنا...
        ],
      ),
      body: Column(
        children: [
          // باني الباركود مع نتيجة الملاءمة
          if (widget.isFromBarcode && widget.searchQuery.isNotEmpty)
            _buildBarcodeHeaderWithSuitability(),

          _buildSkinCategories(),
          SizedBox(height: 8),

          // عرض نوع بشرة المستخدم
          if (_currentUserSkinType != null)
            _buildUserSkinTypeInfo(),

          // عرض عنوان البدائل إذا كنا نعرضها
          if (_showingAlternatives && _alternativeProducts.isNotEmpty)
            _buildAlternativesHeader(),

          if (_isLoading) LinearProgressIndicator(),

          Expanded(
            child: _buildSearchResults(cart, favorites),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeHeaderWithSuitability() {
    final hasResults = _searchResults.isNotEmpty;

    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        color: Colors.blue[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.blue[700]),
                  onPressed: () {
                    Navigator.pushReplacement(  // ✅ التعديل هنا أيضاً
                      context,
                      MaterialPageRoute(builder: (context) => Home()),
                    );
                  },
                  padding: EdgeInsets.zero,
                  iconSize: 24,
                ),
                SizedBox(width: 4),
                Icon(Icons.qr_code, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Barcode Scan Result',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Barcode: ${widget.searchQuery}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),

            // عرض نتيجة الملاءمة إذا كان هناك منتج
            if (hasResults && _currentUserSkinType != null && _searchResults.isNotEmpty)
              _buildSuitabilityResult(_searchResults[0]),

            SizedBox(height: 8),
            if (hasResults)
              Text(
                'Found ${_searchResults.length} product(s)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No products found with this barcode',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try scanning again or check the barcode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
          ],)
    );
  }

  Widget _buildSuitabilityResult(Map<String, dynamic> product) {
    final suitability = _checkProductSuitability(product);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: suitability['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: suitability['color'], width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(suitability['icon'], color: suitability['color'], size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  suitability['recommendation'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: suitability['color'],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (suitability['shouldShowAlternatives'] == true)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'This product may not be ideal for your skin type.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _findAlternativeProducts(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text('Show Alternatives'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUserSkinTypeInfo() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.face, color: Colors.blue[700], size: 20),
          SizedBox(width: 8),
          Text(
            'Your Skin Type: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
          Text(
            _currentUserSkinType!.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.green[50],
      child: Row(
        children: [
          Icon(Icons.recommend, color: Colors.green[700], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alternative Products for Your Skin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'These products are suitable for your ${_currentUserSkinType ?? 'skin'} type',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _backToOriginalResults,
            child: Text('Back'),
          ),
        ],
      ),
    );
  }

  void _searchProducts(String query) {
    if (query.isEmpty && _selectedCategory == 'all') {
      setState(() {
        _searchResults = [];
        _showingAlternatives = false;
        _alternativeProducts.clear();
      });
      return;
    }

    setState(() {
      _searchResults = widget.products.where((product) {
        if (query.isEmpty && _selectedCategory == 'all') return false;

        final lowerCaseQuery = query.toLowerCase();

        if (query.isNotEmpty) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          final brand = product['brand']?.toString().toLowerCase() ?? '';
          final description = product['description']?.toString().toLowerCase() ?? '';

          final ingredients = product['ingredients'] as List<dynamic>? ?? [];
          final hasMatchingIngredient = ingredients.any((ingredient) =>
              ingredient.toString().toLowerCase().contains(lowerCaseQuery));

          final skinTypes = product['skinTypes'] as List<dynamic>? ?? [];
          final hasMatchingSkinType = skinTypes.any((skinType) =>
              skinType.toString().toLowerCase().contains(lowerCaseQuery));

          final hasTextMatch = name.contains(lowerCaseQuery) ||
              brand.contains(lowerCaseQuery) ||
              description.contains(lowerCaseQuery) ||
              hasMatchingIngredient ||
              hasMatchingSkinType;

          if (_selectedCategory != 'all') {
            final hasCategoryMatch = skinTypes.any((skinType) =>
                skinType.toString().toLowerCase().contains(_selectedCategory));
            return hasTextMatch && hasCategoryMatch;
          }

          return hasTextMatch;
        } else if (_selectedCategory != 'all') {
          final skinTypes = product['skinTypes'] as List<dynamic>? ?? [];
          return skinTypes.any((skinType) =>
              skinType.toString().toLowerCase().contains(_selectedCategory));
        }

        return false;
      }).toList();

      _showingAlternatives = false;
      _alternativeProducts.clear();
    });
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _showingAlternatives = false;
      _alternativeProducts.clear();
    });
    _searchProducts(_searchController.text);
  }

  Widget _buildSkinCategories() {
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _skinCategories.length,
        itemBuilder: (context, index) {
          final category = _skinCategories[index];
          final isSelected = _selectedCategory == category['id'];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _selectCategory(category['id']),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFF914D74) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Color(0xFF914D74), width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 30,
                        ),
                        SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  category['name'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Color(0xFF914D74) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(Cart cart, Favorites favorites) {
    final hasActiveSearch = _searchController.text.isNotEmpty ||
        _selectedCategory != 'all' ||
        widget.isFromBarcode;

    if (_showingAlternatives && _alternativeProducts.isNotEmpty) {
      return _buildAlternativeProducts(cart, favorites);
    }

    if (!hasActiveSearch) {
      return _buildEmptyState();
    }

    if (_searchResults.isEmpty && widget.isFromBarcode) {
      return _buildNoResultsForBarcode();
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildProductItem(_searchResults[index], cart, favorites);
      },
    );
  }

  Widget _buildAlternativeProducts(Cart cart, Favorites favorites) {
    if (_alternativeProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No alternative products found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching for products manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _backToOriginalResults,
              child: Text('Back to Results'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _alternativeProducts.length,
      itemBuilder: (context, index) {
        return _buildProductItem(_alternativeProducts[index], cart, favorites);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for products',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Try searching by name, brand, ingredients,\nskin type, or concerns',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          Text(
            'Or browse by skin type above',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          if (widget.isFromBarcode) ...[
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.qr_code_scanner),
              label: Text('Scan Another Barcode'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsForBarcode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            'Product Not Found',
            style: TextStyle(fontSize: 18, color: Colors.orange),
          ),
          SizedBox(height: 8),
          Text(
            'Barcode: ${widget.searchQuery}',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'No products match this barcode',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Scan Another Barcode'),
          ),
          SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Back to Scanner'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product, Cart cart, Favorites favorites) {
    double price = (product['price'] != null)
        ? double.parse(product['price'].toString())
        : 0.0;

    bool isFavorite = favorites.containsKey(product['id'] ?? '');

    final skinTypes = product['skinTypes'] as List<dynamic>? ?? [];
    final skinProblems = product['skinProblems'] as List<dynamic>? ?? [];
    final suitability = _checkProductSuitability(product);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          child: _buildProductImage(product['image'], product['name']),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name'] ?? 'Unknown Product',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: suitability['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: suitability['color'].withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    suitability['icon'],
                    size: 14,
                    color: suitability['color'],
                  ),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      suitability['recommendation'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: suitability['color'],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['brand'] ?? 'Unknown Brand',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 4),

            if (skinTypes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    children: skinTypes.map((type) {
                      final typeStr = type.toString();
                      final isUserType = typeStr.toLowerCase() == _currentUserSkinType;

                      return Chip(
                        label: Text(
                          typeStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isUserType ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isUserType ? Color(0xFF914D74) : Colors.blue[50],
                        labelStyle: TextStyle(
                          color: isUserType ? Colors.white : Colors.black,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 4),
                ],
              ),

            Text(
              'OMR ${price.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF914D74),
              ),
            ),
            SizedBox(height: 4),

            if (product['description'] != null)
              Text(
                _getShortDescription(product['description']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

            if (skinProblems.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: skinProblems.map((problem) {
                      return Chip(
                        label: Text(
                          problem.toString(),
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.green[50],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suitability['shouldShowAlternatives'] == true && !_showingAlternatives)
              IconButton(
                icon: Icon(Icons.recommend, color: Colors.blue),
                onPressed: () => _findAlternativeProducts(product),
                tooltip: 'Show alternative products',
              ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
              ),
              onPressed: () {
                _toggleFavorite(product, favorites);
              },
            ),
            IconButton(
              icon: Icon(Icons.add_shopping_cart),
              onPressed: () {
                _addToCart(context, product, cart);
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: product,
                userSkinType: _currentUserSkinType,
              ),
            ),
          );
        },
      ),
    );
  }

  String _getShortDescription(String description) {
    final firstLine = description.split('\n').first;
    if (firstLine.length > 60) {
      return '${firstLine.substring(0, 60)}...';
    }
    return firstLine;
  }

  Widget _buildProductImage(String? imageUrl, String productName) {
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return Icon(Icons.shopping_bag, size: 40);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.error);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }

  void _toggleFavorite(Map<String, dynamic> product, Favorites favorites) {
    final String productId = product['id'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    if (favorites.containsKey(productId)) {
      favorites.removeItem(productId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed from favorites'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      final String productName = product['name'] ?? 'Unknown Product';
      final double productPrice = (product['price'] != null)
          ? double.parse(product['price'].toString())
          : 0.0;
      final String productImage = product['image'] ?? '';

      favorites.addItem(productId, productName, productPrice, productImage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to favorites'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _addToCart(BuildContext context, Map<String, dynamic> product, Cart cart) {
    final String productId = product['id'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    final String productName = product['name'] ?? 'Unknown Product';
    final double productPrice = (product['price'] != null)
        ? double.parse(product['price'].toString())
        : 0.0;
    final String productImage = product['image'] ?? '';

    cart.addItem(
      productId,
      productName,
      productPrice,
      productImage,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$productName added to cart!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}