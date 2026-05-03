// providers/product_provider.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import '../Screens/product_model.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _loading = false;
  bool _useFirebase = false;
  String _dataSource = 'local';

  List<Product> get products => _products;
  bool get loading => _loading;
  String get dataSource => _dataSource;



  // جلب جميع المنتجات
  Future<void> fetchProducts() async {
    _loading = true;
    notifyListeners();

    try {
      DatabaseReference productsRef = FirebaseDatabase.instance.ref("products");
      DatabaseEvent snapshot = await productsRef.once();

      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> productsData = snapshot.snapshot.value as Map<dynamic, dynamic>;

        _products = productsData.entries.map((entry) {
          try {
            // استخدام fromJson من المودل
            return Product.fromJson({
              'id': entry.key.toString(),
              ...Map<String, dynamic>.from(entry.value as Map),
            });
          } catch (e) {
            print('❌ Error parsing product ${entry.key}: $e');
            // إرجاع منتج افتراضي في حالة الخطأ
            return Product(
              id: entry.key.toString(),
              name: 'Unknown Product',
              brand: 'Unknown Brand',
              price: 0.0,
              image: '',
              description: '',
              skinTypes: [],
              skinProblems: [],
              createdAt: DateTime.now(),
            );
          }
        }).where((product) => product.name != 'Unknown Product').toList();

        _products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        print('✅ تم جلب ${_products.length} منتج من Firebase');
      } else {
        _products = [];
        print('⚠️ لا توجد منتجات في Firebase');
      }
    } catch (error) {
      print('❌ خطأ في جلب المنتجات: $error');
      _products = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // إضافة منتج جديد
  Future<bool> addProduct(Product product) async {
    try {
      DatabaseReference productsRef = FirebaseDatabase.instance.ref("products");

      String productId = product.id.isNotEmpty ? product.id : 'product_${DateTime.now().millisecondsSinceEpoch}';

      // استخدام toJson من المودل
      Map<String, dynamic> productData = product.toJson();
      // تأكد من أن الـ ID مضاف للبيانات
      //productData['id'] = productId;
      // تحقق من أن productData يحتوي على جميع الحقول
      print('📦 Product Data: $productData'); // للإ Debug

      //print('🔄 محاولة إضافة منتج برقم: $productId');

      await productsRef.child(productId).set(productData);

      print('✅ تم إضافة المنتج بنجاح إلى Firebase');
      return true;
    } catch (error) {
      print('❌ خطأ في إضافة المنتج: $error');
      return false;
    }
  }

  // حذف منتج
  Future<bool> deleteProduct(String productId) async {
    try {
      DatabaseReference productsRef = FirebaseDatabase.instance.ref("products/$productId");
      await productsRef.remove();

      // حذف من القائمة المحلية
      _products.removeWhere((product) => product.id == productId);
      notifyListeners();

      print('✅ تم حذف المنتج بنجاح: $productId');
      return true;
    } catch (error) {
      print('❌ خطأ في حذف المنتج: $error');
      return false;
    }
  }
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('products');
  // تحديث منتج
  Future<bool> updateProduct(Product product) async {
    try {
      print('🔄 === بدء تحديث المنتج ===');
      print('Product ID: ${product.id}');
      print('Product Name: ${product.name}');

      // استخدام الطريق المباشر للتأكد
      DatabaseReference ref = FirebaseDatabase.instance.ref("products/${product.id}");

      // تحويل المنتج إلى Map
      Map<String, dynamic> productData = product.toJson();

      // طباعة البيانات المرسلة
      print('📦 بيانات المنتج المرسلة:');
      print('Name: ${productData['name']}');
      print('Price: ${productData['price']}');
      print('Image: ${productData['image']}');

      // استخدام set() بدلاً من update() لضمان حفظ جميع البيانات
      await ref.set(productData);

      print('✅ تم حفظ البيانات في Firebase');

      // التحقق من أن البيانات حفظت
      DataSnapshot snapshot = await ref.get();
      if (snapshot.exists) {
        print('✅ تم التحقق من حفظ البيانات بنجاح');
        Map<dynamic, dynamic> savedData = snapshot.value as Map;
        print('📋 البيانات المحفوظة: ${savedData['name']} - ${savedData['price']}');
        return true;
      } else {
        print('❌ البيانات لم تحفظ في Firebase');
        return false;
      }

    } catch (e, stackTrace) {
      print('❌ خطأ في updateProduct: $e');
      print('Stack trace: $stackTrace');

      // محاولة بديلة
      try {
        print('🔄 محاولة بديلة باستخدام الطريق المباشر...');
        DatabaseReference directRef = FirebaseDatabase.instance.ref().child("products/${product.id}");
        await directRef.set(product.toJson());
        print('✅ تم التحديث باستخدام الطريق المباشر');
        return true;
      } catch (e2) {
        print('❌ فشلت المحاولة البديلة أيضاً: $e2');
        return false;
      }
    }
  }

  // دالة مساعدة للتحقق من اتصال Firebase
  //عشان الامور تمشي
  //Future<bool> checkFirebaseConnection() async {
    /*try {
      print('🔍 فحص اتصال Firebase...');

      // الطريقة 1: فحص الاتصال الأساسي
      DatabaseReference ref = FirebaseDatabase.instance.ref(".info/connected");
      DatabaseEvent event = await ref.once();
      bool isConnected = event.snapshot.value == true;

      if (isConnected) {
        print('✅ اتصال Firebase ناجح');

        // الطريقة 2: محاولة قراءة بسيطة
        try {
          DatabaseReference testRef = FirebaseDatabase.instance.ref("test_connection");
          await testRef.set({
            "timestamp": DateTime.now().toString(),
            "test": "connection_check"
          });
          await testRef.remove();
          print('✅ اختبار الكتابة ناجح');
        } catch (e) {
          print('⚠️ يمكن القراءة ولكن مشكلة في الكتابة: $e');
        }

        return true;
      } else {
        print('❌ لا يوجد اتصال بـ Firebase');
        return false;
      }

    } catch (e) {
      print('❌ فشل اتصال Firebase: $e');

      // تحقق من الأخطاء الشائعة
      if (e.toString().contains('permission_denied')) {
        print('🔒 مشكلة في قواعد Firebase - Permission Denied');
      } else if (e.toString().contains('network_error')) {
        print('🌐 مشكلة في الشبكة');
      } else if (e.toString().contains('database_not_found')) {
        print('📁 قاعدة البيانات غير موجودة - تحقق من الرابط');
      }

      return false;
    }
  }
*/
    Future<bool> checkFirebaseConnection() async {
      try {
        DatabaseReference testRef = FirebaseDatabase.instance.ref("test_connection_check");
        await testRef.set({"ping": DateTime.now().toIso8601String()});
        await testRef.remove();
        print('✅ اتصال Firebase ناجح');
        return true;
      } catch (e) {
        print('❌ فشل اتصال Firebase: $e');
        return false;
      }
    }

    // البحث عن منتج بالاسم
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;

    return _products.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.brand.toLowerCase().contains(query.toLowerCase()) ||
          product.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // الحصول على منتج بواسطة ID
  Product? getProductById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  // الحصول على منتجات حسب نوع البشرة
  List<Product> getProductsBySkinType(String skinType) {
    return _products.where((product) =>
        product.skinTypes.contains(skinType.toLowerCase())
    ).toList();
  }

  // الحصول على منتجات حسب مشكلة البشرة
  List<Product> getProductsBySkinProblem(String skinProblem) {
    return _products.where((product) =>
        product.skinProblems.contains(skinProblem.toLowerCase())
    ).toList();
  }
}