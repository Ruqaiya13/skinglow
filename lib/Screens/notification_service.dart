// services/notification_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  static final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref().child('users');

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // دالة للتحقق إذا كان المستخدم يرغب في استقبال إشعار معين
  static Future<bool> _checkUserNotificationPreference(String notificationType) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _databaseRef
          .child(user.uid)
          .child('notificationPreferences')
          .get();

      if (snapshot.exists) {
        final preferences = snapshot.value as Map<dynamic, dynamic>;

        // التحقق حسب نوع الإشعار
        switch (notificationType) {
          case 'new_product':
            return preferences['newProductArrival'] ?? true;
          case 'new_discount':
          case 'product_discount':
            return preferences['discountsAndOffers'] ?? true;
          case 'order_update':
            return preferences['orderUpdates'] ?? true;
          default:
            return true; // الإشعارات العامة مسموحة
        }
      }
    } catch (e) {
      print('Error checking notification preferences: $e');
    }

    return true; // الافتراضي هو السماح
  }

  // دالة إرسال الإشعارات مع التحقق من التفضيلات
  static Future<void> sendNotificationWithPreferenceCheck({
    required String title,
    required String body,
    required String type,
    String? productId,
    String? couponCode,
    double? discountValue,
    String? discountType,
  }) async {
    try {
      // 1. التحقق من تفضيلات المستخدم
      final isAllowed = await _checkUserNotificationPreference(type);

      if (!isAllowed) {
        print('⚠️ User has disabled $type notifications');
        return;
      }

      // 2. جلب جميع المستخدمين
      final usersSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .get();

      if (usersSnapshot.exists) {
        final users = Map<String, dynamic>.from(usersSnapshot.value as Map);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final notificationId = '${type}_${timestamp}';

        // 3. بيانات الإشعار
        final notificationData = {
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'timestamp': timestamp,
          'productId': productId,
          'couponCode': couponCode,
          'discountValue': discountValue,
          'discountType': discountType,
        };

        final currentUser = _auth.currentUser;
        int sentCount = 0;
        int skippedCount = 0;

        // 4. إرسال الإشعار لكل مستخدم مع التحقق من تفضيلاته
        for (final userId in users.keys) {
          // تخطي المستخدم الحالي (المدير)
          if (currentUser != null && userId == currentUser.uid) continue;

          // التحقق من تفضيلات المستخدم
          final userPrefsSnapshot = await _databaseRef
              .child(userId)
              .child('notificationPreferences')
              .get();

          bool userAllowsNotification = true;

          if (userPrefsSnapshot.exists) {
            final userPreferences = userPrefsSnapshot.value as Map<dynamic, dynamic>;

            switch (type) {
              case 'new_product':
                userAllowsNotification = userPreferences['newProductArrival'] ?? true;
                break;
              case 'new_discount':
              case 'product_discount':
                userAllowsNotification = userPreferences['discountsAndOffers'] ?? true;
                break;
              case 'order_update':
                userAllowsNotification = userPreferences['orderUpdates'] ?? true;
                break;
            }
          }

          if (userAllowsNotification) {
            await FirebaseDatabase.instance
                .ref('users/$userId/notifications/$notificationId')
                .set(notificationData);
            sentCount++;
          } else {
            skippedCount++;
          }
        }

        print('✅ Notifications: $sentCount sent, $skippedCount skipped (type: $type)');
      }
    } catch (e) {
      print('❌ Error sending notifications with preference check: $e');
    }
  }
}