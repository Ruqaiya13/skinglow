import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skinglow/Screens/Home.dart';
import 'AdminManagement/DiscountManagementScreen.dart';
import 'AdminManagement/ProductProvider.dart';
import 'AdminManagement/UserManagememtProvider.dart';
import 'AdminManagement/UserManagement.dart';
import 'AdminManagement/add_product_screen.dart';
import 'AdminManagement/firebase_messaging_service.dart';
import 'Screens/CustomNotificationService.dart';
import 'Screens/NotificationHistoryScreen.dart';
import 'Screens/NotificationPreferencesPage.dart';
import 'Screens/checkout_screen.dart';
import 'Screens/favorites_model.dart';
import 'Screens/payment_model.dart';
import 'Screens/Login.dart';
import 'Screens/userNotification.dart';
import 'SkinAnalysis/skin_type_provider.dart';
import 'Screens/splash_screen.dart';
import 'Screens/Registration.dart';
import 'Screens/cart_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Screens/user_provider.dart';
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ✅ التهيئة المبسطة للإشعارات
  await SimpleNotificationService.initialize();
  await FirebaseMessagingService.initialize();
  HttpOverrides.global = MyHttpOverrides();

  try {
    //  Firebase تهيئة
    await Firebase.initializeApp();
    print('✅ Firebase initialized for Admin operations');
  } catch (e) {
    print('⚠️ Firebase init failed, but app can still work with local JSON');
  }
  await CustomNotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserManagementProvider()),
        ChangeNotifierProvider(create: (_) => Cart()),
        ChangeNotifierProvider(create: (_) => Favorites()),
        ChangeNotifierProvider(create: (_) => Payment()),
        ChangeNotifierProvider(create: (_) => SkinTypeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ProductProvider()),
        //ChangeNotifierProvider(create: (_) => DiscountProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // تعيين userId في Cart و Favorites عند تسجيل الدخول
        final cart = Provider.of<Cart>(context, listen: false);
        final favorites = Provider.of<Favorites>(context, listen: false);
        final productProvider = Provider.of<ProductProvider>(context, listen: false);

        cart.setUserId(user.uid);
        favorites.setUserId(user.uid);
        productProvider.fetchProducts();

        print("✅ User ID set in Cart and Favorites: ${user.uid}");
      } else {
        // مسح userId عند تسجيل الخروج
        final cart = Provider.of<Cart>(context, listen: false);
        final favorites = Provider.of<Favorites>(context, listen: false);

        print("❌ User logged out, cleared Cart and Favorites");
      }
    });
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        print("✅ User logged in: ${user.uid}");
        // تحميل البيانات عند تسجيل الدخول
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        productProvider.fetchProducts();
      } else {
        print("❌ User logged out");
      }
    });

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Firebase',
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(
          child: LoginPage(),
        ),
        '/login': (context) => LoginPage(),
        '/signUp': (context) => SignUpPage(),
        '/home': (context) => Home(),
        '/checkout': (context) => CheckoutScreen(),
        '/add-product': (context) => AddProductScreen(),
        '/user-management': (context) => UserManagementScreen(),
        '/notification-history': (context) => NotificationHistoryScreen(),
        '/notifications': (context) => UserNotificationsScreen(),
        '/notification-preferences': (context) => NotificationPreferencesPage(),
      },
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
class SimpleNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ✅ تهيئة مبسطة للإشعارات
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initializationSettings);
    print('✅ Simple notifications initialized');
  }

  // ✅ دالة مبسطة لعرض أي إشعار
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'simple_channel',
      'Simple Notifications',
      channelDescription: 'All app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
    // حفظ الإشعار في السجل
    await _saveNotificationToHistory(title, body);

    print('📢 Notification sent and saved: $title');
  }

  // ✅ حفظ الإشعار في السجل
  static Future<void> _saveNotificationToHistory(String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // الحصول على الإشعارات الحالية
      final String? existingNotifications = prefs.getString('sent_notifications');
      final List<String> notificationsList = [];

      if (existingNotifications != null && existingNotifications.isNotEmpty) {
        notificationsList.addAll(existingNotifications.split('||'));
      }

      // إضافة الإشعار الجديد
      final String newNotification = '$title|$body|${DateTime.now().toIso8601String()}';
      notificationsList.insert(0, newNotification); // إضافة في البداية

      // حفظ فقط آخر 50 إشعار (لتجنب التخزين الزائد)
      if (notificationsList.length > 50) {
        notificationsList.removeLast();
      }

      // حفظ في SharedPreferences
      await prefs.setString('sent_notifications', notificationsList.join('||'));

    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }
}