import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // تهيئة الإشعارات
  static Future<void> initialize() async {
    // طلب الإذن (لـ iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // تهيئة الإشعارات المحلية
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // التعامل مع النقر على الإشعار
        print('Notification clicked: ${response.payload}');
      },
    );

    // التعامل مع الإشعارات في الخلفية
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  // التعامل مع الإشعارات في الواجهة
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showLocalNotification(message);
  }

  // التعامل مع الإشعارات عند فتح التطبيق
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Background message: ${message.notification?.title}');
  }

  // عرض إشعار محلي
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'coupon_channel',
      'Coupon Notifications',
      channelDescription: 'Notifications for new coupons and discounts',
      importance: Importance.high,
      priority: Priority.high,
    );

    final DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails();

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'New Coupon',
      message.notification?.body ?? 'Check out our new discount!',
      details,
      payload: message.data['couponCode'],
    );
  }

  // الحصول على token الجهاز
  static Future<String?> getDeviceToken() async {
    return await _firebaseMessaging.getToken();
  }
}
// هذيلا تبع وصل منتج جديد

class SimpleNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // ✅ تهيئة الإشعارات
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initializationSettings);
    _isInitialized = true;

    print('✅ Simple notifications initialized');
  }

  // ✅ إشعار تحديث الطلب - معدل
  static Future<void> showOrderUpdateNotification({
    required String orderNumber,
    required String newStatus,
    required String userName,
  }) async {
    await _ensureInitialized();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'order_updates', // ID القناة
      'Order Updates', // اسم القناة
      channelDescription: 'Notifications for your order status updates',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF914D74), // استخدام اللون الأساسي للتطبيق
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails =
    DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String title = '📦 Order #$orderNumber Update';
    String body = _getOrderStatusMessage(newStatus, userName);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );

    await _saveNotificationToHistory(title, body);
    print('📦 Order update notification sent for order #$orderNumber');
  }

  // ✅ إشعار عام - معدل
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'All app notifications',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.blue,
      enableVibration: true,
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

    await _saveNotificationToHistory(title, body);
    print('📢 Notification sent: $title');
  }

  // ✅ رسائل حالة الطلب
  static String _getOrderStatusMessage(String status, String userName) {
    switch (status) {
      case 'Pending':
        return 'Hello $userName, your order has been received and is being processed.';
      case 'Confirmed':
        return 'Hello $userName, your order has been confirmed!';
      case 'Processing':
        return 'Hello $userName, your order is now being processed.';
      case 'Shipped':
        return '🎉 Hello $userName, your order has been shipped! Track your package.';
      case 'Delivered':
        return '✅ Hello $userName, your order has been delivered! Thank you for shopping with us.';
      case 'Cancelled':
        return 'Hello $userName, your order has been cancelled. Contact support for more details.';
      default:
        return 'Hello $userName, your order status has been updated to: $status';
    }
  }

  // ✅ حفظ في السجل
  static Future<void> _saveNotificationToHistory(String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString('sent_notifications');
      final List<String> notifications = [];

      if (existing != null && existing.isNotEmpty) {
        notifications.addAll(existing.split('||'));
      }

      final String newNotification = '$title|$body|${DateTime.now().toIso8601String()}';
      notifications.insert(0, newNotification);

      // حفظ آخر 50 إشعار فقط
      if (notifications.length > 50) {
        notifications.removeLast();
      }

      await prefs.setString('sent_notifications', notifications.join('||'));
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  // ✅ التأكد من التهيئة
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}

class UserNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // ✅ حفظ توكن الجهاز للمستخدم
  static Future<void> saveUserToken(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _databaseRef
            .child('users')
            .child(userId)
            .child('fcmToken')
            .set(token);
        print('✅ User FCM token saved: $token');
      }
    } catch (e) {
      print('❌ Error saving user token: $e');
    }
  }

  // ✅ إرسال إشعار لمستخدم معين
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // الحصول على توكن المستخدم
      final tokenSnapshot = await _databaseRef
          .child('users')
          .child(userId)
          .child('fcmToken')
          .get();

      if (tokenSnapshot.exists) {
        final String userToken = tokenSnapshot.value.toString();

        // هنا تحتاج لـ Cloud Functions أو server لإرسال الإشعارات
        // هذا مثال مبسط
        print('📢 Should send notification to user $userId');
        print('Title: $title');
        print('Body: $body');
        print('User Token: $userToken');

        // في التطبيق الحقيقي، تحتاج لاستدعاء Cloud Functions
        // await _sendViaCloudFunctions(userToken, title, body, data);
      } else {
        print('❌ User $userId has no FCM token');
      }
    } catch (e) {
      print('❌ Error sending notification to user: $e');
    }
  }

  // ✅ إرسال إشعار تحديث الطلب للمستخدم
  static Future<void> sendOrderUpdateToUser({
    required String userId,
    required String orderNumber,
    required String newStatus,
    required String userName,
  }) async {
    // التحقق من تفضيلات المستخدم أولاً
    final userPrefs = await _getUserNotificationPreferences(userId);

    if (userPrefs['orderUpdates'] ?? true) {
      await sendNotificationToUser(
        userId: userId,
        title: '📦 Order #$orderNumber Update',
        body: _getOrderStatusMessage(newStatus, userName),
        data: {
          'type': 'order_update',
          'orderNumber': orderNumber,
          'status': newStatus,
        },
      );
    }
  }

  // ✅ الحصول على تفضيلات المستخدم
  static Future<Map<String, bool>> _getUserNotificationPreferences(String userId) async {
    try {
      final snapshot = await _databaseRef
          .child('users')
          .child(userId)
          .child('notificationPreferences')
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          'orderUpdates': data['orderUpdates'] ?? true,
          'discountsAndOffers': data['discountsAndOffers'] ?? true,
          'newProductArrival': data['newProductArrival'] ?? true,
        };
      }
    } catch (e) {
      print('❌ Error getting user preferences: $e');
    }

    return {
      'orderUpdates': true,
      'discountsAndOffers': true,
      'newProductArrival': true,
    };
  }

  static String _getOrderStatusMessage(String status, String userName) {
    switch (status) {
      case 'Pending': return 'Hello $userName, your order has been received.';
      case 'Confirmed': return 'Hello $userName, your order has been confirmed!';
      case 'Processing': return 'Hello $userName, your order is being processed.';
      case 'Shipped': return '🎉 Hello $userName, your order has been shipped!';
      case 'Delivered': return '✅ Hello $userName, your order has been delivered!';
      case 'Cancelled': return 'Hello $userName, your order has been cancelled.';
      default: return 'Hello $userName, your order status updated: $status';
    }
  }
}