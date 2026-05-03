// lib/services/custom_notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomNotificationService {
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

    print('✅ Custom notifications initialized');
  }

  // ✅ دالة showOrderUpdateNotification المطلوبة
  static Future<void> showOrderUpdateNotification({
    required String orderNumber,
    required String newStatus,
    required String userName,
  }) async {
    await _ensureInitialized();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'order_updates_channel',
      'Order Updates',
      channelDescription: 'Notifications for order status updates',
      importance: Importance.high,
      priority: Priority.high,
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