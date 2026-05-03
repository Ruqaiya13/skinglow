// screens/admin/add_product_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Screens/product_model.dart';
import '../main.dart';
import 'ProductProvider.dart';


class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _addingProduct = false;

  // البيانات الأساسية
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _reviewCountController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailedDescriptionController = TextEditingController();
  final TextEditingController _ingredientsDescriptionController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _textureController = TextEditingController();
  final TextEditingController _scentController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // القوائم
  final List<TextEditingController> _imagesControllers = [TextEditingController()];
  final List<TextEditingController> _keyBenefitsControllers = [TextEditingController()];
  final List<TextEditingController> _ingredientsControllers = [TextEditingController()];
  final List<TextEditingController> _howToUseControllers = [TextEditingController()];

  // الاختيارات
  List<String> _selectedSkinTypes = [];
  List<String> _selectedSkinProblems = [];
  bool _crueltyFree = false;
  bool _vegan = false;
  bool _allergenFree = false;
  bool _dermatologistTested = false;
  bool isAdminEmail(String email) {
    List<String> adminEmails = [
      'oorro137@gmail.com',
      'admin@skinglow.com',
    ];
    return adminEmails.contains(email);
  }

  // قوائم الخيارات
  final List<String> _skinTypesOptions = [
    'dry', 'normal', 'combination', 'oily', 'sensitive', 'acne-prone', 'all-skin-type'
  ];

  final List<String> _skinProblemsOptions = [
    'acne', 'blackheads', 'large_pores', 'scar', 'wrinkles', 'redness',
    'dullness', 'dehydration', 'melasma', 'hyperpigmentation', 'texture',
    'excess oil', 'inflammation', 'sensitivity', 'sun damage'
  ];

  @override
  void initState() {
    super.initState();
    // تعيين قيم افتراضية
    //_ratingController.text = '4.5';
    //_reviewCountController.text = '0';
    _countryController.text = '';
    _availability = 'In Stock';
    //_shippingInfo = 'Free shipping on orders over \$35';
    _returnPolicy = '30-day return policy';
  }

  String _availability = 'In Stock';
  //String _shippingInfo = 'Free shipping on orders over \$35';
  String _returnPolicy = '30-day return policy';

  void _addController(List<TextEditingController> list) {
    setState(() {
      list.add(TextEditingController());
    });
  }

  void _removeController(List<TextEditingController> list, int index) {
    if (list.length > 1) {
      setState(() {
        list.removeAt(index);
      });
    }
  }

  List<String> _getListFromControllers(List<TextEditingController> controllers) {
    return controllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() => _addingProduct = true);

    try {
      print(' Start adding the product...');


      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must log in first.')),
        );
        return;
      }

      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      // تحقق من اتصال Firebase
      //اتاكد اذا الامور طيبه
      /*
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      bool isConnected = await productProvider.checkFirebaseConnection();

      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد اتصال بقاعدة البيانات')),
        );
        return;
      }*/

      // إنشاء المنتج مع تحقق إضافي
      final product = Product(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        price: double.parse(_priceController.text),
        originalPrice: double.parse(_originalPriceController.text),
        //rating: double.parse(_ratingController.text),
        //reviewCount: int.parse(_reviewCountController.text),
        image: _imageController.text.trim(),
        images: _getListFromControllers(_imagesControllers),
        description: _descriptionController.text.trim(),
        detailedDescription: _detailedDescriptionController.text.trim(),
        keyBenefits: _getListFromControllers(_keyBenefitsControllers),
        ingredients: _getListFromControllers(_ingredientsControllers),
        ingredientsDescription: _ingredientsDescriptionController.text.trim(),
        howToUse: _getListFromControllers(_howToUseControllers),
        volume: _volumeController.text.trim(),
        texture: _textureController.text.trim(),
        scent: _scentController.text.trim(),
        skinTypes: _selectedSkinTypes,
        skinProblems: _selectedSkinProblems,
        crueltyFree: _crueltyFree,
        vegan: _vegan,
        allergenFree: _allergenFree,
        dermatologistTested: _dermatologistTested,
        countryOfOrigin: _countryController.text.trim(),
        availability: _availability,
        //shippingInfo: _shippingInfo,
        returnPolicy: _returnPolicy,
        createdAt: DateTime.now(),
      );

      // طباعة بيانات المنتج للت Debug
      print(' Product data:');
      print('ID: ${product.id}');
      print('Name: ${product.name}');
      print('Brand: ${product.brand}');
      print('Price: ${product.price}');

      final success = await productProvider.addProduct(product);


      if (success) {
        print('The product has been added successfully');
        await _sendNewProductNotificationToUsers(); // إرسال إشعار للمستخدمين
        _sendNewProductNotification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('The product has been added successfully! ')),
        );
        Navigator.pop(context);
      } else {
        print('Product addition failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add the product! ')),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error in _submitProduct: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() => _addingProduct = false);
    }
  }
  // ✅ دالة إرسال إشعار المنتج الجديد
  void _sendNewProductNotification() {
    SimpleNotificationService.showNotification(
      title: '🆕 New Product Arrived!',
      body: '${_nameController.text} by ${_brandController.text} - OMR ${_priceController.text}',
    );
  }
  Future<void> _sendNewProductNotificationToUsers() async {
    try {
      // 1. جلب جميع المستخدمين من Firebase
      final usersSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .get();

      if (usersSnapshot.exists) {
        final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

        // 2. إنشاء بيانات الإشعار
        final notificationData = {
          'title': '🆕 New Product Arrived!',
          'body': '${_nameController.text} by ${_brandController.text} - OMR ${_priceController.text}',
          'type': 'new_product',
          'productId': _idController.text.trim(),
          'productName': _nameController.text.trim(),
          'isRead': false,
          'timestamp': timestamp,
        };

        // 3. الحصول على المستخدم الحالي (المدير)
        final currentUser = FirebaseAuth.instance.currentUser;

        // 4. إرسال الإشعار لكل مستخدم
        for (final userId in users.keys) {
          // تخطي حساب المدير (لا ترسل إشعار لنفسك)
          if (currentUser != null && userId == currentUser.uid) continue;

          // حفظ الإشعار في قاعدة البيانات
          await FirebaseDatabase.instance
              .ref('users/$userId/notifications/$notificationId')
              .set(notificationData);
        }

        print('✅ Notifications sent to all users');
      }
    } catch (e) {
      print('❌ Error sending notifications: $e');
    }
  }
  Widget _buildMultiSelectField({
    required String title,
    required List<String> options,
    required List<String> selectedValues,
    required Function(List<String>) onChanged,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selectedValues.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedValues.add(option);
                      } else {
                        selectedValues.remove(option);
                      }
                      onChanged(selectedValues);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListField({
    required String title,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required String hintText,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...controllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: '$hintText ${index + 1}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove, color: Colors.red),
                      onPressed: () => onRemove(index),
                    ),
                  ],
                ),
              );
            }),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add),
              label: Text('Add $title'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF914D74),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add new product'),
        backgroundColor: Color(0xFF914D74),
      ),
      body: _addingProduct
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // المعلومات الأساسية
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Basic Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(_idController, 'Product number (ID)', TextInputType.text),
                      _buildTextField(_nameController, 'Product Name', TextInputType.text),
                      _buildTextField(_brandController, 'Brand', TextInputType.text),
                      _buildTextField(_priceController, 'Price', TextInputType.number),
                      _buildTextField(_originalPriceController, 'Original price', TextInputType.number),
                      //_buildTextField(_ratingController, 'Evaluation (0-5)', TextInputType.number),
                      //_buildTextField(_reviewCountController, 'Number of reviews', TextInputType.number),
                      _buildTextField(_imageController, 'Main image link', TextInputType.text),
                      _buildTextField(_volumeController, 'Size/Quantity', TextInputType.text),
                      _buildTextField(_textureController, 'Figure', TextInputType.text),
                      _buildTextField(_scentController, 'The smell', TextInputType.text),
                      _buildTextField(_countryController, 'Country of origin', TextInputType.text),
                    ],
                  ),
                ),
              ),

              // الوصف
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Description',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      _buildTextArea(_descriptionController, 'Brief description', 2),
                      _buildTextArea(_detailedDescriptionController, 'Detailed description', 4),
                    ],
                  ),
                ),
              ),

              // القوائم
              _buildListField(
                title: 'Additional images',
                controllers: _imagesControllers,
                onAdd: () => _addController(_imagesControllers),
                onRemove: (index) => _removeController(_imagesControllers, index),
                hintText: 'Image link',
              ),

              _buildListField(
                title: 'Key benefits',
                controllers: _keyBenefitsControllers,
                onAdd: () => _addController(_keyBenefitsControllers),
                onRemove: (index) => _removeController(_keyBenefitsControllers, index),
                hintText: 'Benefit',
              ),

              _buildListField(
                title: 'Ingredients',
                controllers: _ingredientsControllers,
                onAdd: () => _addController(_ingredientsControllers),
                onRemove: (index) => _removeController(_ingredientsControllers, index),
                hintText: 'Component',
              ),

              // وصف المكونات
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Description of the ingredients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      _buildTextArea(_ingredientsDescriptionController, 'A detailed description of the components', 3),
                    ],
                  ),
                ),
              ),

              _buildListField(
                title: 'Instructions for use',
                controllers: _howToUseControllers,
                onAdd: () => _addController(_howToUseControllers),
                onRemove: (index) => _removeController(_howToUseControllers, index),
                hintText: 'Step',
              ),

              // أنواع البشرة والمشاكل
              _buildMultiSelectField(
                title: 'Suitable skin types',
                options: _skinTypesOptions,
                selectedValues: _selectedSkinTypes,
                onChanged: (value) => _selectedSkinTypes = value,
              ),

              _buildMultiSelectField(
                title: 'Targeted skin problems',
                options: _skinProblemsOptions,
                selectedValues: _selectedSkinProblems,
                onChanged: (value) => _selectedSkinProblems = value,
              ),

              // المعلومات الإضافية
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Additional information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      _buildCheckboxField('Free from cruelty to animals', _crueltyFree, (value) {
                        setState(() => _crueltyFree = value!);
                      }),
                      _buildCheckboxField('Vegetarian', _vegan, (value) {
                        setState(() => _vegan = value!);
                      }),
                      _buildCheckboxField('Allergen-free', _allergenFree, (value) {
                        setState(() => _allergenFree = value!);
                      }),
                      _buildCheckboxField('Tested by dermatologists', _dermatologistTested, (value) {
                        setState(() => _dermatologistTested = value!);
                      }),
                    ],
                  ),
                ),
              ),

              // زر الإرسال
              SizedBox(height: 20),
              /*ElevatedButton(
                onPressed: _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF914D74),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Add Product',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
               */
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  if (!isAdminEmail(user.email!)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('You do not have permission to add products.')),
                    );
                    return;
                  }

                  await _submitProduct(); // ← هذا هو الصحيح

                  // ملاحظة: الرسالة "تم إضافة المنتج بنجاح" موجودة بالفعل داخل _submitProduct
                },
                child: Text('add product'),
              )


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please fill out this field';
          }
          if (keyboardType == TextInputType.number && double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextArea(TextEditingController controller, String label, int maxLines) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildCheckboxField(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
          ),
          Text(label),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // تنظيف جميع الـ controllers
    _idController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    //_ratingController.dispose();
    //_reviewCountController.dispose();
    _imageController.dispose();
    _descriptionController.dispose();
    _detailedDescriptionController.dispose();
    _ingredientsDescriptionController.dispose();
    _volumeController.dispose();
    _textureController.dispose();
    _scentController.dispose();
    _countryController.dispose();

    for (var controller in _imagesControllers) controller.dispose();
    for (var controller in _keyBenefitsControllers) controller.dispose();
    for (var controller in _ingredientsControllers) controller.dispose();
    for (var controller in _howToUseControllers) controller.dispose();

    super.dispose();
  }
}