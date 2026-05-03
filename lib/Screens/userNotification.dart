import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'NotificationPreferencesPage.dart';

class UserNotificationsScreen extends StatefulWidget {
  @override
  _UserNotificationsScreenState createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _filteredNotifications = [];
  bool _isLoading = true;

  bool _newProductArrival = true;
  bool _discountsAndOffers = true;
  bool _orderUpdates = true;
  bool _showOnlyEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUserPreferences();
    _setupRealtimeListener();
  }
  Future<void> _loadUserPreferences() async {
    if (user == null) {
      await _loadNotifications();
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user!.uid}/notificationPreferences')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _newProductArrival = data['newProductArrival'] ?? true;
          _discountsAndOffers = data['discountsAndOffers'] ?? true;
          _orderUpdates = data['orderUpdates'] ?? true;
        });
      }

      // تحميل الإشعارات بعد التفضيلات
      await _loadNotifications();
    } catch (e) {
      print('❌ Error loading preferences: $e');
      await _loadNotifications();
    }
  }

  void _setupRealtimeListener() {
    if (user == null) return;

    // 🔧 الاستماع لتغييرات التفضيلات أيضاً
    FirebaseDatabase.instance
        .ref('users/${user!.uid}/notificationPreferences')
        .onValue
        .listen((event) {
      if (mounted) {
        _loadUserPreferences();
      }
    });

    FirebaseDatabase.instance
        .ref('users/${user!.uid}/notifications')
        .onValue
        .listen((event) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  Future<void> _loadNotifications() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user!.uid}/notifications')
          .orderByChild('timestamp')
          .get();

      List<Map<String, dynamic>> allNotifications = [];

      if (snapshot.exists) {
        final notificationsMap = Map<dynamic, dynamic>.from(snapshot.value as Map);

        allNotifications = notificationsMap.entries.map((entry) {
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value),
          };
        }).toList();

        // ترتيب من الأحدث إلى الأقدم
        allNotifications.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      }

      // 🔧 تطبيق الفلترة
      _applyFilter(allNotifications);

      setState(() {
        _notifications = allNotifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }
  void _applyFilter(List<Map<String, dynamic>> allNotifications) {
    if (!_showOnlyEnabled) {
      _filteredNotifications = allNotifications;
      return;
    }

    _filteredNotifications = allNotifications.where((notification) {
      final type = notification['type'] ?? 'general';

      switch (type) {
        case 'new_product':
        case 'product_arrival':
          return _newProductArrival;
        case 'new_discount':
        case 'product_discount':
        case 'coupon':
        case 'discount':
          return _discountsAndOffers;
        case 'order_update':
        case 'order_status':
        case 'shipping':
        case 'order':
          return _orderUpdates;
        case 'test':
        case 'general':
        case 'system':
          return true; // الإشعارات العامة دائماً معروضة
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _markAsRead(String notificationId) async {
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user!.uid}/notifications/$notificationId/isRead')
          .set(true);

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Clear'),
        content: Text('Are you sure you want to clear all your notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseDatabase.instance
            .ref('users/${user!.uid}/notifications')
            .remove();

        setState(() {
          _notifications = [];
          _filteredNotifications = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All notifications cleared')),
        );
      } catch (e) {
        print('Error clearing notifications: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing notifications')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Notifications')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please login to view notifications'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Notifications'),
        backgroundColor: Color(0xFF914D74),
        actions: [
          // 🔧 إضافة زر للتصفية
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Notification Settings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_filter',
                child: Row(
                  children: [
                    Icon(_showOnlyEnabled ? Icons.toggle_on : Icons.toggle_off, size: 20),
                    SizedBox(width: 8),
                    Text(_showOnlyEnabled ? 'Show All' : 'Filter by Preferences'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 8),
                    Text('View Stats'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationPreferencesPage(),
                  ),
                );
              } else if (value == 'toggle_filter') {
                setState(() {
                  _showOnlyEnabled = !_showOnlyEnabled;
                  _applyFilter(_notifications);
                });
              } else if (value == 'stats') {
                _showStatsDialog();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: _clearAllNotifications,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildNotificationContent(),
    );
  }

  Widget _buildNotificationContent() {
    if (_filteredNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // 🔧 شريط معلومات الفلترة
        if (_showOnlyEnabled)
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing only enabled notifications based on your preferences',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showOnlyEnabled = false;
                      _applyFilter(_notifications);
                    });
                  },
                  child: Text(
                    'Show All',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF914D74),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 🔧 إحصائيات سريعة
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBadge('Total', _notifications.length, Colors.grey),
              _buildStatBadge('Filtered', _filteredNotifications.length, Color(0xFF914D74)),
              _buildStatBadge('Unread', _countUnreadNotifications(), Colors.blue),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: _filteredNotifications.length,
            padding: EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final notification = _filteredNotifications[index];
              return _buildNotificationCard(notification);
            },
          ),
        ),
      ],
    );
  }
  Widget _buildStatBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasNotificationsButFiltered = _notifications.isNotEmpty && _filteredNotifications.isEmpty;

    String message;
    String subMessage;
    IconData icon;
    Color iconColor;

    if (hasNotificationsButFiltered) {
      message = 'No notifications to show';
      subMessage = 'All notifications are filtered out based on your preferences';
      icon = Icons.filter_alt_off;
      iconColor = Colors.orange;
    } else {
      message = 'No notifications yet';
      subMessage = 'You\'ll see updates here when they arrive';
      icon = Icons.notifications_none;
      iconColor = Colors.grey[400]!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: iconColor),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),

          if (hasNotificationsButFiltered)
            Column(
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.settings),
                  label: Text('Adjust Preferences'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF914D74),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationPreferencesPage(),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showOnlyEnabled = false;
                      _applyFilter(_notifications);
                    });
                  },
                  child: Text('Show All Notifications Anyway'),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              icon: Icon(Icons.settings),
              label: Text('Notification Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF914D74),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPreferencesPage(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    final type = notification['type'] ?? 'general';

    IconData icon;
    Color iconColor;
    Color? backgroundColor;
    String typeLabel;
    String? productId;
    String? couponCode;

    switch (type) {
      case 'new_product':
      case 'product_arrival':
        icon = Icons.shopping_bag;
        iconColor = Colors.purple;
        backgroundColor = Colors.purple[50];
        typeLabel = 'Product';
        productId = notification['productId'];
        break;
      case 'new_discount':
      case 'product_discount':
      case 'coupon':
      case 'discount':
        icon = Icons.local_offer;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange[50];
        typeLabel = 'Discount';
        productId = notification['productId'];
        couponCode = notification['couponCode'];
        break;
      case 'order_update':
      case 'order_status':
      case 'shipping':
      case 'order':
        icon = Icons.inventory_2;
        iconColor = Colors.blue;
        backgroundColor = Colors.blue[50];
        typeLabel = 'Order';
        break;
      case 'test':
        icon = Icons.construction;
        iconColor = Colors.grey;
        backgroundColor = Colors.grey[50];
        typeLabel = 'Test';
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.green;
        backgroundColor = Colors.green[50];
        typeLabel = 'General';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: isRead ? Colors.grey[50] : backgroundColor,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification['title'] ?? 'Notification',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isRead ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              notification['body'] ?? 'No message',
              style: TextStyle(
                color: isRead ? Colors.grey[500] : Colors.black54,
              ),
            ),

            if (type.contains('discount') && couponCode != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Text(
                        couponCode,
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (notification['discountValue'] != null)
                      Text(
                        notification['discountType'] == 'percentage'
                            ? '${notification['discountValue']}% OFF'
                            : 'OMR ${notification['discountValue']} OFF',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(DateTime.fromMillisecondsSinceEpoch(notification['timestamp'] ?? 0)),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                if (!isRead)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: isRead
            ? Icon(Icons.check_circle, color: Colors.green, size: 20)
            : Icon(Icons.mark_chat_unread, color: Colors.blue, size: 20),
        onTap: () {
          if ((type == 'new_product' || type == 'product_discount') && productId != null) {
            Navigator.pushNamed(
              context,
              '/product_detail',
              arguments: productId,
            );
          }
          else if (type.contains('discount')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Discount code ready to use!'),
                backgroundColor: Colors.orange,
              ),
            );
          }

          _markAsRead(notification['id']);
        },
        onLongPress: () {
          _showNotificationOptions(notification);
        },
      ),
    );
  }
  void _showNotificationOptions(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notification Options'),
        content: Text(notification['title'] ?? 'Notification'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsRead(notification['id']);
            },
            child: Text('Mark as Read'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteNotification(notification['id']);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  Future<void> _deleteNotification(String notificationId) async {
    if (user == null) return;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user!.uid}/notifications/$notificationId')
          .remove();

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
        _applyFilter(_notifications);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }
  void _showStatsDialog() {
    final total = _notifications.length;
    final filtered = _filteredNotifications.length;
    final hidden = total - filtered;
    final unread = _countUnreadNotifications();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF914D74)),
            SizedBox(width: 8),
            Text('Notification Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Notifications', total.toString(), Colors.grey),
            _buildStatRow('Currently Showing', filtered.toString(), Color(0xFF914D74)),
            _buildStatRow('Hidden by Preferences', hidden.toString(), Colors.orange),
            _buildStatRow('Unread Notifications', unread.toString(), Colors.blue),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Preferences Status:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            _buildPreferenceStatus('Product Notifications', _newProductArrival),
            _buildPreferenceStatus('Discount Notifications', _discountsAndOffers),
            _buildPreferenceStatus('Order Notifications', _orderUpdates),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPreferencesPage(),
                ),
              );
            },
            child: Text('Manage Preferences', style: TextStyle(color: Color(0xFF914D74))),
          ),
        ],
      ),
    );
  }
  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPreferenceStatus(String label, bool isEnabled) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isEnabled ? Colors.green : Colors.red,
          ),
          SizedBox(width: 8),
          Text(label),
          Spacer(),
          Text(
            isEnabled ? 'ENABLED' : 'DISABLED',
            style: TextStyle(
              fontSize: 10,
              color: isEnabled ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  int _countUnreadNotifications() {
    return _notifications.where((n) => n['isRead'] != true).length;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
