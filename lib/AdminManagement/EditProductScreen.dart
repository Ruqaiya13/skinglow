import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Screens/product_model.dart';
import 'ProductProvider.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({Key? key, required this.product}) : super(key: key);

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _updatingProduct = false;

  // البيانات الأساسية
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  //final TextEditingController _ratingController = TextEditingController();
  //final TextEditingController _reviewCountController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailedDescriptionController = TextEditingController();
  final TextEditingController _ingredientsDescriptionController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _textureController = TextEditingController();
  final TextEditingController _scentController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // القوائم
  final List<TextEditingController> _imagesControllers = [];
  final List<TextEditingController> _keyBenefitsControllers = [];
  final List<TextEditingController> _ingredientsControllers = [];
  final List<TextEditingController> _howToUseControllers = [];

  // الاختيارات
  List<String> _selectedSkinTypes = [];
  List<String> _selectedSkinProblems = [];
  bool _crueltyFree = false;
  bool _vegan = false;
  bool _allergenFree = false;
  bool _dermatologistTested = false;

  // قوائم الخيارات
  final List<String> _skinTypesOptions = [
    'dry', 'normal', 'combination', 'oily', 'sensitive', 'acne-prone', 'all-skin-type'
  ];

  final List<String> _skinProblemsOptions = [
    'acne', 'blackheads', 'large_pores', 'scar', 'wrinkles', 'redness',
    'dullness', 'dehydration', 'melasma', 'hyperpigmentation', 'texture',
    'excess oil', 'inflammation', 'sensitivity', 'sun damage'
  ];

  String _availability = 'In Stock';
  String _shippingInfo = 'Free shipping on orders over \$35';
  String _returnPolicy = '30-day return policy';

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

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

  void _loadProductData() {
    final product = widget.product;

    _idController.text = product['id'] ?? '';
    _nameController.text = product['name'] ?? '';
    _brandController.text = product['brand'] ?? '';
    _priceController.text = product['price']?.toString() ?? '';
    _originalPriceController.text = product['originalPrice']?.toString() ?? '';
    //_ratingController.text = product['rating']?.toString() ?? '4.5';
    //_reviewCountController.text = product['reviewCount']?.toString() ?? '0';
    _imageController.text = product['image'] ?? '';
    _descriptionController.text = product['description'] ?? '';
    _detailedDescriptionController.text = product['detailedDescription'] ?? '';
    _ingredientsDescriptionController.text = product['ingredientsDescription'] ?? '';
    _volumeController.text = product['volume'] ?? '';
    _textureController.text = product['texture'] ?? '';
    _scentController.text = product['scent'] ?? '';
    _countryController.text = product['countryOfOrigin'] ?? 'South Korea';

    _selectedSkinTypes = List<String>.from(product['skinTypes'] ?? []);
    _selectedSkinProblems = List<String>.from(product['skinProblems'] ?? []);
    _crueltyFree = product['crueltyFree'] ?? false;
    _vegan = product['vegan'] ?? false;
    _allergenFree = product['allergenFree'] ?? false;
    _dermatologistTested = product['dermatologistTested'] ?? false;

    _availability = product['availability'] ?? 'In Stock';
    _shippingInfo = product['shippingInfo'] ?? 'Free shipping on orders over \$35';
    _returnPolicy = product['returnPolicy'] ?? '30-day return policy';

    _imagesControllers.clear();
    if (product['images'] != null && product['images'] is List) {
      List<dynamic> imagesList = product['images'] as List;
      for (var image in imagesList) {
        if (image != null && image.toString().isNotEmpty) {
          _imagesControllers.add(TextEditingController(text: image.toString()));
        }
      }
    }
    _keyBenefitsControllers.clear();
    _keyBenefitsControllers.addAll(
        (List<String>.from(product['keyBenefits'] ?? [])).map((e) => TextEditingController(text: e))
    );

    _ingredientsControllers.clear();
    _ingredientsControllers.addAll(
        (List<String>.from(product['ingredients'] ?? [])).map((e) => TextEditingController(text: e))
    );

    _howToUseControllers.clear();
    _howToUseControllers.addAll(
        (List<String>.from(product['howToUse'] ?? [])).map((e) => TextEditingController(text: e))
    );

    // إذا كانت القوائم فارغة نضيف حقل واحد على الأقل
    if (_imagesControllers.isEmpty) _imagesControllers.add(TextEditingController());
    if (_keyBenefitsControllers.isEmpty) _keyBenefitsControllers.add(TextEditingController());
    if (_ingredientsControllers.isEmpty) _ingredientsControllers.add(TextEditingController());
    if (_howToUseControllers.isEmpty) _howToUseControllers.add(TextEditingController());
  }



  List<String> _getListFromControllers(List<TextEditingController> controllers) {
    return controllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _updatingProduct = true);

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      final updatedProduct = Product(
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
        shippingInfo: _shippingInfo,
        returnPolicy: _returnPolicy,
        createdAt: DateTime.now(),
      );

      final success = await productProvider.updateProduct(updatedProduct);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product updated successfully! 🎉')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product! ❌')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      setState(() => _updatingProduct = false);
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
        title: Text('Edit Product'),
        backgroundColor: Color(0xFF914D74),
      ),
      body: _updatingProduct
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
                      _buildTextField(_idController, 'Product ID', TextInputType.text, enabled: true),
                      _buildTextField(_nameController, 'Product Name', TextInputType.text),
                      _buildTextField(_brandController, 'Brand', TextInputType.text),
                      _buildTextField(_priceController, 'Price', TextInputType.number),
                      _buildTextField(_originalPriceController, 'Original Price', TextInputType.number),
                      //_buildTextField(_ratingController, 'Rating (0-5)', TextInputType.number),
                      //_buildTextField(_reviewCountController, 'Review Count', TextInputType.number),
                      _buildTextField(_imageController, 'Main Image URL', TextInputType.text),
                      _buildTextField(_volumeController, 'Volume/Size', TextInputType.text),
                      _buildTextField(_textureController, 'Texture', TextInputType.text),
                      _buildTextField(_scentController, 'Scent', TextInputType.text),
                      _buildTextField(_countryController, 'Country of Origin', TextInputType.text),
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
                      _buildTextArea(_descriptionController, 'Brief Description', 2),
                      _buildTextArea(_detailedDescriptionController, 'Detailed Description', 4),
                    ],
                  ),
                ),
              ),

              // القوائم
              _buildListField(
                title: 'Additional Images',
                controllers: _imagesControllers,
                onAdd: () => _addController(_imagesControllers),
                onRemove: (index) => _removeController(_imagesControllers, index),
                hintText: 'Image URL',
              ),

              _buildListField(
                title: 'Key Benefits',
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
                hintText: 'Ingredient',
              ),

              // وصف المكونات
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Ingredients Description',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      _buildTextArea(_ingredientsDescriptionController, 'Detailed ingredients description', 3),
                    ],
                  ),
                ),
              ),

              _buildListField(
                title: 'How to Use',
                controllers: _howToUseControllers,
                onAdd: () => _addController(_howToUseControllers),
                onRemove: (index) => _removeController(_howToUseControllers, index),
                hintText: 'Step',
              ),

              // أنواع البشرة والمشاكل
              _buildMultiSelectField(
                title: 'Suitable Skin Types',
                options: _skinTypesOptions,
                selectedValues: _selectedSkinTypes,
                onChanged: (value) => _selectedSkinTypes = value,
              ),

              _buildMultiSelectField(
                title: 'Targeted Skin Problems',
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
                        'Additional Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      _buildCheckboxField('Cruelty Free', _crueltyFree, (value) {
                        setState(() => _crueltyFree = value!);
                      }),
                      _buildCheckboxField('Vegan', _vegan, (value) {
                        setState(() => _vegan = value!);
                      }),
                      _buildCheckboxField('Allergen Free', _allergenFree, (value) {
                        setState(() => _allergenFree = value!);
                      }),
                      _buildCheckboxField('Dermatologist Tested', _dermatologistTested, (value) {
                        setState(() => _dermatologistTested = value!);
                      }),
                    ],
                  ),
                ),
              ),

              // زر التحديث
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF914D74),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Update Product',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, TextInputType keyboardType, {bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
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