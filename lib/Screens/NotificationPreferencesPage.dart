import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPreferencesPage extends StatefulWidget {
  @override
  _NotificationPreferencesPageState createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref().child('users');

  bool _newProductArrival = true;
  bool _discountsAndOffers = true;
  bool _orderUpdates = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _databaseRef
          .child(user!.uid)
          .child('notificationPreferences')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _newProductArrival = data['newProductArrival'] ?? true;
          _discountsAndOffers = data['discountsAndOffers'] ?? true;
          _orderUpdates = data['orderUpdates'] ?? true;
          _isLoading = false;
        });
      } else {
        // إذا لم توجد تفضيلات سابقة، قم بإنشاء القيم الافتراضية
        await _setDefaultPreferences();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading preferences: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultPreferences() async {
    if (user == null) return;

    final defaultPreferences = {
      'newProductArrival': true,
      'discountsAndOffers': true,
      'orderUpdates': true,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    await _databaseRef
        .child(user!.uid)
        .child('notificationPreferences')
        .set(defaultPreferences);
  }

  Future<void> _updatePreference(String key, bool value) async {
    if (user == null) return;

    try {
      await _databaseRef
          .child(user!.uid)
          .child('notificationPreferences')
          .update({
        key: value,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Preference updated: $key = $value');

      // 🔧 تحديث تلقائي لصفحة الإشعارات عند التغيير
      _notifyUserNotificationsPage();
    } catch (e) {
      print('❌ Error updating preference: $e');
      // إعادة تحميل التفضيلات في حالة الخطأ
      _loadNotificationPreferences();
    }
  }

  // 🔧 دالة جديدة: إشعار صفحة الإشعارات بالتحديث
  void _notifyUserNotificationsPage() {
    // نستخدم ValueNotifier للإشعار بالتغييرات
    // يمكنك استخدام Provider أو أي طريقة أخرى تناسبك
    // هذا مثال مبسط:
    try {
      FirebaseDatabase.instance
          .ref('users/${user!.uid}/notificationPreferences/lastUpdated')
          .set(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error notifying changes: $e');
    }
  }

  void _showPreferenceChangeInfo(String type, bool newValue) {
    String message = '';

    switch (type) {
      case 'newProductArrival':
        message = newValue
            ? '✅ You will now receive notifications when new products are added'
            : '🔕 You will NOT receive notifications for new products';
        break;
      case 'discountsAndOffers':
        message = newValue
            ? '✅ You will now receive notifications about discounts and offers'
            : '🔕 You will NOT receive notifications for discounts and offers';
        break;
      case 'orderUpdates':
        message = newValue
            ? '✅ You will now receive notifications about your order status'
            : '🔕 You will NOT receive notifications for order updates';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: newValue ? Colors.green : Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notification Preferences'),
          backgroundColor: Color(0xFF914D74),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Preferences'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotificationPreferences,
            tooltip: 'Refresh Preferences',
          ),
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF914D74).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: Color(0xFF914D74)),
                      SizedBox(width: 8),
                      Text(
                        'Manage Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF914D74),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Control which notifications you receive from SkinGlow',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),

                  // 🔧 إضافة إحصائيات سريعة
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Enabled', _countActiveNotifications(), Colors.green),
                      _buildStatItem('Disabled', _countInactiveNotifications(), Colors.orange),
                      _buildStatItem('All', 3, Colors.blue),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 🔔 Notification Switches
            _buildNotificationSwitch(
              icon: Icons.new_releases,
              title: 'New Product Arrival',
              subtitle: 'Get notified when new products are added to SkinGlow',
              value: _newProductArrival,
              onChanged: (value) {
                setState(() => _newProductArrival = value);
                _updatePreference('newProductArrival', value);
                _showPreferenceChangeInfo('newProductArrival', value);
              },
              notificationType: 'product',
            ),

            _buildNotificationSwitch(
              icon: Icons.local_offer,
              title: 'Discounts and Offers',
              subtitle: 'Receive notifications about coupons, sales, and special offers',
              value: _discountsAndOffers,
              onChanged: (value) {
                setState(() => _discountsAndOffers = value);
                _updatePreference('discountsAndOffers', value);
                _showPreferenceChangeInfo('discountsAndOffers', value);
              },
              notificationType: 'discount',
            ),

            _buildNotificationSwitch(
              icon: Icons.shopping_bag,
              title: 'Order Updates',
              subtitle: 'Get updates about your order status, shipping, and delivery',
              value: _orderUpdates,
              onChanged: (value) {
                setState(() => _orderUpdates = value);
                _updatePreference('orderUpdates', value);
                _showPreferenceChangeInfo('orderUpdates', value);
              },
              notificationType: 'order',
            ),

            SizedBox(height: 32),

            // 📱 Quick Actions
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF914D74),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.grey[800],
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _resetToDefaults,
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.notifications, size: 16),
                        label: Text('Test Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF914D74),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _sendTestNotification,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ℹ️ Information Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'How It Works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Changes take effect immediately\n'
                        '• Disabled notifications will not be shown\n'
                        '• You can change settings anytime\n'
                        '• Notifications are saved for 30 days',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required String notificationType,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? _getTypeColor(notificationType).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: value ? _getTypeColor(notificationType) : Colors.grey,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(notificationType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Type: ${notificationType.toUpperCase()}',
                style: TextStyle(
                  fontSize: 10,
                  color: _getTypeColor(notificationType),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _getTypeColor(notificationType),
          activeTrackColor: _getTypeColor(notificationType).withOpacity(0.3),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'product':
        return Colors.purple;
      case 'discount':
        return Colors.orange;
      case 'order':
        return Colors.blue;
      default:
        return Color(0xFF914D74);
    }
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  int _countActiveNotifications() {
    int count = 0;
    if (_newProductArrival) count++;
    if (_discountsAndOffers) count++;
    if (_orderUpdates) count++;
    return count;
  }

  int _countInactiveNotifications() {
    return 3 - _countActiveNotifications();
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset to Defaults'),
        content: Text('Are you sure you want to reset all notification preferences to default settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setDefaultPreferences();
      await _loadNotificationPreferences();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Notification preferences reset to defaults'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    // إرسال إشعار تجريبي للمستخدم
    if (user == null) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testNotificationId = 'test_$timestamp';

      final testNotification = {
        'title': 'Test Notification',
        'body': 'This is a test notification to verify your preferences are working.',
        'type': 'test',
        'timestamp': timestamp,
        'isRead': false,
      };

      await _databaseRef
          .child(user!.uid)
          .child('notifications')
          .child(testNotificationId)
          .set(testNotification);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test notification sent! Check your notifications page.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error sending test notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sending test notification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help, color: Colors.blue),
            SizedBox(width: 8),
            Text('Notification Preferences Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                'New Product Arrival',
                'Get notified immediately when new skincare products are added to our store.',
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                'Discounts and Offers',
                'Receive alerts about sales, coupons, and special promotions.',
              ),
              SizedBox(height: 12),
              _buildHelpItem(
                'Order Updates',
                'Stay informed about your order status, shipping, and delivery.',
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text(
                'Important Notes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• Changes take effect immediately\n'
                    '• Already received notifications will not be deleted\n'
                    '• You can enable/disable anytime\n'
                    '• App restart is not required',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!', style: TextStyle(color: Color(0xFF914D74))),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF914D74),
          ),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}